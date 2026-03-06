extends BaseAnomaly
class_name HeatAnomaly

# Свои собственные параметры
@export var heat_radius: float = 5.0
@export var heat_color: Color = Color(1, 0.5, 0, 1)


func _ready():
	anomaly_type = "heat_anomaly"
	difficulty_level = 1  # Легкая
	anomaly_name = "Жарка"
	damage_per_second = 10.0
	
	super._ready()
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = heat_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = heat_radius
		mesh.mesh.height = heat_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = heat_color
		mesh.material_override.emission = heat_color
