extends Node
class_name AnomalySpawner

## Создание и управление аномалиями

signal anomaly_created(anomaly: Node, anomaly_type: String, difficulty: int)
signal anomaly_destroyed(anomaly_type: String, position: Vector3, difficulty: int)

var owner: Node

# Сцены аномалий
@export var anomaly_scenes: Dictionary = {}

# Активные аномалии
var active_anomalies: Array[Node] = []

# Карта аномалия -> артефакт
@export var anomaly_artifact_map: Dictionary = {}

# Параметры
var _difficulty: float = 1.0


func _init(node: Node):
	owner = node


func setup(artifact_map: Dictionary):
	anomaly_artifact_map = artifact_map


func set_difficulty(difficulty: float):
	_difficulty = difficulty


func create_anomaly(anomaly_type: String, position: Vector3, difficulty: int = 1, cost: float = 0.0) -> Node:
	"""Создать аномалию"""
	if not anomaly_scenes.has(anomaly_type):
		push_error("AnomalySpawner: неизвестный тип - ", anomaly_type)
		return null
	
	var scene = anomaly_scenes[anomaly_type]
	if not scene:
		return null
	
	var anomaly = scene.instantiate()
	anomaly.position = position
	anomaly.add_to_group("anomalies")
	
	owner.get_tree().current_scene.add_child(anomaly)
	active_anomalies.append(anomaly)
	
	anomaly_created.emit(anomaly, anomaly_type, difficulty)
	return anomaly


func destroy_anomaly(anomaly: Node):
	"""Уничтожить аномалию"""
	if not is_instance_valid(anomaly):
		return
	
	var anomaly_type = ""
	var difficulty = 1
	
	if anomaly.has_method("get_anomaly_type"):
		anomaly_type = anomaly.get_anomaly_type()
	if anomaly.has_method("get_difficulty"):
		difficulty = anomaly.get_difficulty()
	
	var pos = anomaly.global_position
	
	if anomaly in active_anomalies:
		active_anomalies.erase(anomaly)
	
	anomaly.queue_free()
	anomaly_destroyed.emit(anomaly_type, pos, difficulty)


func destroy_random_anomaly() -> bool:
	"""Уничтожить случайную аномалию"""
	if active_anomalies.is_empty():
		return false
	
	var idx = randi() % active_anomalies.size()
	var anomaly = active_anomalies[idx]
	destroy_anomaly(anomaly)
	return true


func get_active_anomalies() -> Array[Node]:
	return active_anomalies.filter(func(a): return is_instance_valid(a))


def get_anomaly_count() -> int:
	return active_anomalies.size()


func get_anomaly_at_position(pos: Vector3, radius: float = 5.0) -> Node:
	"""Получить аномалию в радиусе от позиции"""
	for a in active_anomalies:
		if not is_instance_valid(a):
			continue
		if a.global_position.distance_to(pos) <= radius:
			return a
	return null


func get_anomalies_in_radius(center: Vector3, radius: float) -> Array[Node]:
	"""Получить все аномалии в радиусе"""
	var result = []
	for a in active_anomalies:
		if not is_instance_valid(a):
			continue
		if a.global_position.distance_to(center) <= radius:
			result.append(a)
	return result


func get_artifact_type_for_anomaly(anomaly_type: String) -> String:
	return anomaly_artifact_map.get(anomaly_type, "common")


func clear_all():
	"""Удалить все аномалии"""
	for anomaly in active_anomalies:
		if is_instance_valid(anomaly):
			anomaly.queue_free()
	active_anomalies.clear()


func set_anomaly_scenes(scenes: Dictionary):
	anomaly_scenes = scenes


func set_artifact_map(map: Dictionary):
	anomaly_artifact_map = map
