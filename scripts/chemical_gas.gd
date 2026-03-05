extends BaseAnomaly
class_name ChemicalGas

@export var gas_radius: float = 8.0
@export var gas_color: Color = Color(0.5, 0.8, 0.3, 0.6)
@export var poison_damage: float = 12.0
@export var particle_count: int = 400


func _ready():
	super._ready()
	anomaly_name = "Химический газ"
	damage_per_second = poison_damage
	
	_update_size()
	_update_color()
	_setup_particles()


func _setup_particles():
	var particles = $GasParticles
	if particles:
		particles.amount = particle_count
		particles.emitting = true


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = gas_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = gas_radius
		mesh.mesh.height = gas_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = gas_color
		mesh.material_override.emission = gas_color


func _process(delta):
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker) and stalker.has_method("take_damage"):
			stalker.take_damage(damage_per_second * delta)
			energy_consumed.emit(damage_per_second * delta)
