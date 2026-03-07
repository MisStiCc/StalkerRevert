extends Node
class_name FogManager

## Управление атмосферным туманом
## Туман зависит от высоты камеры и типа местности

signal fog_density_changed(density: float)

@export var enabled: bool = true
@export var base_density: float = 0.02
@export var max_density: float = 0.08
@export var height_falloff: float = 15.0  # Высота, на которой туман исчезает
@export var ground_fog_height: float = 3.0  # Высота тумана над землёй

@export var fog_color: Color = Color(0.7, 0.75, 0.8)
@export var ground_fog_color: Color = Color(0.8, 0.85, 0.9)

var camera: Camera3D = null
var world_environment: WorldEnvironment = null
var current_density: float = 0.0


func _ready():
	add_to_group("fog_manager")
	_find_camera_and_environment()
	print("🌫️ FogManager: инициализирован")


func _find_camera_and_environment():
	camera = get_viewport().get_camera_3d()
	
	# Ищем WorldEnvironment в сцене
	var env_node = get_tree().get_first_node_in_group("world_environment")
	if env_node:
		world_environment = env_node
	else:
		# Создаём если нет
		world_environment = WorldEnvironment.new()
		world_environment.name = "WorldEnvironment"
		world_environment.add_to_group("world_environment")
		
		var env = Environment.new()
		env.background_mode = Environment.BG_SKY
		env.fog_enabled = true
		env.fog_light_color = fog_color
		env.fog_density = base_density
		env.fog_height = ground_fog_height
		env.fog_height_density = 0.5
		
		world_environment.environment = env
		get_tree().current_scene.add_child(world_environment)


func _process(_delta):
	if not enabled or not camera or not world_environment:
		return
	
	var camera_height = camera.global_position.y
	var new_density = _calculate_density(camera_height)
	
	if abs(new_density - current_density) > 0.001:
		current_density = new_density
		_apply_fog(new_density)
		fog_density_changed.emit(new_density)


func _calculate_density(camera_height: float) -> float:
	# Чем выше камера, тем меньше тумана
	var height_factor = clamp(1.0 - (camera_height / height_falloff), 0.0, 1.0)
	
	# Базовое значение + вариация по высоте
	var density = base_density + (max_density - base_density) * height_factor
	
	# Добавляем небольшую случайную вариацию для реализма
	density += sin(Time.get_ticks_msec() * 0.001) * 0.002
	
	return clamp(density, 0.0, max_density)


func _apply_fog(density: float):
	if not world_environment or not world_environment.environment:
		return
	
	var env = world_environment.environment
	env.fog_enabled = enabled
	env.fog_density = density
	env.fog_light_color = fog_color
	env.fog_height = ground_fog_height
	env.fog_height_density = 0.5


func set_enabled(value: bool):
	enabled = value
	if not enabled and world_environment and world_environment.environment:
		world_environment.environment.fog_enabled = false


func set_density(value: float):
	base_density = value
	current_density = value
	_apply_fog(value)


func set_fog_color(color: Color):
	fog_color = color
	if world_environment and world_environment.environment:
		world_environment.environment.fog_light_color = color


func get_current_density() -> float:
	return current_density


func is_visible() -> bool:
	return enabled and current_density > 0.005
