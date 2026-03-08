extends Node
class_name AnomalyManager

## Управление аномалиями и артефактами
## Создание, уничтожение, преобразование

signal anomaly_created(anomaly: Node, anomaly_type: String, difficulty: int)
signal anomaly_destroyed(anomaly_type: String, position: Vector3, difficulty: int)
signal artifact_created(artifact: Node, artifact_type: String, position: Vector3)
signal artifact_stolen(artifact: Node, stalker: Node)
signal artifact_collected(artifact: Node, collector: Node)

@export var anomaly_scenes: Dictionary = {}
@export var anomaly_artifact_map: Dictionary = {}
@export var artifact_values: Dictionary = {}
@export var difficulty_to_rarity: Dictionary = {}
@export var artifact_respawn_time: float = 30.0

var active_anomalies: Array[Node] = []
var active_artifacts: Array[Node] = []
var dropped_artifact_timers: Dictionary = {}


func _ready():
	add_to_group("anomaly_manager")


# ==================== АНОМАЛИИ ====================

func create_anomaly(anomaly_type: String, position: Vector3, difficulty: int, energy_cost: float) -> Node:
	if not anomaly_scenes.has(anomaly_type):
		push_error("AnomalyManager: неизвестный тип аномалии - ", anomaly_type)
		return null
	
	var scene = anomaly_scenes[anomaly_type]
	var anomaly = scene.instantiate()
	anomaly.position = position
	
	# Устанавливаем сложность
	if anomaly.has_method("set_difficulty"):
		anomaly.set_difficulty(difficulty)
	
	# Подключаем сигнал уничтожения
	if anomaly.has_signal("destroyed"):
		anomaly.destroyed.connect(_on_anomaly_destroyed)
	
	anomaly.add_to_group("anomalies")
	get_tree().current_scene.add_child(anomaly)
	active_anomalies.append(anomaly)
	
	anomaly_created.emit(anomaly, anomaly_type, difficulty)
	return anomaly


func remove_anomaly(anomaly: Node):
	if is_instance_valid(anomaly):
		active_anomalies.erase(anomaly)
		anomaly.queue_free()


func get_active_anomalies() -> Array[Node]:
	return active_anomalies.filter(func(a): return is_instance_valid(a))


func get_anomaly_cost(anomaly_type: String) -> float:
	match anomaly_type:
		"heat_anomaly": return 50.0
		"electric_anomaly": return 75.0
		"acid_anomaly": return 100.0
		"gravity_vortex": return 150.0
		"gravity_lift": return 80.0
		"gravity_whirlwind": return 120.0
		"thermal_steam": return 70.0
		"thermal_comet": return 100.0
		"chemical_jelly": return 60.0
		"chemical_gas": return 85.0
		"chemical_acid_cloud": return 110.0
		"radiation_hotspot": return 95.0
		"time_dilation": return 200.0
		"teleport": return 180.0
		"electric_tesla": return 90.0
		"bio_burning_fluff": return 75.0
		_: return 50.0


func _on_anomaly_destroyed(anomaly_type: String, position: Vector3, difficulty: int):
	# Удаляем из списка
	active_anomalies = active_anomalies.filter(
		func(a): return is_instance_valid(a) and a.global_position != position
	)
	
	# Создаём артефакт
	var artifact_type = anomaly_artifact_map.get(anomaly_type, "common_artifact")
	var rarity = difficulty_to_rarity.get(difficulty, "common")
	var values = artifact_values.get(rarity, [10])
	var value = values[randi() % values.size()]
	
	create_artifact(artifact_type, position, rarity, value)
	
	anomaly_destroyed.emit(anomaly_type, position, difficulty)


# ==================== АРТЕФАКТЫ ====================

func create_artifact(artifact_type: String, position: Vector3, rarity: String = "common", value: float = 10.0) -> Node:
	var scene_path = "res://scenes/artifacts/" + artifact_type + ".tscn"
	if not ResourceLoader.exists(scene_path):
		push_error("AnomalyManager: сцена артефакта не найдена - ", scene_path)
		return null
	
	var scene = load(scene_path)
	var artifact = scene.instantiate()
	artifact.position = position
	
	# Устанавливаем редкость и ценность
	if artifact.has_method("set_rarity_and_value"):
		artifact.set_rarity_and_value(rarity, value)
	
	# Подключаем сигналы
	if artifact.has_signal("stolen"):
		artifact.stolen.connect(_on_artifact_stolen)
	if artifact.has_signal("collected"):
		artifact.collected.connect(_on_artifact_collected)
	
	artifact.add_to_group("artifacts")
	get_tree().current_scene.add_child(artifact)
	active_artifacts.append(artifact)
	
	# Запускаем таймер для артефактов на земле
	_start_dropped_artifact_timer(artifact)
	
	artifact_created.emit(artifact, artifact_type, position)
	return artifact


func _on_artifact_stolen(artifact: Node, stalker: Node):
	# Останавливаем таймер
	if dropped_artifact_timers.has(artifact):
		var timer = dropped_artifact_timers[artifact]
		timer.stop()
		timer.queue_free()
		dropped_artifact_timers.erase(artifact)
	
	artifact_stolen.emit(artifact, stalker)


func _on_artifact_collected(artifact: Node, collector: Node):
	if artifact in active_artifacts:
		active_artifacts.erase(artifact)
	artifact_collected.emit(artifact, collector)


func _start_dropped_artifact_timer(artifact: Node):
	if dropped_artifact_timers.has(artifact):
		return
	
	var timer = Timer.new()
	timer.wait_time = artifact_respawn_time
	timer.one_shot = true
	timer.timeout.connect(_on_artifact_timeout.bind(artifact))
	add_child(timer)
	timer.start()
	
	dropped_artifact_timers[artifact] = timer


func _on_artifact_timeout(artifact: Node):
	if not is_instance_valid(artifact):
		dropped_artifact_timers.erase(artifact)
		return
	
	var position = artifact.global_position
	var difficulty = 1
	
	if artifact.has_method("get_difficulty"):
		difficulty = artifact.get_difficulty()
	elif artifact.has_method("get_rarity"):
		match artifact.get_rarity():
			"rare": difficulty = 2
			"legendary": difficulty = 3
	
	# Удаляем артефакт
	dropped_artifact_timers.erase(artifact)
	active_artifacts.erase(artifact)
	artifact.queue_free()
	
	# Эмитим сигнал для создания аномалии извне
	# (ZoneController или EventManager обработает)
	print("🔄 Артефакт истёк - требуется превращение в аномалию")


func remove_all_artifacts():
	for artifact in active_artifacts:
		if is_instance_valid(artifact):
			artifact.queue_free()
	active_artifacts.clear()
	
	for timer in dropped_artifact_timers.values():
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	dropped_artifact_timers.clear()


func stop_all_timers():
	for timer in dropped_artifact_timers.values():
		if is_instance_valid(timer):
			timer.stop()
	dropped_artifact_timers.clear()


func get_active_artifacts() -> Array[Node]:
	return active_artifacts.filter(func(a): return is_instance_valid(a))
