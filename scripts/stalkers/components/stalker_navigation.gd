extends Node
class_name StalkerNavigation

## Управление навигацией сталкера
## Работа с NavigationAgent3D

signal target_reached
signal path_blocked

var owner_stalker: CharacterBody3D
var nav_agent: NavigationAgent3D

# Режимы
var is_patrol_mode: bool = false
var current_target: Vector3 = Vector3.ZERO
var is_moving: bool = false

# Параметры
var base_speed: float = 4.0
var current_speed: float = 4.0
var terrain_multiplier: float = 1.0

# Ссылки
var terrain_manager: Node = null


func _init(stalker: CharacterBody3D):
	owner_stalker = stalker


func _ready():
	# Ищем NavigationAgent3D
	nav_agent = owner_stalker.get_node_or_null("NavigationAgent3D")
	if nav_agent:
		nav_agent.velocity_computed.connect(_on_velocity_computed)
		nav_agent.navigation_finished.connect(_on_navigation_finished)
	
	# Ищем TerrainGenerator
	terrain_manager = owner_stalker.get_tree().get_first_node_in_group("terrain_generator")


func _physics_process(_delta: float):
	if not nav_agent or not is_moving:
		return
	
	# Обновляем скорость с учётом местности
	_update_terrain_speed()
	
	# Проверяем достигли ли цели
	if nav_agent.is_navigation_finished():
		_on_navigation_finished()
		return
	
	# Продолжаем движение
	_continue_path_internal()


func _update_terrain_speed():
	"""Обновляет скорость в зависимости от местности"""
	if terrain_manager:
		var terrain_speed = terrain_manager.get_terrain_speed_multiplier(owner_stalker.global_position)
		current_speed = base_speed * terrain_speed * terrain_multiplier
	else:
		current_speed = base_speed * terrain_multiplier


func _continue_path_internal():
	if not nav_agent or nav_agent.is_navigation_finished():
		return
	
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - owner_stalker.global_position).normalized()
	
	# Применяем скорость
	var velocity = direction * current_speed
	
	# Проверяем валидность пути
	if nav_agent.avoidance_enabled:
		nav_agent.velocity = velocity
	else:
		owner_stalker.velocity = velocity
		owner_stalker.move_and_slide()


func _on_velocity_computed(safe_velocity: Vector3):
	owner_stalker.velocity = safe_velocity
	owner_stalker.move_and_slide()


func _on_navigation_finished():
	is_moving = false
	target_reached.emit()


# ==================== ПУБЛИЧНОЕ API ====================

func set_target(position: Vector3):
	"""Установить цель для навигации"""
	if not nav_agent:
		return
	
	current_target = position
	nav_agent.target_position = position
	
	# Запускаем навигацию
	nav_agent.get_path()  # Принудительно обновляем путь
	is_moving = true


func set_flee_target(from_position: Vector3):
	"""Установить цель для бегства (в противоположную сторону)"""
	if not nav_agent:
		return
	
	# Вычисляем точку в противоположном направлении
	var direction = (owner_stalker.global_position - from_position).normalized()
	var flee_distance = 30.0
	current_target = owner_stalker.global_position + direction * flee_distance
	
	nav_agent.target_position = current_target
	is_moving = true


func continue_path():
	"""Продолжить движение по текущему пути"""
	_continue_path_internal()


func stop():
	"""Остановить движение"""
	is_moving = false
	current_target = Vector3.ZERO
	if nav_agent:
		nav_agent.target_position = owner_stalker.global_position


func set_patrol_mode(enabled: bool):
	"""Включить режим патрулирования"""
	is_patrol_mode = enabled


func set_speed(speed: float):
	"""Установить базовую скорость"""
	base_speed = speed
	current_speed = speed * terrain_multiplier
	if nav_agent:
		nav_agent.max_speed = current_speed


func set_terrain_multiplier(mult: float):
	"""Установить множитель скорости от местности"""
	terrain_multiplier = mult
	_update_terrain_speed()


func is_moving() -> bool:
	return is_moving


func get_current_target() -> Vector3:
	return current_target


func get_distance_to_target() -> float:
	return owner_stalker.global_position.distance_to(current_target)


func has_valid_path() -> bool:
	if not nav_agent:
		return false
	return nav_agent.get_nav_path().size() > 0
