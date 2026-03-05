extends BaseAnomaly
class_name TeleportAnomaly

@export var teleport_radius: float = 5.0
@export var teleport_color: Color = Color(0.5, 0, 1, 1)
@export var teleport_range: float = 30.0  # Диапазон телепортации
@export var teleport_cooldown: float = 3.0

var teleported_stalkers: Array[Node] = []
var teleport_timers: Dictionary = {}


func _ready():
	super._ready()
	anomaly_name = "Телепорт"
	damage_per_second = 3.0  # Низкий урон
	
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = teleport_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = teleport_radius
		mesh.mesh.height = teleport_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = teleport_color
		mesh.material_override.emission = teleport_color


func _process(delta):
	# Телепортация сталкеров
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if not teleport_timers.has(stalker.get_instance_id()):
				teleport_timers[stalker.get_instance_id()] = 0.0
			
			teleport_timers[stalker.get_instance_id()] += delta
			
			if teleport_timers[stalker.get_instance_id()] >= teleport_cooldown:
				_teleport_stalker(stalker)
				teleport_timers[stalker.get_instance_id()] = 0.0


func _teleport_stalker(stalker: Node):
	if stalker.has_method("take_damage"):
		stalker.take_damage(damage_per_second * 5.0)  # Урон при телепортации
	
	# Случайная позиция в пределах teleport_range
	var random_offset = Vector3(
		randf_range(-teleport_range, teleport_range),
		0,
		randf_range(-teleport_range, teleport_range)
	)
	stalker.global_position += random_offset
	
	energy_consumed.emit(damage_per_second * 5.0)
