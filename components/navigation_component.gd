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
			nav_agent.target_desired_distance = 2.0
			nav_agent.path_desired_distance = 1.0
			print("NavigationAgent3D подключен")

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
var _last_entity_pos: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _stuck_threshold: float = 5.0  # Увеличил до 5 секунд
var _stuck_distance: float = 1.0    # Увеличил до 1 метра
var _last_target: Vector3 = Vector3.ZERO
var _move_start_time: float = 0.0


func _ready():
	if not nav_agent and entity:
		nav_agent = entity.get_node_or_null("NavigationAgent3D")
		if nav_agent:
			nav_agent.velocity_computed.connect(_on_velocity_computed)
			nav_agent.navigation_finished.connect(_on_navigation_finished)
			nav_agent.target_desired_distance = 2.0
			nav_agent.path_desired_distance = 1.0
	
	set_process(true)
	set_physics_process(true)
	
	print("NavigationComponent инициализирован")


func _process(delta):
	if not is_moving or not nav_agent:
		return
	
	# Проверка на застревание - только если прошло достаточно времени
	if _move_start_time > 2.0:
		if _last_entity_pos.distance_to(entity.global_position) < _stuck_distance:
			_stuck_timer += delta
			if _stuck_timer >= _stuck_threshold:
				print("Застревание обнаружено, ищу новый путь")
				path_blocked.emit()
				# Пробуем переустановить цель
				if _last_target != Vector3.ZERO:
					nav_agent.target_position = _last_target
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
	
	var next_pos = nav_agent.get_next_path_position()
	if next_pos == Vector3.ZERO:
		return
	
	var direction = (next_pos - entity.global_position).normalized()
	var desired_velocity = direction * move_speed * terrain_multiplier
	
	if nav_agent.avoidance_enabled:
		nav_agent.velocity = desired_velocity
	else:
		entity.velocity = desired_velocity
		entity.move_and_slide()


func _on_velocity_computed(safe_velocity: Vector3):
	entity.velocity = safe_velocity
	entity.move_and_slide()


func _on_navigation_finished():
	is_moving = false
	target_reached.emit()
	
	if is_patrolling and patrol_points.size() > 0:
		_advance_patrol()
	
	print("Навигация завершена")


func _advance_patrol():
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	move_to(patrol_points[current_patrol_index])
	print("Переход к следующей точке патруля: " + str(current_patrol_index))


# ==================== ПУБЛИЧНОЕ API ====================

func move_to(position: Vector3):
	if not nav_agent:
		print("NavigationAgent3D не назначен")
		navigation_failed.emit()
		return
	
	_last_target = position
	target_position = position
	nav_agent.target_position = position
	is_moving = true
	is_patrolling = false
	_stuck_timer = 0.0
	_move_start_time = 0.0
	_last_entity_pos = entity.global_position
	target_updated.emit(position)
	
	print("Движение к цели: " + str(position))


func set_patrol_points(points: Array[Vector3], start_index: int = 0, loop: bool = true):
	patrol_points = points
	current_patrol_index = clamp(start_index, 0, points.size() - 1) if points.size() > 0 else 0
	patrol_loop = loop
	is_patrolling = true
	
	if points.size() > 0:
		move_to(points[current_patrol_index])
		print("Патруль установлен, точек: " + str(points.size()))
	else:
		print("Патруль без точек")


func stop():
	is_moving = false
	is_patrolling = false
	if nav_agent:
		nav_agent.target_position = entity.global_position
	print("Движение остановлено")


func pause():
	is_moving = false
	print("Движение приостановлено")


func resume():
	if target_position != Vector3.ZERO:
		move_to(target_position)
		print("Движение возобновлено")


func set_speed(speed: float):
	move_speed = speed
	print("Скорость изменена на " + str(speed))


func set_terrain_multiplier(mult: float):
	terrain_multiplier = mult
	print("Множитель местности изменен на " + str(mult))


func get_distance_to_target() -> float:
	if not is_moving:
		return INF
	return entity.global_position.distance_to(target_position)


func has_valid_path() -> bool:
	if not nav_agent:
		return false
	return not nav_agent.is_navigation_finished()


func get_target() -> Vector3:
	return target_position


func is_navigating() -> bool:
	return is_moving


func get_current_patrol_index() -> int:
	return current_patrol_index


func get_patrol_points() -> Array[Vector3]:
	return patrol_points.duplicate()