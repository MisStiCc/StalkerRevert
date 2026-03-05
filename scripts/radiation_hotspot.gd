extends BaseAnomaly
class_name RadiationHotspot

@export var radiation_radius: float = 6.0
@export var radiation_color: Color = Color(0.3, 1, 0.3, 1)
@export var radiation_damage: float = 14.0
@export var particle_count: int = 200


func _ready():
	super._ready()
	anomaly_name = "Радиоактивный очаг"
	damage_per_second = radiation_damage
	
	_update_size()
	_update_color()
	_setup_particles()


func _setup_particles():
	var particles = $RadiationParticles
	if particles:
		particles.amount = particle_count
		particles.emitting = true


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = radiation_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = radiation_radius
		mesh.mesh.height = radiation_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = radiation_color
		mesh.material_override.emission = radiation_color


func _process(delta):
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker) and stalker.has_method("take_damage"):
			stalker.take_damage(damage_per_second * delta)
			energy_consumed.emit(damage_per_second * delta)
