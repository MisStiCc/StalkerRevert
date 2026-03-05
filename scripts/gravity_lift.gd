extends BaseAnomaly
class_name GravityLift

@export var lift_radius: float = 4.0
@export var lift_color: Color = Color(0.5, 0, 1, 1)
@export var lift_force: float = 8.0
@export var lift_height: float = 20.0


func _ready():
	super._ready()
	anomaly_name = "Гравитационный лифт"
	damage_per_second = 8.0
	
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = lift_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = lift_radius
		mesh.mesh.height = lift_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = lift_color
		mesh.material_override.emission = lift_color


func _physics_process(delta):
	# Поднимаем сталкеров вверх
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			stalker.global_position.y += lift_force * delta
			# Ограничиваем высоту
			if stalker.global_position.y > lift_height:
				stalker.global_position.y = lift_height
