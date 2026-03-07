extends Node
class_name ZoneController

## ZoneController - ОРХЕСТРАТОР
## Управляет менеджерами и координирует игровую логику
## Каждый менеджер отвечает за свою область ответственности

# ========== СИГНАЛЫ (пробрасываем наружу) ==========
signal energy_changed(current: float, max_energy: float)
signal biomass_changed(current: float, max_biomass: float)
signal difficulty_changed(new_difficulty: float)
signal wave_started(wave_number: int)
signal wave_ended(wave_number: int, stalkers_spawned: int)
signal radiation_pulse_started(level: int)
signal radiation_pulse_ended
signal anomaly_created(anomaly: Node, anomaly_type: String, difficulty: int)
signal anomaly_destroyed(anomaly_type: String, position: Vector3, difficulty: int)
signal artifact_created(artifact: Node, artifact_type: String, position: Vector3)
signal artifact_stolen(artifact: Node, stalker: Node)
signal stalker_died(stalker_type: String, biomass_returned: float)
signal game_over
signal game_won(run_number: int, reward: float)

# ========== МЕНЕДЖЕРЫ ==========
var resource_manager: ResourceManager
var anomaly_manager: AnomalyManager
var spawn_manager: SpawnManager
var event_manager: EventManager
var progression_manager: ProgressionManager
var fog_manager: FogManager
var particle_manager: ParticleManager
var sound_manager: SoundManager

# ========== КОНФИГУРАЦИЯ ==========
@export var anomaly_scenes: Dictionary = {}
@export var anomaly_artifact_map: Dictionary = {}
@export var artifact_values: Dictionary = {}
@export var difficulty_to_rarity: Dictionary = {}

@export var novice_stalker_scene: PackedScene
@export var veteran_stalker_scene: PackedScene
@export var master_stalker_scene: PackedScene
@export var mutant_scenes: Dictionary = {}

@export var max_energy: float = 1000.0
@export var max_biomass: float = 1000.0
@export var critical_biomass_threshold: float = 0.8


func _ready():
	add_to_group("zone_controller")
	_setup_managers()
	_connect_signals()
	_initialize_game()
	print("🎮 ZoneController: инициализирован как оркестратор")


func _setup_managers():
	# 1. ResourceManager
	resource_manager = ResourceManager.new()
	resource_manager.max_energy = max_energy
	resource_manager.max_biomass = max_biomass
	add_child(resource_manager)
	
	# 2. AnomalyManager
	anomaly_manager = AnomalyManager.new()
	anomaly_manager.anomaly_scenes = anomaly_scenes
	anomaly_manager.anomaly_artifact_map = anomaly_artifact_map
	anomaly_manager.artifact_values = artifact_values
	anomaly_manager.difficulty_to_rarity = difficulty_to_rarity
	add_child(anomaly_manager)
	
	# 3. SpawnManager
	spawn_manager = SpawnManager.new()
	spawn_manager.stalker_scenes = {
		"novice": novice_stalker_scene,
		"veteran": veteran_stalker_scene,
		"master": master_stalker_scene
	}
	spawn_manager.mutant_scenes = mutant_scenes
	add_child(spawn_manager)
	
	# 4. EventManager
	event_manager = EventManager.new()
	add_child(event_manager)
	
	# 5. ProgressionManager
	progression_manager = ProgressionManager.new()
	add_child(progression_manager)

	# 6. FogManager (визуальный)
	fog_manager = FogManager.new()
	fog_manager.enabled = true
	add_child(fog_manager)

	# 7. ParticleManager (визуальный)
	particle_manager = ParticleManager.new()
	add_child(particle_manager)

	# 8. SoundManager (аудио)
	sound_manager = SoundManager.new()
	add_child(sound_manager)


func _connect_signals():
	resource_manager.energy_changed.connect(_on_energy_changed)
	resource_manager.biomass_changed.connect(_on_biomass_changed)
	resource_manager.critical_biomass_reached.connect(_on_critical_biomass)
	
	anomaly_manager.anomaly_created.connect(_on_anomaly_created)
	anomaly_manager.anomaly_destroyed.connect(_on_anomaly_destroyed)
	anomaly_manager.artifact_created.connect(_on_artifact_created)
	anomaly_manager.artifact_stolen.connect(_on_artifact_stolen)
	
	spawn_manager.wave_started.connect(_on_wave_started)
	spawn_manager.wave_ended.connect(_on_wave_ended)
	spawn_manager.stalker_died.connect(_on_stalker_died)
	
	event_manager.radiation_pulse_started.connect(_on_radiation_pulse_started)
	event_manager.radiation_pulse_ended.connect(_on_radiation_pulse_ended)
	event_manager.game_over.connect(_on_game_over)
	event_manager.game_won.connect(_on_game_won)


func _initialize_game():
	var run_data = progression_manager.start_new_run()
	event_manager.set_pulses_to_win(run_data.pulses_to_win)
	event_manager.set_run_number(run_data.run_number)
	event_manager.set_difficulty(run_data.difficulty)
	spawn_manager.start_spawning()


# ========== ОБРАБОТЧИКИ СИГНАЛОВ ==========

func _on_energy_changed(current: float, max_energy: float):
	energy_changed.emit(current, max_energy)


func _on_biomass_changed(current: float, max_biomass: float):
	biomass_changed.emit(current, max_biomass)


func _on_critical_biomass():
	event_manager.start_radiation_pulse()


func _on_anomaly_created(anomaly: Node, anomaly_type: String, difficulty: int):
	anomaly_created.emit(anomaly, anomaly_type, difficulty)


func _on_anomaly_destroyed(anomaly_type: String, position: Vector3, difficulty: int):
	anomaly_destroyed.emit(anomaly_type, position, difficulty)


func _on_artifact_created(artifact: Node, artifact_type: String, position: Vector3):
	artifact_created.emit(artifact, artifact_type, position)


func _on_artifact_stolen(artifact: Node, stalker: Node):
	var loss = 10.0
	if artifact.has_method("get_value"):
		loss = artifact.get_value()
	resource_manager.spend_biomass(loss)
	artifact_stolen.emit(artifact, stalker)


func _on_wave_started(wave_number: int):
	wave_started.emit(wave_number)
	spawn_manager.set_difficulty(progression_manager.get_current_difficulty())


func _on_wave_ended(wave_number: int, stalkers_spawned: int):
	wave_ended.emit(wave_number, stalkers_spawned)


func _on_stalker_died(stalker: Node, biomass_returned: float):
	resource_manager.add_biomass(biomass_returned)
	var stalker_type = "unknown"
	if stalker.has_method("get_stalker_type"):
		stalker_type = stalker.get_stalker_type()
	stalker_died.emit(stalker_type, biomass_returned)
	progression_manager.record_stalker_killed()


func _on_radiation_pulse_started(level: int):
	var safe_level = max_biomass * 0.3
	resource_manager.current_biomass = safe_level
	resource_manager.biomass_changed.emit(safe_level, max_biomass)
	progression_manager.increase_difficulty()
	event_manager.set_difficulty(progression_manager.get_current_difficulty())
	radiation_pulse_started.emit(level)


func _on_radiation_pulse_ended():
	radiation_pulse_ended.emit()


func _on_game_over():
	game_over.emit()


func _on_game_won(run_number: int, reward: float):
	resource_manager.add_biomass(reward)
	game_won.emit(run_number, reward)


# ========== ПУБЛИЧНОЕ API ==========

func get_energy() -> float:
	return resource_manager.get_energy()


func get_biomass() -> float:
	return resource_manager.get_biomass()


func add_energy(amount: float):
	resource_manager.add_energy(amount)


func add_biomass(amount: float):
	resource_manager.add_biomass(amount)


func spend_energy(amount: float) -> bool:
	return resource_manager.spend_energy(amount)


func spend_biomass(amount: float) -> bool:
	return resource_manager.spend_biomass(amount)


func create_anomaly(anomaly_type: String, position: Vector3, difficulty: int = 1) -> Node:
	var cost = anomaly_manager.get_anomaly_cost(anomaly_type)
	if not resource_manager.spend_energy(cost):
		print("ZoneController: недостаточно энергии для аномалии ", anomaly_type)
		return null
	return anomaly_manager.create_anomaly(anomaly_type, position, difficulty, cost)


func create_artifact(artifact_type: String, position: Vector3, rarity: String = "common", value: float = 10.0) -> Node:
	return anomaly_manager.create_artifact(artifact_type, position, rarity, value)


func spawn_mutant(mutant_type: String, position: Vector3) -> Node:
	var cost = spawn_manager.get_mutant_cost(mutant_type)
	if not resource_manager.spend_biomass(cost):
		print("ZoneController: недостаточно биомассы для мутанта ", mutant_type)
		return null
	return spawn_manager.spawn_mutant(mutant_type, position, cost)


func register_stalker(stalker: Node):
	spawn_manager.active_stalkers.append(stalker)


func get_difficulty() -> float:
	return progression_manager.get_current_difficulty()


func set_difficulty(value: float):
	progression_manager.current_difficulty = value
	difficulty_changed.emit(value)


func get_run_number() -> int:
	return progression_manager.get_current_run()


func get_pulses_to_win() -> int:
	return progression_manager.get_pulses_to_win()


func get_pulse_count() -> int:
	return event_manager.get_pulse_count()


func is_radiating() -> bool:
	return event_manager.is_pulse_active()


func get_resource_status() -> Dictionary:
	return {
		"energy": resource_manager.get_energy(),
		"max_energy": resource_manager.max_energy,
		"biomass": resource_manager.get_biomass(),
		"max_biomass": resource_manager.max_biomass,
		"difficulty": progression_manager.get_current_difficulty(),
		"stalker_count": spawn_manager.get_stalker_count()
	}


func can_afford(energy_cost: float, biomass_cost: float) -> bool:
	return resource_manager.get_energy() >= energy_cost and resource_manager.get_biomass() >= biomass_cost


# ==================== РЕЗУЛЬТАТЫ ЗАБЕГА ====================

func get_run_result() -> Dictionary:
	"""Возвращает результаты забега для передачи в ЛК"""
	var result = {
		"success": event_manager.has_won(),
		"run_number": progression_manager.get_current_run(),
		"reward": resource_manager.get_biomass(),
		"statistics": {
			"stalkers_killed": progression_manager.get_stalkers_killed(),
			"anomalies_created": anomaly_manager.get_anomaly_count(),
			"mutants_created": spawn_manager.get_mutant_count(),
			"artifacts_stolen": spawn_manager.get_artifacts_stolen(),
			"biomass_earned": resource_manager.get_biomass(),
			"biomass_spent": 0  # TODO: отслеживать
		},
		"artifacts_collected": _collect_artifacts()
	}
	return result


func _collect_artifacts() -> Array:
	"""Собирает все артефакты со сцены"""
	var artifacts = []
	var artifact_nodes = get_tree().get_nodes_in_group("artifacts")
	
	for a in artifact_nodes:
		if is_instance_valid(a) and a.has_method("get_rarity") and a.has_method("get_value"):
			artifacts.append({
				"type": a.get_rarity(),
				"value": a.get_value()
			})
	
	return artifacts


func finish_run(success: bool):
	"""Завершает забег и передаёт результаты в GameManager"""
	event_manager.set_game_over(success)
	
	# Собираем результаты
	var result = get_run_result()
	
	# Передаём в GameManager
	if Engine.has_singleton("GameManager"):
		# Используем группу для поиска GameManager
		var gm = get_tree().get_first_node_in_group("game_manager")
		if gm:
			gm.process_run_result(result)
	
	# Переходим в ЛК
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/lab/lab.tscn")
