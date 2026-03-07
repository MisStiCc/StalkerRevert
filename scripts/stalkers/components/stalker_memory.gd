extends Node
class_name StalkerMemory

## Память сталкера об угрозах и объектах
## Хранит и обновляет информацию об окружении

var owner_stalker: CharacterBody3D

# Известные объекты
var known_anomalies: Array[Node] = []
var known_mutants: Array[Node] = []
var known_artifacts: Array[Node] = []

# Параметры
var vision_range: float = 30.0
var memory_duration: float = 10.0  # Как долго помнить объект
var last_update: float = 0.0

# Таймеры для каждого объекта
var anomaly_timers: Dictionary = {}
var mutant_timers: Dictionary = {}
var artifact_timers: Dictionary = {}


func _init(stalker: CharacterBody3D):
	owner_stalker = stalker


func _ready():
	vision_range = owner_stalker.vision_range if owner_stalker.has_property("vision_range") else 30.0


func _physics_process(delta: float):
	last_update += delta
	
	# Обновляем память каждый интервал
	if last_update >= 2.0:
		last_update = 0.0
		_refresh_memory()


func _refresh_memory():
	"""Обновляет информацию о замеченных объектах"""
	_clear_invalid()
	_scan_for_objects()


func _clear_invalid():
	"""Удаляет невалидные объекты"""
	var tree = owner_stalker.get_tree()
	
	# Фильтруем аномалии
	known_anomalies = known_anomalies.filter(func(a): 
		return is_instance_valid(a) and _is_in_vision_range(a)
	)
	
	# Фильтруем мутантов
	known_mutants = known_mutants.filter(func(m):
		return is_instance_valid(m) and _is_in_vision_range(m)
	)
	
	# Фильтруем артефакты
	known_artifacts = known_artifacts.filter(func(a):
		return is_instance_valid(a) and not a.is_collected if a.has_method("is_collected") else _is_in_vision_range(a)
	)


func _scan_for_objects():
	"""Сканирует окружение для поиска новых объектов"""
	var tree = owner_stalker.get_tree()
	var pos = owner_stalker.global_position
	
	# Ищем аномалии
	var anomalies = tree.get_nodes_in_group("anomalies")
	for a in anomalies:
		if is_instance_valid(a) and _is_in_vision_range(a):
			if not a in known_anomalies:
				known_anomalies.append(a)
				anomaly_timers[a.get_instance_id()] = 0.0
	
	# Ищем мутантов
	var mutants = tree.get_nodes_in_group("mutants")
	for m in mutants:
		if is_instance_valid(m) and _is_in_vision_range(m):
			if not m in known_mutants:
				known_mutants.append(m)
				mutant_timers[m.get_instance_id()] = 0.0
	
	# Ищем артефакты
	var artifacts = tree.get_nodes_in_group("artifacts")
	for a in artifacts:
		if is_instance_valid(a) and _is_in_vision_range(a):
			var is_collected = a.is_collected if a.has_method("is_collected") else false
			if not is_collected and not a in known_artifacts:
				known_artifacts.append(a)
				artifact_timers[a.get_instance_id()] = 0.0


func _is_in_vision_range(obj: Node) -> bool:
	return owner_stalker.global_position.distance_to(obj.global_position) <= vision_range


# ==================== ПУБЛИЧНОЕ API ====================

func get_nearest_threat() -> Node:
	"""Получить ближайшую угрозу (аномалию)"""
	if known_anomalies.is_empty():
		return null
	
	var nearest = null
	var min_dist = vision_range
	
	for a in known_anomalies:
		if not is_instance_valid(a):
			continue
		var dist = owner_stalker.global_position.distance_to(a.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = a
	
	return nearest


func get_nearest_mutant() -> Node:
	"""Получить ближайшего мутанта"""
	if known_mutants.is_empty():
		return null
	
	var nearest = null
	var min_dist = vision_range
	
	for m in known_mutants:
		if not is_instance_valid(m):
			continue
		var dist = owner_stalker.global_position.distance_to(m.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = m
	
	return nearest


func get_nearest_artifact() -> Node:
	"""Получить ближайший артефакт"""
	if known_artifacts.is_empty():
		return null
	
	var nearest = null
	var min_dist = vision_range
	
	for a in known_artifacts:
		if not is_instance_valid(a):
			continue
		var is_collected = a.is_collected if a.has_method("is_collected") else true
		if is_collected:
			continue
		var dist = owner_stalker.global_position.distance_to(a.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = a
	
	return nearest


func get_all_threats() -> Array[Node]:
	"""Получить все известные угрозы"""
	return known_anomalies.duplicate()


func get_all_mutants() -> Array[Node]:
	"""Получить всех известных мутантов"""
	return known_mutants.duplicate()


func get_all_artifacts() -> Array[Node]:
	"""Получить все известные артефакты"""
	return known_artifacts.duplicate()


func has_known_threats() -> bool:
	return not known_anomalies.is_empty()


func has_known_mutants() -> bool:
	return not known_mutants.is_empty()


func has_known_artifacts() -> bool:
	return not known_artifacts.is_empty()


func get_threat_count() -> int:
	return known_anomalies.size()


func get_mutant_count() -> int:
	return known_mutants.size()


func get_artifact_count() -> int:
	return known_artifacts.size()


func clear_memory():
	"""Очистить всю память"""
	known_anomalies.clear()
	known_mutants.clear()
	known_artifacts.clear()
	anomaly_timers.clear()
	mutant_timers.clear()
	artifact_timers.clear()


func set_vision_range(range_val: float):
	vision_range = range_val
