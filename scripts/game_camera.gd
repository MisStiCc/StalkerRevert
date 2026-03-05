extends Camera3D
class_name GameCamera

## Камера с ручным управлением (WASD + мышь)

# Скорости
@export var move_speed: float = 20.0
@export var look_speed: float = 0.002

# Внутренние переменные
var mouse_captured: bool = false
var rotation_x: float = 0.0
var rotation_y: float = 0.0


func _ready():
	# Захватываем мышь
	_capture_mouse()
	
	# Ставим камеру на хорошую позицию для обзора
	global_position = Vector3(20, 30, 20)
	rotation_degrees = Vector3(-45, 45, 0)
	
	print("GameCamera: готова к работе")


func _input(event):
	# Вращение от мыши
	if event is InputEventMouseMotion and mouse_captured:
		rotation_y -= event.relative.x * look_speed
		rotation_x -= event.relative.y * look_speed
		rotation_x = clamp(rotation_x, -1.4, 1.4)  # Не даём перевернуться
		
		rotation.y = rotation_y
		rotation.x = rotation_x
	
	# Escape — отпустить/захватить мышь
	if event.is_action_pressed("ui_cancel"):
		if mouse_captured:
			_release_mouse()
		else:
			_capture_mouse()


func _process(delta):
	# Движение WASD
	var input_dir = Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += transform.basis.x
	if Input.is_key_pressed(KEY_SPACE):
		input_dir += Vector3.UP
	if Input.is_key_pressed(KEY_SHIFT):
		input_dir -= Vector3.UP
	
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		global_position += input_dir * move_speed * delta


func _capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func _release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false