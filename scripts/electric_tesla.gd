extends BaseAnomaly
class_name ElectricTesla

@export var tesla_radius: float = 6.0
@export var tesla_color: Color = Color(0.3, 0.8, 1, 1)
@export var arc_damage: float = 20.0
@export var stun_chance: float = 0.4
@export var stun_duration: float = 2.0
@export var particle_count: int = 250


func _ready():
	super._ready()
	anomaly_name = "Тесла-разряд"
	damage_per_second = arc_damage
	
	_update_size()
	_update_color()
	_setup_particles()


func _setup_particles():
	var particles = $TeslaParticles
	if particles:
		particles.amount = particle_count
		particles.emitting = true


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = tesla_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = tesla_radius
		mesh.mesh.height = tesla_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = tesla_color
		mesh.material_override.emission = tesla_color


func _apply_damage():
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(damage_per_second)
				
				# Шанс сильного оглушения
				if randf() < stun_chance and stalker.has_method("stun"):
					stalker.stun(stun_duration)
				
				energy_consumed.emit(damage_per_second)
