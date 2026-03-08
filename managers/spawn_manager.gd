# managers/spawn_manager.gd
extends Node
class_name SpawnManager

## Менеджер спавна - управляет сталкерами и мутантами

signal wave_started(wave_number: int, count: int)
signal wave_ended(wave_number: int, survivors: int)
signal stalker_spawned(stalker: Node, stalker_type: String)
signal mutant_spawned(mutant: Node, mutant_type: String)
signal stalker_died(stalker: Node, biomass_returned: float)

# Параметры спавна
@export var spawn_interval: float = 30.0
@export var min_stalkers_per_wave: int = 3
@export var max_stalkers_per_wave: int = 6
@export var spawn_radius: float = 80.0
@export var min_spawn_distance: float = 60.0

# Сцены сталкеров
var stalker_scenes: Dictionary = {
    "novice": null,
    "veteran": null,
    "master": null
}

# Сцены мутантов
var mutant_scenes: Dictionary = {}

# Стоимость мутантов
var mutant_costs: Dictionary = {
    "dog_mutant": 15.0,
    "flesh": 15.0,
    "snork_mutant": 25.0,
    "pseudodog": 25.0,
    "controller_mutant": 40.0,
    "poltergeist": 40.0,
    "bloodsucker": 50.0,
    "chimera": 75.0,
    "pseudogiant": 75.0,
    "zombie": 10.0
}

# Возврат биомассы за сталкеров
var stalker_biomass_returns: Dictionary = {
    "novice": 8.0,
    "veteran": 15.0,
    "master": 30.0,
    "greedy": 8.0,
    "brave": 12.0,
    "cautious": 10.0,
    "aggressive": 15.0,
    "stealthy": 6.0
}

# Множители из лаборатории
var health_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var cost_multiplier: float = 1.0

# Активные объекты
var active_stalkers: Array[Node] = []
var active_mutants: Array[Node] = []

# Состояние
var current_wave: int = 0
var is_spawning: bool = false
var is_active: bool = true
var _difficulty: float = 1.0
var _monolith: Node = null
var _wave_timer: Timer

# Статистика
var _stalkers_killed: int = 0
var _artifacts_stolen: int = 0
var _mutants_spawned: int = 0


func _ready():
    _monolith = get_tree().get_first_node_in_group("monolith")
    add_to_group("spawn_manager")
    _setup_timer()
    Logger.info("SpawnManager инициализирован", "SpawnManager")


func _setup_timer():
    _wave_timer = Timer.new()
    _wave_timer.wait_time = spawn_interval
    _wave_timer.timeout.connect(_start_wave)
    add_child(_wave_timer)


# ==================== УПРАВЛЕНИЕ ====================

func start_spawning():
    is_active = true
    _wave_timer.start()
    _start_wave()
    Logger.info("Спавн сталкеров запущен", "SpawnManager")


func stop_spawning():
    is_active = false
    _wave_timer.stop()
    Logger.info("Спавн сталкеров остановлен", "SpawnManager")


func force_wave():
    if is_active and not is_spawning:
        _start_wave()


func set_difficulty(difficulty: float):
    _difficulty = difficulty
    Logger.debug("Сложность спавна: " + str(difficulty), "SpawnManager")


# ==================== ВОЛНЫ СТАЛКЕРОВ ====================

func _start_wave():
    if is_spawning or not is_active:
        return
    
    is_spawning = true
    current_wave += 1
    
    var stalkers_to_spawn = _calculate_stalker_count()
    wave_started.emit(current_wave, stalkers_to_spawn)
    Logger.info("Волна " + str(current_wave) + " начата, сталкеров: " + str(stalkers_to_spawn), "SpawnManager")
    
    # Спавним сталкеров
    var spawned = 0
    for i in range(stalkers_to_spawn):
        if _spawn_stalker():
            spawned += 1
        await get_tree().create_timer(0.3).timeout
    
    is_spawning = false
    wave_ended.emit(current_wave, spawned)
    Logger.info("Волна " + str(current_wave) + " завершена, создано: " + str(spawned), "SpawnManager")


func _calculate_stalker_count() -> int:
    var base = randi_range(min_stalkers_per_wave, max_stalkers_per_wave)
    return ceil(base * _difficulty)


func _spawn_stalker() -> bool:
    var scene = _get_stalker_scene_by_difficulty()
    if not scene:
        Logger.warning("Нет сцены для сталкера", "SpawnManager")
        return false
    
    var pos = _get_spawn_position()
    if pos == Vector3.ZERO:
        Logger.warning("Не удалось найти позицию для спавна", "SpawnManager")
        return false
    
    var stalker = scene.instantiate()
    stalker.position = pos
    
    # Добавляем в дерево ДО look_at
    get_tree().current_scene.add_child(stalker)
    
    # Поворачиваем к монолиту
    if _monolith:
        var dir = (_monolith.global_position - pos).normalized()
        stalker.look_at(pos + dir, Vector3.UP)
    
    # Подключаем сигнал смерти
    if stalker.has_signal("died"):
        stalker.died.connect(_on_stalker_died)
    
    active_stalkers.append(stalker)
    
    var stalker_type = "novice"
    if scene == stalker_scenes.get("veteran"):
        stalker_type = "veteran"
    elif scene == stalker_scenes.get("master"):
        stalker_type = "master"
    
    stalker_spawned.emit(stalker, stalker_type)
    Logger.debug("Сталкер заспавнен: " + stalker_type + " на позиции " + str(pos), "SpawnManager")
    
    return true


func _get_stalker_scene_by_difficulty() -> PackedScene:
    var rand_val = randf()
    
    if _difficulty < 1.2:
        if rand_val < 0.6: return stalker_scenes.get("novice")
        elif rand_val < 0.9: return stalker_scenes.get("veteran")
        else: return stalker_scenes.get("master")
    elif _difficulty < 1.5:
        if rand_val < 0.4: return stalker_scenes.get("novice")
        elif rand_val < 0.8: return stalker_scenes.get("veteran")
        else: return stalker_scenes.get("master")
    elif _difficulty < 2.0:
        if rand_val < 0.3: return stalker_scenes.get("novice")
        elif rand_val < 0.7: return stalker_scenes.get("veteran")
        else: return stalker_scenes.get("master")
    else:
        if rand_val < 0.2: return stalker_scenes.get("novice")
        elif rand_val < 0.6: return stalker_scenes.get("veteran")
        else: return stalker_scenes.get("master")


func _get_spawn_position() -> Vector3:
    if not _monolith:
        return Vector3.ZERO
    
    var angle = randf() * TAU
    var distance = min_spawn_distance + randf() * (spawn_radius - min_spawn_distance)
    var pos = _monolith.global_position + Vector3(cos(angle) * distance, 50, sin(angle) * distance)
    
    # Raycast для поиска земли
    var space = get_viewport().get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.new()
    query.from = pos
    query.to = pos + Vector3(0, -100, 0)
    query.collision_mask = 1
    
    var result = space.intersect_ray(query)
    if result:
        return result.position + Vector3(0, 1.2, 0)
    
    return Vector3.ZERO


func _on_stalker_died(stalker: Node):
    if stalker in active_stalkers:
        active_stalkers.erase(stalker)
    
    # Возвращаем биомассу
    var return_value = 8.0
    if stalker.has_method("get_stalker_type"):
        var stalker_type = stalker.get_stalker_type()
        return_value = stalker_biomass_returns.get(stalker_type, 8.0)
    
    _stalkers_killed += 1
    stalker_died.emit(stalker, return_value)
    Logger.debug("Сталкер погиб, возвращено биомассы: " + str(return_value), "SpawnManager")


# ==================== МУТАНТЫ ====================

func spawn_mutant(mutant_type: String, position: Vector3, biomass_cost: float) -> Node:
    if not mutant_scenes.has(mutant_type):
        Logger.error("Неизвестный тип мутанта: " + mutant_type, "SpawnManager")
        return null
    
    var scene = mutant_scenes[mutant_type]
    if not scene:
        Logger.error("Сцена не найдена для мутанта: " + mutant_type, "SpawnManager")
        return null
    
    var mutant = scene.instantiate()
    mutant.position = position
    
    # Применяем множители
    if mutant.has_method("set_health_multiplier"):
        mutant.set_health_multiplier(health_multiplier)
    if mutant.has_method("set_damage_multiplier"):
        mutant.set_damage_multiplier(damage_multiplier)
    
    get_tree().current_scene.add_child(mutant)
    active_mutants.append(mutant)
    _mutants_spawned += 1
    
    mutant_spawned.emit(mutant, mutant_type)
    Logger.debug("Мутант заспавнен: " + mutant_type + " на позиции " + str(position), "SpawnManager")
    
    return mutant


func remove_mutant(mutant: Node):
    if mutant in active_mutants:
        active_mutants.erase(mutant)
    if is_instance_valid(mutant):
        mutant.queue_free()


func get_mutant_cost(mutant_type: String) -> float:
    var base_cost = mutant_costs.get(mutant_type, 20.0)
    return base_cost * cost_multiplier


# ==================== ГЕТТЕРЫ ====================

func get_active_stalkers() -> Array[Node]:
    return active_stalkers.filter(func(s): return is_instance_valid(s))


func get_active_mutants() -> Array[Node]:
    return active_mutants.filter(func(m): return is_instance_valid(m))


func get_stalker_count() -> int:
    return active_stalkers.size()


func get_mutant_count() -> int:
    return active_mutants.size()


func get_stalkers_killed() -> int:
    return _stalkers_killed


func get_artifacts_stolen() -> int:
    return _artifacts_stolen


func get_total_mutants_spawned() -> int:
    return _mutants_spawned


# ==================== СТАТИСТИКА ====================

func record_artifact_stolen():
    _artifacts_stolen += 1


func reset_statistics():
    _stalkers_killed = 0
    _artifacts_stolen = 0
    _mutants_spawned = 0
    Logger.debug("Статистика спавна сброшена", "SpawnManager")


# ==================== НАСТРОЙКИ ====================

func set_health_multiplier(value: float):
    health_multiplier = value
    Logger.debug("Множитель здоровья мутантов: " + str(value), "SpawnManager")


func set_damage_multiplier(value: float):
    damage_multiplier = value
    Logger.debug("Множитель урона мутантов: " + str(value), "SpawnManager")


func set_cost_multiplier(value: float):
    cost_multiplier = value
    Logger.debug("Множитель стоимости мутантов: " + str(value), "SpawnManager")