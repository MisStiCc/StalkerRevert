extends Artifact
class_name EnergyArtifact

# Параметры энергетического артефакта
@export var energy_pulse_radius: float = 100.0
@export var energy_damage: float = 15.0
@export var pulse_cooldown: float = 2.0

var pulse_timer: float = 0.0


func _ready():
	super._ready()
	artifact_name = "Energy Artifact"
	artifact_type = "energy"
	artifact_value = 40
	color = Color(0.2, 0.8, 1.0)
	
	pulse_timer = pulse_cooldown


func _process(delta):
	pulse_timer -= delta
	if pulse_timer <= 0:
		_create_energy_pulse()
		pulse_timer = pulse_cooldown


func _create_energy_pulse():
	print("Энергетический артефакт создает импульс!")
	
	var space_state = get_world_3d().direct_space_state
	var params = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = energy_pulse_radius
	params.shape = sphere
	params.transform = Transform3D.IDENTITY.translated(global_position)
	params.collision_mask = 1
	
	var results = space_state.intersect_shape(params)
	
	for result in results:
		var obj = result.collider
		if obj and obj.has_method("take_damage"):
			obj.take_damage(energy_damage)