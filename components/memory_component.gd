# components/memory_component.gd
extends Node
class_name MemoryComponent

## Компонент памяти - хранит информацию об окружении

signal threat_detected(threat: Node, type: String)
signal threat_lost(threat: Node)
signal artifact_detected(artifact: Node)
signal artifact_lost(artifact: Node)
signal memory_cleared

# Владелец
var stalker: BaseStalker

# Известные объекты
var known_anomalies: Array[Node] = []
var known_mutants: Array[Node] = []
var known_artifacts: Array[Node] = []
var known_stalkers: Array[Node] = []

# Параметры
var vision_range: float = 30.0:
	set(value):
		vision_range = max(1.0, value)
		print("Дальность зрения изменена на " + str(vision_range))

var update_interval: float = 1.0
var memory_duration: float = 10.0
var max_memory_size: int = 50

# Внутреннее состояние
var time_since_update: float = 0.0
var object_timers: Dictionary = {}  # instance_id -> time_seen


func _ready():
	set_process(true)
	print("MemoryComponent инициализирован с дальностью " + str(vision_range))


func _process(delta):
	if not stalker or not is_instance_valid(stalker):
		return
	
	time_since_update += delta
	if time_since_update >= update_interval:
		time_since_update = 0.0
		_refresh_memory()


func _refresh_memory():
	var tree = stalker.get_tree()
	if not tree:
		return
	
	var pos = stalker.global_position
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Очищаем невалидные объекты
	_clean_invalid_objects(current_time)
	
	# Сканируем окружение
	_scan_for_anomalies(tree, pos, current_time)
	_scan_for_mutants(tree, pos, current_time)
	_scan_for_artifacts(tree, pos, current_time)
	_scan_for_stalkers(tree, pos, current_time)


func _clean_invalid_objects(current_time: float):
	# Аномалии
	var to_remove = []
	for a in known_anomalies:
		if not is_instance_valid(a):
			to_remove.append(a)
			# Не пытаемся получить ID у невалидного объекта!
		else:
			var id = a.get_instance_id()
			if object_timers.has(id) and current_time - object_timers[id] > memory_duration:
				to_remove.append(a)
				threat_lost.emit(a)
	
	for a in to_remove:
		known_anomalies.erase(a)
		if is_instance_valid(a):
			object_timers.erase(a.get_instance_id())
	
	# Мутанты
	to_remove.clear()
	for m in known_mutants:
		if not is_instance_valid(m):
			to_remove.append(m)
		else:
			var id = m.get_instance_id()
			if object_timers.has(id) and current_time - object_timers[id] > memory_duration:
				to_remove.append(m)
				threat_lost.emit(m)
	
	for m in to_remove:
		known_mutants.erase(m)
		if is_instance_valid(m):
			object_timers.erase(m.get_instance_id())
	
	# Артефакты
	to_remove.clear()
	for a in known_artifacts:
		if not is_instance_valid(a):
			to_remove.append(a)
		else:
			var is_collected = a.get("is_collected") if "is_collected" in a else false
			if is_collected:
				to_remove.append(a)
				artifact_lost.emit(a)
			else:
				var id = a.get_instance_id()
				if object_timers.has(id) and current_time - object_timers[id] > memory_duration:
					to_remove.append(a)
					artifact_lost.emit(a)
	
	for a in to_remove:
		known_artifacts.erase(a)
		if is_instance_valid(a):
			object_timers.erase(a.get_instance_id())
	
	# Сталкеры
	to_remove.clear()
	for s in known_stalkers:
		if not is_instance_valid(s) or s == stalker:
			to_remove.append(s)
		else:
			var id = s.get_instance_id()
			if object_timers.has(id) and current_time - object_timers[id] > memory_duration:
				to_remove.append(s)
	
	for s in to_remove:
		known_stalkers.erase(s)
		if is_instance_valid(s):
			object_timers.erase(s.get_instance_id())


func _scan_for_anomalies(tree: SceneTree, pos: Vector3, current_time: float):
	var anomalies = tree.get_nodes_in_group("anomalies")
	for a in anomalies:
		if not is_instance_valid(a):
			continue
		
		var dist = pos.distance_to(a.global_position)
		if dist <= vision_range:
			var id = a.get_instance_id()
			if not object_timers.has(id):
				known_anomalies.append(a)
				threat_detected.emit(a, "anomaly")
				print("Обнаружена аномалия на расстоянии " + str(dist))
			object_timers[id] = current_time


func _scan_for_mutants(tree: SceneTree, pos: Vector3, current_time: float):
	var mutants = tree.get_nodes_in_group("mutants")
	for m in mutants:
		if not is_instance_valid(m):
			continue
		
		var dist = pos.distance_to(m.global_position)
		if dist <= vision_range:
			var id = m.get_instance_id()
			if not object_timers.has(id):
				known_mutants.append(m)
				threat_detected.emit(m, "mutant")
				print("Обнаружен мутант на расстоянии " + str(dist))
			object_timers[id] = current_time


func _scan_for_artifacts(tree: SceneTree, pos: Vector3, current_time: float):
	var artifacts = tree.get_nodes_in_group("artifacts")
	for a in artifacts:
		if not is_instance_valid(a):
			continue
		
		var is_collected = a.get("is_collected") if "is_collected" in a else false
		if is_collected:
			continue
		
		var dist = pos.distance_to(a.global_position)
		if dist <= vision_range:
			var id = a.get_instance_id()
			if not object_timers.has(id):
				known_artifacts.append(a)
				artifact_detected.emit(a)
				print("Обнаружен артефакт на расстоянии " + str(dist))
			object_timers[id] = current_time


func _scan_for_stalkers(tree: SceneTree, pos: Vector3, current_time: float):
	var stalkers = tree.get_nodes_in_group("stalkers")
	for s in stalkers:
		if not is_instance_valid(s) or s == stalker:
			continue
		
		var dist = pos.distance_to(s.global_position)
		if dist <= vision_range:
			var id = s.get_instance_id()
			if not object_timers.has(id):
				known_stalkers.append(s)
				print("Обнаружен другой сталкер на расстоянии " + str(dist))
			object_timers[id] = current_time


# ==================== ПУБЛИЧНОЕ API ====================

func get_nearest_threat() -> Node:
	var nearest = null
	var min_dist = INF
	var pos = stalker.global_position
	
	for a in known_anomalies:
		if not is_instance_valid(a):
			continue
		var dist = pos.distance_to(a.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = a
	
	return nearest


func get_nearest_mutant() -> Node:
	var nearest = null
	var min_dist = INF
	var pos = stalker.global_position
	
	for m in known_mutants:
		if not is_instance_valid(m):
			continue
		var dist = pos.distance_to(m.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = m
	
	return nearest


func get_nearest_artifact() -> Node:
	var nearest = null
	var min_dist = INF
	var pos = stalker.global_position
	
	for a in known_artifacts:
		if not is_instance_valid(a):
			continue
		var dist = pos.distance_to(a.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = a
	
	return nearest


func get_all_threats() -> Array[Node]:
	var result = []
	result.append_array(known_anomalies)
	result.append_array(known_mutants)
	return result


func get_all_artifacts() -> Array[Node]:
	return known_artifacts.duplicate()


func get_all_mutants() -> Array[Node]:
	return known_mutants.duplicate()


func get_all_anomalies() -> Array[Node]:
	return known_anomalies.duplicate()


func get_threat_count() -> int:
	return known_anomalies.size() + known_mutants.size()


func get_artifact_count() -> int:
	return known_artifacts.size()


func get_mutant_count() -> int:
	return known_mutants.size()


func get_anomaly_count() -> int:
	return known_anomalies.size()


func has_artifacts() -> bool:
	return not known_artifacts.is_empty()


func has_mutants() -> bool:
	return not known_mutants.is_empty()


func has_anomalies() -> bool:
	return not known_anomalies.is_empty()


func has_threats() -> bool:
	return has_anomalies() or has_mutants()


func is_known(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	var id = node.get_instance_id()
	return object_timers.has(id)


func get_memory_age(node: Node) -> float:
	if not is_instance_valid(node):
		return INF
	var id = node.get_instance_id()
	if object_timers.has(id):
		return (Time.get_ticks_msec() / 1000.0) - object_timers[id]
	return INF


func clear_memory():
	known_anomalies.clear()
	known_mutants.clear()
	known_artifacts.clear()
	known_stalkers.clear()
	object_timers.clear()
	memory_cleared.emit()
	print("Память очищена")


func set_vision_range(range_val: float):
	vision_range = max(1.0, range_val)


func get_vision_range() -> float:
	return vision_range


func get_memory_size() -> int:
	return known_anomalies.size() + known_mutants.size() + known_artifacts.size() + known_stalkers.size()


func get_memory_stats() -> Dictionary:
	return {
		"anomalies": known_anomalies.size(),
		"mutants": known_mutants.size(),
		"artifacts": known_artifacts.size(),
		"stalkers": known_stalkers.size(),
		"total": get_memory_size()
	}
