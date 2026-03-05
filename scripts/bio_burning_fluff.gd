extends BaseAnomaly
class_name BioBurningFluff

@export var fluff_radius: float = 5.0
@export var fluff_color: Color = Color(1, 0.4, 0.1, 1)
@export var burn_damage: float = 16.0
@export var particle_count: int = 350


func _ready():
	super._ready()
	anomaly_name = "Горящий пух"
	damage_per_second = burn_damage
	
	_update_size()
	_update_color()
	_setup_particles()


func _setup_particles():
	var particles = $FluffParticles
	if particles:
		particles.amount = particle_count
		particles.emitting = true


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = fluff_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = fluff_radius
		mesh.mesh.height = fluff_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = fluff_color
		mesh.material_override.emission = fluff_color


func _process(delta):
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker) and stalker.has_method("take_damage"):
			stalker.take_damage(damage_per_second * delta)
			energy_consumed.emit(damage_per_second * delta)
