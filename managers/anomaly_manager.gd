# managers/anomaly_manager.gd
extends Node
class_name AnomalyManager

## Менеджер аномалий - создание, уничтожение, связь с артефактами

signal anomaly_created(anomaly: Node, anomaly_type: String, difficulty: int)
signal anomaly_destroyed(anomaly_type: String, position: Vector3, difficulty: int)
signal artifact_created(artifact: Node, artifact_type: String, position: Vector3)
signal artifact_stolen(artifact: Node, stalker: Node)

# Сцены аномалий (загружаются из конфига)
var anomaly_scenes: Dictionary = {}

# Маппинг аномалия -> артефакт
var anomaly_artifact_map: Dictionary = {}

# Ценности артефактов по редкости
var artifact_values: Dictionary = {}

# Маппинг сложности -> редкость
var difficulty_to_rarity: Dictionary = {}

# Активные объекты
var active_anomalies: Array[Node] = []
var active_artifacts: Array[Node] = []

# Таймеры для артефактов
var artifact_timers: Dictionary = {}  # artifact_instance_id -> Timer

# Множители из лаборатории
var damage_multiplier: float = 1.0
var radius_multiplier: float = 1.0


func _ready():
    add_to_group("anomaly_manager")
    Logger.info("AnomalyManager инициализирован", "AnomalyManager")


# ==================== АНОМАЛИИ ====================

func create_anomaly(anomaly_type: String, position: Vector3, difficulty: int, energy_cost: float) -> Node:
    if not anomaly_scenes.has(anomaly_type):
        Logger.error("Неизвестный тип аномалии: " + anomaly_type, "AnomalyManager")
        return null
    
    var scene = anomaly_scenes[anomaly_type]
    var anomaly = scene.instantiate()
    anomaly.position = position
    
    # Устанавливаем сложность
    if anomaly.has_method("set_difficulty"):
        anomaly.set_difficulty(difficulty)
    
    # Применяем множители из лаборатории
    if anomaly.has_method("set_damage_multiplier"):
        anomaly.set_damage_multiplier(damage_multiplier)
    if anomaly.has_method("set_radius_multiplier"):
        anomaly.set_radius_multiplier(radius_multiplier)
    
    # Подключаем сигнал уничтожения
    if anomaly.has_signal("destroyed"):
        anomaly.destroyed.connect(_on_anomaly_destroyed)
    
    anomaly.add_to_group("anomalies")
    get_tree().current_scene.add_child(anomaly)
    active_anomalies.append(anomaly)
    
    anomaly_created.emit(anomaly, anomaly_type, difficulty)
    Logger.info("Аномалия создана: " + anomaly_type + " на позиции " + str(position), "AnomalyManager")
    
    return anomaly


func remove_anomaly(anomaly: Node):
    if is_instance_valid(anomaly):
        active_anomalies.erase(anomaly)
        anomaly.queue_free()
        Logger.debug("Аномалия удалена", "AnomalyManager")


func get_active_anomalies() -> Array[Node]:
    return active_anomalies.filter(func(a): return is_instance_valid(a))


func get_anomaly_count() -> int:
    return active_anomalies.size()


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


func _on_anomaly_destroyed(anomaly: Node):
    # Получаем информацию
    var anomaly_type = "unknown"
    var difficulty = 1
    var position = anomaly.global_position
    
    if anomaly.has_method("get_type_name"):
        anomaly_type = anomaly.get_type_name()
    if anomaly.has_method("get_difficulty"):
        difficulty = anomaly.get_difficulty()
    
    # Удаляем из списка
    active_anomalies.erase(anomaly)
    
    # Создаём артефакт
    var artifact_type = anomaly_artifact_map.get(anomaly_type, "common_artifact")
    var rarity = difficulty_to_rarity.get(difficulty, "common")
    var values = artifact_values.get(rarity, [10])
    var value = values[randi() % values.size()]
    
    create_artifact(artifact_type, position, rarity, value)
    
    anomaly_destroyed.emit(anomaly_type, position, difficulty)
    Logger.info("Аномалия уничтожена, создан артефакт: " + artifact_type, "AnomalyManager")


# ==================== АРТЕФАКТЫ ====================

func create_artifact(artifact_type: String, position: Vector3, rarity: String = "common", value: float = 10.0) -> Node:
    # Пробуем загрузить сцену
    var scene_path = "res://entities/artifacts/" + artifact_type + ".tscn"
    if not ResourceLoader.exists(scene_path):
        Logger.error("Сцена артефакта не найдена: " + scene_path, "AnomalyManager")
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
    _start_artifact_timer(artifact)
    
    artifact_created.emit(artifact, artifact_type, position)
    Logger.debug("Артефакт создан: " + artifact_type + " на позиции " + str(position), "AnomalyManager")
    
    return artifact


func _on_artifact_stolen(artifact: Node, stalker: Node):
    # Останавливаем таймер
    _stop_artifact_timer(artifact)
    
    artifact_stolen.emit(artifact, stalker)
    Logger.info("Артефакт украден сталкером: " + str(stalker), "AnomalyManager")


func _on_artifact_collected(artifact: Node, collector: Node):
    if artifact in active_artifacts:
        active_artifacts.erase(artifact)
    _stop_artifact_timer(artifact)
    Logger.debug("Артефакт собран: " + str(collector), "AnomalyManager")


func _start_artifact_timer(artifact: Node):
    var id = artifact.get_instance_id()
    if artifact_timers.has(id):
        return
    
    var timer = Timer.new()
    timer.wait_time = 30.0  # 30 секунд до превращения
    timer.one_shot = true
    timer.timeout.connect(_on_artifact_timeout.bind(artifact))
    add_child(timer)
    timer.start()
    
    artifact_timers[id] = timer
    Logger.debug("Таймер артефакта запущен на 30с", "AnomalyManager")


func _stop_artifact_timer(artifact: Node):
    var id = artifact.get_instance_id()
    if artifact_timers.has(id):
        var timer = artifact_timers[id]
        if is_instance_valid(timer):
            timer.stop()
            timer.queue_free()
        artifact_timers.erase(id)


func _on_artifact_timeout(artifact: Node):
    if not is_instance_valid(artifact):
        artifact_timers.erase(artifact.get_instance_id())
        return
    
    Logger.info("Артефакт превращается в аномалию", "AnomalyManager")
    
    # Удаляем артефакт
    active_artifacts.erase(artifact)
    _stop_artifact_timer(artifact)
    artifact.queue_free()
    
    # TODO: Создать аномалию на этом месте
    # create_anomaly("some_type", artifact.global_position, 1, 0)


func remove_all_artifacts():
    for artifact in active_artifacts:
        if is_instance_valid(artifact):
            artifact.queue_free()
    active_artifacts.clear()
    
    for timer in artifact_timers.values():
        if is_instance_valid(timer):
            timer.stop()
            timer.queue_free()
    artifact_timers.clear()
    
    Logger.info("Все артефакты удалены", "AnomalyManager")


func stop_all_timers():
    for timer in artifact_timers.values():
        if is_instance_valid(timer):
            timer.stop()
    Logger.debug("Все таймеры артефактов остановлены", "AnomalyManager")


func get_active_artifacts() -> Array[Node]:
    return active_artifacts.filter(func(a): return is_instance_valid(a))


func get_artifact_count() -> int:
    return active_artifacts.size()


# ==================== НАСТРОЙКИ ====================

func set_damage_multiplier(value: float):
    damage_multiplier = value
    Logger.debug("Множитель урона аномалий: " + str(value), "AnomalyManager")


func set_radius_multiplier(value: float):
    radius_multiplier = value
    Logger.debug("Множитель радиуса аномалий: " + str(value), "AnomalyManager")


func load_config(config: Dictionary):
    if config.has("anomaly_scenes"):
        anomaly_scenes = config["anomaly_scenes"]
    if config.has("anomaly_artifact_map"):
        anomaly_artifact_map = config["anomaly_artifact_map"]
    if config.has("artifact_values"):
        artifact_values = config["artifact_values"]
    if config.has("difficulty_to_rarity"):
        difficulty_to_rarity = config["difficulty_to_rarity"]
    
    Logger.info("Конфигурация загружена", "AnomalyManager")