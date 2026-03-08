# components/navigation_component.gd
extends Node
class_name NavigationComponent

## Компонент навигации - управляет движением к цели

signal target_reached
signal target_updated(new_target: Vector3)
signal path_blocked
signal navigation_failed

# Владелец
var entity: CharacterBody3D

# Навигационный агент
var nav_agent: NavigationAgent3D = null:
    set(value):
        nav_agent = value
        if nav_agent:
            nav_agent.velocity_computed.connect(_on_velocity_computed)
            nav_agent.navigation_finished.connect(_on_navigation_finished)
            nav_agent.path_changed.connect(_on_path_changed)
            Logger.debug("NavigationAgent3D подключен", "NavigationComponent")

# Параметры
var move_speed: float = 5.0:
    set(value):
        move_speed = value
        if nav_agent:
            nav_agent.max_speed = move_speed

var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false
var is_patrolling: bool = false
var terrain_multiplier: float = 1.0

# Патрулирование
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var patrol_loop: bool = true

# Внутреннее состояние
var _path: PackedVector3Array = []
var _last_entity_pos: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _stuck_threshold: float = 2.0
var _stuck_distance: float = 0.5


func _ready():
    if not nav_agent and entity:
        nav_agent = entity.get_node_or_null("NavigationAgent3D")
        if nav_agent:
            nav_agent.velocity_computed.connect(_on_velocity_computed)
            nav_agent.navigation_finished.connect(_on_navigation_finished)
            nav_agent.path_changed.connect(_on_path_changed)
    
    set_process(true)
    set_physics_process(true)
    
    Logger.debug("NavigationComponent инициализирован", "NavigationComponent")


func _process(delta):
    if not is_moving or not nav_agent:
        return
    
    # Проверка на застревание
    if _last_entity_pos.distance_to(entity.global_position) < _stuck_distance:
        _stuck_timer += delta
        if _stuck_timer >= _stuck_threshold:
            Logger.warning("Застревание обнаружено", "NavigationComponent")
            path_blocked.emit()
            _stuck_timer = 0.0
    else:
        _stuck_timer = 0.0
    
    _last_entity_pos = entity.global_position


func _physics_process(_delta):
    if not nav_agent or not is_moving:
        return
    
    if nav_agent.is_navigation_finished():
        _on_navigation_finished()
        return
    
    _continue_movement()


func _continue_movement():
    var next_pos = nav_agent.get_next_path_position()
    var direction = (next_pos - entity.global_position).normalized()
    var velocity = direction * move_speed * terrain_multiplier
    
    if nav_agent.avoidance_enabled:
        nav_agent.velocity = velocity
    else:
        entity.velocity = velocity
        entity.move_and_slide()


func _on_velocity_computed(safe_velocity: Vector3):
    entity.velocity = safe_velocity
    entity.move_and_slide()


func _on_navigation_finished():
    is_moving = false
    target_reached.emit()
    
    if is_patrolling and patrol_points.size() > 0:
        _advance_patrol()
    
    Logger.debug("Навигация завершена", "NavigationComponent")


func _on_path_changed():
    _path = nav_agent.get_nav_path()
    Logger.debug("Путь обновлен, точек: " + str(_path.size()), "NavigationComponent")


func _advance_patrol():
    current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
    move_to(patrol_points[current_patrol_index])
    Logger.debug("Переход к следующей точке патруля: " + str(current_patrol_index), "NavigationComponent")


# ==================== ПУБЛИЧНОЕ API ====================

func move_to(position: Vector3):
    if not nav_agent:
        Logger.error("NavigationAgent3D не назначен", "NavigationComponent")
        navigation_failed.emit()
        return
    
    target_position = position
    nav_agent.target_position = position
    is_moving = true
    is_patrolling = false
    target_updated.emit(position)
    
    Logger.debug("Движение к цели: " + str(position), "NavigationComponent")


func set_patrol_points(points: Array[Vector3], start_index: int = 0, loop: bool = true):
    patrol_points = points
    current_patrol_index = clamp(start_index, 0, points.size() - 1) if points.size() > 0 else 0
    patrol_loop = loop
    is_patrolling = true
    
    if points.size() > 0:
        move_to(points[current_patrol_index])
        Logger.debug("Патруль установлен, точек: " + str(points.size()), "NavigationComponent")
    else:
        Logger.warning("Патруль без точек", "NavigationComponent")


func stop():
    is_moving = false
    is_patrolling = false
    if nav_agent:
        nav_agent.target_position = entity.global_position
    Logger.debug("Движение остановлено", "NavigationComponent")


func pause():
    is_moving = false
    Logger.debug("Движение приостановлено", "NavigationComponent")


func resume():
    if target_position != Vector3.ZERO:
        is_moving = true
        Logger.debug("Движение возобновлено", "NavigationComponent")


func set_speed(speed: float):
    move_speed = speed
    Logger.debug("Скорость изменена на " + str(speed), "NavigationComponent")


func set_terrain_multiplier(mult: float):
    terrain_multiplier = mult
    Logger.debug("Множитель местности изменен на " + str(mult), "NavigationComponent")


func get_distance_to_target() -> float:
    if not is_moving:
        return INF
    return entity.global_position.distance_to(target_position)


func get_path_length() -> float:
    if _path.size() < 2:
        return 0.0
    
    var length = 0.0
    for i in range(_path.size() - 1):
        length += _path[i].distance_to(_path[i + 1])
    
    return length


func get_remaining_path_length() -> float:
    if _path.size() < 2:
        return 0.0
    
    var length = 0.0
    var start_index = 0
    
    # Находим ближайшую точку на пути
    for i in range(_path.size()):
        if _path[i].distance_to(entity.global_position) < 2.0:
            start_index = i
            break
    
    for i in range(start_index, _path.size() - 1):
        length += _path[i].distance_to(_path[i + 1])
    
    return length


func has_valid_path() -> bool:
    return _path.size() > 1


func get_target() -> Vector3:
    return target_position


func is_navigating() -> bool:
    return is_moving


func get_current_patrol_index() -> int:
    return current_patrol_index


func get_patrol_points() -> Array[Vector3]:
    return patrol_points.duplicate()