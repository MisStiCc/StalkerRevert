# zones/zone_controller.gd
extends Node
class_name ZoneController

## Единый контроллер зоны - оркестрирует все менеджеры

# Сигналы (прокси для менеджеров)
signal energy_changed(current: float, max_value: float)
signal biomass_changed(current: float, max_value: float)
signal radiation_pulse_started(level: int)
signal radiation_pulse_ended
signal wave_started(wave_number: int, count: int)
signal wave_ended(wave_number: int, survivors: int)
signal game_over
signal game_won(run_number: int, reward: float)

# Менеджеры
var resource_manager: ResourceManager
var anomaly_manager: AnomalyManager
var spawn_manager: SpawnManager
var event_manager: EventManager
var progression_manager: ProgressionManager

# Визуальные менеджеры
var fog_manager: FogManager
var particle_manager: ParticleManager
var sound_manager: SoundManager

# Конфигурация (загружается из сцены)
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
@export var pulse_duration: float = 5.0
@export var pulses_to_win: int = 5

# Параметры забега
var run_params: Dictionary = {}
var is_initialized: bool = false


func _ready():
    Logger.info("ZoneController: инициализация...", "ZoneController")
    add_to_group("zone_controller")
    
    # Загружаем параметры забега из GameManager
    if get_tree().root.has_meta("run_params"):
        run_params = get_tree().root.get_meta("run_params")
        get_tree().root.remove_meta("run_params")
        Logger.debug("Параметры забега загружены: " + str(run_params), "ZoneController")
    
    _setup_managers()
    _connect_managers()
    _initialize_run()
    
    is_initialized = true
    Logger.info("ZoneController: готов!", "ZoneController")


func _setup_managers():
    # ResourceManager
    resource_manager = ResourceManager.new()
    resource_manager.max_energy = max_energy
    resource_manager.max_biomass = max_biomass
    resource_manager.critical_threshold = critical_biomass_threshold
    add_child(resource_manager)
    Logger.debug("ResourceManager создан", "ZoneController")
    
    # AnomalyManager
    anomaly_manager = AnomalyManager.new()
    anomaly_manager.anomaly_scenes = anomaly_scenes
    anomaly_manager.anomaly_artifact_map = anomaly_artifact_map
    anomaly_manager.artifact_values = artifact_values
    anomaly_manager.difficulty_to_rarity = difficulty_to_rarity
    add_child(anomaly_manager)
    Logger.debug("AnomalyManager создан", "ZoneController")
    
    # SpawnManager
    spawn_manager = SpawnManager.new()
    spawn_manager.stalker_scenes = {
        "novice": novice_stalker_scene,
        "veteran": veteran_stalker_scene,
        "master": master_stalker_scene
    }
    spawn_manager.mutant_scenes = mutant_scenes
    add_child(spawn_manager)
    Logger.debug("SpawnManager создан", "ZoneController")
    
    # EventManager
    event_manager = EventManager.new()
    event_manager.pulse_duration = pulse_duration
    add_child(event_manager)
    Logger.debug("EventManager создан", "ZoneController")
    
    # ProgressionManager
    progression_manager = ProgressionManager.new()
    add_child(progression_manager)
    Logger.debug("ProgressionManager создан", "ZoneController")
    
    # FogManager
    fog_manager = FogManager.new()
    fog_manager.enabled = true
    add_child(fog_manager)
    Logger.debug("FogManager создан", "ZoneController")
    
    # ParticleManager
    particle_manager = ParticleManager.new()
    add_child(particle_manager)
    Logger.debug("ParticleManager создан", "ZoneController")
    
    # SoundManager
    sound_manager = SoundManager.new()
    add_child(sound_manager)
    Logger.debug("SoundManager создан", "ZoneController")


func _connect_managers():
    # ResourceManager
    resource_manager.energy_changed.connect(_on_energy_changed)
    resource_manager.biomass_changed.connect(_on_biomass_changed)
    resource_manager.critical_biomass_reached.connect(_on_critical_biomass)
    
    # EventManager
    event_manager.radiation_pulse_started.connect(_on_radiation_pulse_started)
    event_manager.radiation_pulse_ended.connect(_on_radiation_pulse_ended)
    event_manager.game_over.connect(_on_game_over)
    event_manager.game_won.connect(_on_game_won)
    
    # SpawnManager
    spawn_manager.wave_started.connect(_on_wave_started)
    spawn_manager.wave_ended.connect(_on_wave_ended)
    spawn_manager.stalker_died.connect(_on_stalker_died)
    spawn_manager.mutant_spawned.connect(_on_mutant_spawned)
    
    # AnomalyManager
    anomaly_manager.anomaly_created.connect(_on_anomaly_created)
    anomaly_manager.anomaly_destroyed.connect(_on_anomaly_destroyed)
    anomaly_manager.artifact_created.connect(_on_artifact_created)
    anomaly_manager.artifact_stolen.connect(_on_artifact_stolen)
    
    # Прокси сигналы в глобальные
    anomaly_manager.anomaly_created.connect(func(a, t, d): Signals.anomaly_created.emit(a, t, a.global_position, d))
    anomaly_manager.artifact_created.connect(func(a, t, p): Signals.artifact_created.emit(a, t, p, a.get_value() if a.has_method("get_value") else 0))
    spawn_manager.stalker_spawned.connect(func(s, t): Signals.stalker_spawned.emit(s, t, s.global_position))
    spawn_manager.mutant_spawned.connect(func(m, t): Signals.mutant_spawned.emit(m, t, m.global_position, spawn_manager.get_mutant_cost(t)))


func _initialize_run():
    var run_data = progression_manager.start_new_run()
    event_manager.set_pulses_to_win(pulses_to_win)
    event_manager.set_run_number(run_data.run_number)
    event_manager.set_difficulty(run_data.difficulty)
    
    # Применяем бонусы из лаборатории
    _apply_lab_bonuses()
    
    spawn_manager.start_spawning()
    
    Signals.run_started.emit(run_data.run_number, run_data.difficulty, pulses_to_win)
    Logger.info("Забег начат: #" + str(run_data.run_number) + " сложность: " + str(run_data.difficulty), "ZoneController")


func _apply_lab_bonuses():
    if not run_params.has("bonuses"):
        return
    
    var bonuses = run_params["bonuses"]
    
    # Применяем бонусы к менеджерам
    if bonuses.has("anomaly_damage_mult") and anomaly_manager:
        anomaly_manager.damage_multiplier = bonuses["anomaly_damage_mult"]
    
    if bonuses.has("anomaly_radius_mult") and anomaly_manager:
        anomaly_manager.radius_multiplier = bonuses["anomaly_radius_mult"]
    
    if bonuses.has("mutant_health_mult") and spawn_manager:
        spawn_manager.health_multiplier = bonuses["mutant_health_mult"]
    
    if bonuses.has("mutant_damage_mult") and spawn_manager:
        spawn_manager.damage_multiplier = bonuses["mutant_damage_mult"]
    
    if bonuses.has("mutant_cost_mult") and spawn_manager:
        spawn_manager.cost_multiplier = bonuses["mutant_cost_mult"]
    
    Logger.debug("Бонусы лаборатории применены: " + str(bonuses), "ZoneController")


# ==================== ОБРАБОТЧИКИ ====================

func _on_energy_changed(current: float, max_val: float):
    energy_changed.emit(current, max_val)
    Signals.energy_changed.emit(current, max_val, current / max_val if max_val > 0 else 0.0)


func _on_biomass_changed(current: float, max_val: float):
    biomass_changed.emit(current, max_val)
    Signals.biomass_changed.emit(current, max_val, current / max_val if max_val > 0 else 0.0)


func _on_critical_biomass():
    Logger.warning("Критический уровень биомассы!", "ZoneController")
    event_manager.start_radiation_pulse()


func _on_radiation_pulse_started(level: int):
    # Сбрасываем биомассу до безопасного уровня
    var safe_level = max_biomass * 0.3
    resource_manager.current_biomass = safe_level
    
    progression_manager.increase_difficulty()
    event_manager.set_difficulty(progression_manager.get_current_difficulty())
    
    radiation_pulse_started.emit(level)
    Signals.radiation_pulse_started.emit(level, pulse_duration)
    
    # Визуальные/звуковые эффекты
    if particle_manager:
        particle_manager.spawn_pulse_effect()
    if sound_manager:
        sound_manager.play_pulse_warning()
    
    Logger.warning("ВЫБРОС начался! Уровень: " + str(level), "ZoneController")


func _on_radiation_pulse_ended():
    radiation_pulse_ended.emit()
    Signals.radiation_pulse_ended.emit()
    Logger.info("Выброс закончился", "ZoneController")


func _on_wave_started(wave_number: int, count: int):
    wave_started.emit(wave_number, count)
    Signals.wave_started.emit(wave_number, count, progression_manager.get_current_difficulty())
    
    Logger.info("Волна " + str(wave_number) + " началась, сталкеров: " + str(count), "ZoneController")


func _on_wave_ended(wave_number: int, survivors: int):
    wave_ended.emit(wave_number, survivors)
    Signals.wave_ended.emit(wave_number, survivors, spawn_manager.get_stalker_count())
    
    Logger.info("Волна " + str(wave_number) + " закончилась, выжило: " + str(survivors), "ZoneController")


func _on_stalker_died(stalker: Node, biomass_returned: float):
    resource_manager.add_biomass(biomass_returned)
    progression_manager.record_stalker_killed()
    
    var stalker_type = "unknown"
    if stalker.has_method("get_stalker_type"):
        stalker_type = stalker.get_stalker_type()
    
    Signals.stalker_died.emit(stalker, stalker_type, stalker.global_position, biomass_returned)
    Logger.debug("Сталкер погиб: " + stalker_type + ", возвращено биомассы: " + str(biomass_returned), "ZoneController")


func _on_mutant_spawned(mutant: Node, mutant_type: String):
    progression_manager.record_mutant_spawned()
    Logger.debug("Мутант заспавнен: " + mutant_type, "ZoneController")


func _on_anomaly_created(anomaly: Node, anomaly_type: String, difficulty: int):
    if particle_manager:
        particle_manager.spawn_anomaly_effects(anomaly.global_position, anomaly_type)
    if sound_manager:
        sound_manager.play_anomaly_sound(anomaly_type)
    
    progression_manager.record_anomaly_created()
    Logger.debug("Аномалия создана: " + anomaly_type, "ZoneController")


func _on_anomaly_destroyed(anomaly_type: String, position: Vector3, difficulty: int):
    # Создаем артефакт
    var artifact_type = anomaly_artifact_map.get(anomaly_type, "common")
    var rarity = difficulty_to_rarity.get(difficulty, "common")
    var values = artifact_values.get(rarity, [10])
    var value = values[randi() % values.size()]
    
    create_artifact(artifact_type, position, rarity, value)
    
    if particle_manager:
        particle_manager.spawn_particles_at(position, "spark", 1.0)
    
    Logger.debug("Аномалия уничтожена, создан артефакт: " + artifact_type, "ZoneController")


func _on_artifact_created(artifact: Node, artifact_type: String, position: Vector3):
    if particle_manager:
        particle_manager.spawn_particles_at(position, "spark", 0.5)
    
    Logger.debug("Артефакт создан: " + artifact_type, "ZoneController")


func _on_artifact_stolen(artifact: Node, stalker: Node):
    var loss = 10.0
    if artifact.has_method("get_value"):
        loss = artifact.get_value()
    
    resource_manager.spend_biomass(loss)
    progression_manager.record_artifact_stolen()
    
    Signals.artifact_stolen.emit(artifact, stalker, loss)
    Logger.warning("Артефакт украден! Потеряно биомассы: " + str(loss), "ZoneController")


func _on_game_over():
    game_over.emit()
    Signals.game_over.emit(false, progression_manager.get_current_run(), 0)
    
    Logger.error("GAME OVER", "ZoneController")
    finish_run(false)


func _on_game_won(run_number: int, reward: float):
    resource_manager.add_biomass(reward)
    game_won.emit(run_number, reward)
    Signals.game_won.emit(run_number, reward)
    
    Logger.info("ПОБЕДА! Забег #" + str(run_number) + " награда: " + str(reward), "ZoneController")
    finish_run(true)


# ==================== ПУБЛИЧНОЕ API ====================

# Ресурсы
func get_energy() -> float: 
    return resource_manager.get_energy() if resource_manager else 0.0

func get_biomass() -> float: 
    return resource_manager.get_biomass() if resource_manager else 0.0

func add_energy(amount: float): 
    if resource_manager: resource_manager.add_energy(amount)

func add_biomass(amount: float): 
    if resource_manager: resource_manager.add_biomass(amount)

func spend_energy(amount: float) -> bool: 
    return resource_manager.spend_energy(amount) if resource_manager else false

func spend_biomass(amount: float) -> bool: 
    return resource_manager.spend_biomass(amount) if resource_manager else false

func can_afford(energy: float, biomass: float) -> bool: 
    return resource_manager.can_afford(energy, biomass) if resource_manager else false

# Аномалии
func create_anomaly(type: String, position: Vector3, difficulty: int = 1) -> Node:
    if not anomaly_manager:
        return null
    
    var cost = anomaly_manager.get_anomaly_cost(type)
    if not resource_manager.spend_energy(cost):
        Logger.warning("Недостаточно энергии для " + type + " (нужно: " + str(cost) + ")", "ZoneController")
        return null
    
    return anomaly_manager.create_anomaly(type, position, difficulty, cost)

# Артефакты
func create_artifact(artifact_type: String, position: Vector3, rarity: String = "common", value: float = 10.0) -> Node:
    if not anomaly_manager:
        return null
    return anomaly_manager.create_artifact(artifact_type, position, rarity, value)

# Мутанты
func spawn_mutant(mutant_type: String, position: Vector3) -> Node:
    if not spawn_manager:
        return null
    
    var cost = spawn_manager.get_mutant_cost(mutant_type)
    if not resource_manager.spend_biomass(cost):
        Logger.warning("Недостаточно биомассы для " + mutant_type + " (нужно: " + str(cost) + ")", "ZoneController")
        return null
    
    return spawn_manager.spawn_mutant(mutant_type, position, cost)

# Регистрация
func register_stalker(stalker: Node):
    if spawn_manager:
        spawn_manager.active_stalkers.append(stalker)

# Информация
func get_difficulty() -> float: 
    return progression_manager.get_current_difficulty() if progression_manager else 1.0

func get_run_number() -> int: 
    return progression_manager.get_current_run() if progression_manager else 1

func get_pulse_count() -> int: 
    return event_manager.get_pulse_count() if event_manager else 0

func get_pulses_remaining() -> int: 
    return event_manager.get_pulses_remaining() if event_manager else pulses_to_win

func is_radiating() -> bool: 
    return event_manager.is_pulse_active() if event_manager else false

func has_won() -> bool: 
    return event_manager.has_won() if event_manager else false

func get_status() -> Dictionary:
    return {
        "energy": get_energy(),
        "max_energy": max_energy,
        "biomass": get_biomass(),
        "max_biomass": max_biomass,
        "difficulty": get_difficulty(),
        "run_number": get_run_number(),
        "pulse_count": get_pulse_count(),
        "pulses_remaining": get_pulses_remaining(),
        "radiating": is_radiating(),
        "stalkers": spawn_manager.get_stalker_count() if spawn_manager else 0,
        "mutants": spawn_manager.get_mutant_count() if spawn_manager else 0,
        "anomalies": anomaly_manager.get_anomaly_count() if anomaly_manager else 0,
        "artifacts": anomaly_manager.get_artifact_count() if anomaly_manager else 0
    }


# ==================== ЗАВЕРШЕНИЕ ЗАБЕГА ====================

func finish_run(success: bool):
    Logger.info("Завершение забега. Успех: " + str(success), "ZoneController")
    
    # Останавливаем спавн
    if spawn_manager:
        spawn_manager.stop_spawning()
    
    # Собираем результаты
    var result = _collect_run_result(success)
    
    # Передаем в GameManager
    var gm = Engine.get_singleton("GameManager")
    if gm and gm.has_method("process_run_result"):
        gm.process_run_result(result)
    
    # Ждем и переходим в лабораторию
    await get_tree().create_timer(3.0).timeout
    get_tree().change_scene_to_file("res://ui/lab/lab.tscn")


func _collect_run_result(success: bool) -> Dictionary:
    var run_number = progression_manager.get_current_run() if progression_manager else 1
    var reward = resource_manager.accumulated_biomass if resource_manager else 0.0
    
    var stats = {
        "stalkers_killed": progression_manager.get_stalkers_killed() if progression_manager else 0,
        "anomalies_created": progression_manager.get_anomalies_created() if progression_manager else 0,
        "mutants_created": progression_manager.get_mutants_spawned() if progression_manager else 0,
        "artifacts_stolen": progression_manager.get_artifacts_stolen() if progression_manager else 0,
        "biomass_earned": resource_manager.accumulated_biomass if resource_manager else 0.0,
        "biomass_spent": 0  # TODO: отслеживать траты
    }
    
    return {
        "success": success,
        "run_number": run_number,
        "reward": reward,
        "statistics": stats,
        "artifacts_collected": _collect_artifacts()
    }


func _collect_artifacts() -> Array:
    var artifacts = []
    var nodes = get_tree().get_nodes_in_group("artifacts")
    
    for a in nodes:
        if is_instance_valid(a) and a.has_method("get_rarity_name") and a.has_method("get_value"):
            artifacts.append({
                "type": a.get_rarity_name(),
                "value": a.get_value()
            })
    
    return artifacts