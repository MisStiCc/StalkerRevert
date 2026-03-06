extends BaseAnomaly
class_name ThermalComet

@export var move_speed: float = 3.3
@export var orbit_radius: float = 10.0
@export var comet_radius: float = 1.0
@export var comet_color: Color = Color(1, 0.3, 0, 1)
@export var particle_count: int = 800

var angle: float = 0.0
var spawn_position: Vector3


func _ready():
	anomaly_type = "thermal_comet"
	difficulty_level = 2  # Средняя
	anomaly_name = "Комета"
	damage_per_second = 15.0
	
	spawn_position = global_position
	
	super._ready()
	_update_size()
	_update_color()


func _setup_particles():
	var particles = $TailParticles
	if particles:
		particles.amount = particle_count
		particles.emitting = true


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = comet_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = comet_radius
		mesh.mesh.height = comet_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = comet_color
		mesh.material_override.emission = comet_color


func _physics_process(delta):
	angle += move_speed * delta
	position.x = spawn_position.x + cos(angle) * orbit_radius
	position.z = spawn_position.z + sin(angle) * orbit_radius
	
	_apply_damage_nearby()


func _apply_damage_nearby():
	var space_state = get_world_3d().direct_space_state
	var params = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = comet_radius * 1.5
	params.shape = sphere
	params.transform = Transform3D.IDENTITY.translated(global_position)
	params.collision_mask = 1
	
	for result in space_state.intersect_shape(params):
		var obj = result.collider
		if obj and obj.has_method("take_damage"):
			obj.take_damage(damage_per_second)
			energy_consumed.emit(damage_per_second)
