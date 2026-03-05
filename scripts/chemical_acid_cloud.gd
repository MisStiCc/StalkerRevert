extends BaseAnomaly
class_name ChemicalAcidCloud

@export var cloud_radius: float = 7.0
@export var cloud_color: Color = Color(0.6, 1, 0, 0.7)
@export var particle_count: int = 300


func _ready():
	super._ready()
	anomaly_name = "Кислотное облако"
	damage_per_second = 18.0
	
	_update_size()
	_update_color()
	_setup_particles()


func _setup_particles():
	var particles = $AcidParticles
	if particles:
		particles.amount = particle_count
		particles.emitting = true


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = cloud_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = cloud_radius
		mesh.mesh.height = cloud_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = cloud_color
		mesh.material_override.emission = cloud_color


func _process(delta):
	# Постоянный урон как в ThermalSteam
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker) and stalker.has_method("take_damage"):
			stalker.take_damage(damage_per_second * delta)
			energy_consumed.emit(damage_per_second * delta)
