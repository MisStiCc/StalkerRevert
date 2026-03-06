extends BaseAnomaly
class_name ThermalSteam

@export var steam_radius: float = 7.0
@export var steam_color: Color = Color(0.9, 0.9, 0.8, 0.7)
@export var steam_height: float = 10.0
@export var steam_rise_speed: float = 3.0
@export var particle_count: int = 500


func _ready():
	anomaly_type = "thermal_steam"
	difficulty_level = 2
	anomaly_name = "Пар"
	damage_per_second = 20.0
	
	super._ready()
	_update_size()
	_update_color()


func _setup_particles():
	var particles = $SteamCloud
	if particles:
		particles.amount = particle_count
		particles.emitting = true


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = steam_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = steam_radius
		mesh.mesh.height = steam_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = steam_color
		mesh.material_override.emission = steam_color


func _process(delta):
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker) and stalker.has_method("take_damage"):
			stalker.take_damage(damage_per_second * delta)
			energy_consumed.emit(damage_per_second * delta)
