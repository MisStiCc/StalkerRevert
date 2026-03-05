extends Camera3D
class_name GameCamera

## Камера с поддержкой вида сверху (top-down) и от третьего лица (third-person)

signal view_mode_changed(mode: String)

@export_enum("TopDown", "ThirdPerson") var current_mode: String = "ThirdPerson"

# Параметры камеры
@export var follow_target: Node3D = null
@export var top_down_height: float = 30.0  # Высота для вида сверху
@export var top_down_angle: float = -70.0  # Угол наклона для вида сверху (в градусах)
@export var third_person_distance: float = 8.0  # Расстояние от игрока
@export var third_person_height: float = 3.0  # Высота камеры
@export var rotation_speed: float = 2.0  # Скорость вращения
@export var smooth_speed: float = 5.0  # Плавность движения

# Внутренние переменные
var current_rotation: float = 0.0
var target_position: Vector3 = Vector3.ZERO

func _ready():
	# Ищем цель для слежения
	if not follow_target:
		follow_target = get_tree().get_first_node_in_group("player")
	if not follow_target:
		follow_target = get_tree().get_first_node_in_group("stalkers")
	
	# Установка начальной позиции
	_update_camera_position()
	
	print("GameCamera: инициализирована в режиме ", current_mode)

func _process(delta):
	if not follow_target or not is_instance_valid(follow_target):
		return
	
	# Обработка ввода
	_handle_input(delta)
	
	# Обновление позиции камеры
	_update_camera_position(delta)

func _handle_input(delta):
	# Переключение режимов
	if Input.is_action_just_pressed("camera_switch"):
		switch_view_mode()
	
	# Вращение камеры (только в третьем лице)
	if current_mode == "ThirdPerson":
		if Input.is_action_pressed("camera_left"):
			current_rotation -= rotation_speed * delta
		if Input.is_action_pressed("camera_right"):
			current_rotation += rotation_speed * delta

func _update_camera_position(delta: float = 0.0):
	if not follow_target:
		return
	
	var target_pos = follow_target.global_position
	
	match current_mode:
		"TopDown":
			# Вид сверху - камера над игроком
			target_position = Vector3(
				target_pos.x,
				target_pos.y + top_down_height,
				target_pos.z
			)
			look_at(target_pos)
			
		"ThirdPerson":
			# Третье лицо - камера сзади и выше игрока
			var offset = Vector3(
				sin(current_rotation) * third_person_distance,
				third_person_height,
				cos(current_rotation) * third_person_distance
			)
			target_position = target_pos + offset
			look_at(target_pos + Vector3(0, 1.5, 0))  # Смотрим на игрока
	
	# Плавное движение камеры
	global_position = global_position.lerp(target_position, smooth_speed * delta if delta > 0 else 1.0)

func switch_view_mode():
	"""Переключение между режимами камеры"""
	if current_mode == "TopDown":
		current_mode = "ThirdPerson"
	else:
		current_mode = "TopDown"
	
	view_mode_changed.emit(current_mode)
	print("GameCamera: переключено на режим ", current_mode)

func set_follow_target(target: Node3D):
	"""Установка цели для слежения"""
	follow_target = target

func get_current_mode() -> String:
	return current_mode

func set_top_down_height(height: float):
	top_down_height = height

func set_third_person_distance(distance: float):
	third_person_distance = distance
