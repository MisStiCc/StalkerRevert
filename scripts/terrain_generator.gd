extends Node3D
class_name TerrainGenerator

signal chunk_generated(chunk_pos: Vector2i, mesh: ArrayMesh)

@export var chunk_size: int = 32
@export var chunk_load_distance: int = 3
@export var terrain_height: float = 10.0
@export var terrain_scale: float = 0.02
@export var water_level: float = 2.0

var camera: Camera3D = null
var loaded_chunks: Dictionary = {}
var noise: FastNoiseLite
var terrain_material: StandardMaterial3D
var water_material: StandardMaterial3D
var ground_plane: StaticBody3D  # Простая плоскость для коллизии

func _ready():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = terrain_scale
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 6
	noise.fractal_gain = 0.5
	
	_create_materials()
	
	# СОЗДАЕМ ПРОСТУЮ ПЛОСКОСТЬ ДЛЯ КОЛЛИЗИИ
	_create_ground_plane()
	
	await get_tree().process_frame
	camera = get_viewport().get_camera_3d()
	if camera:
		print("TerrainGenerator: найдена камера, начинаем генерацию")
	else:
		print("TerrainGenerator: камера не найдена, использую центр мира")
	
	print("TerrainGenerator: инициализирован")

func _create_ground_plane():
	"""Создаем простую плоскость для коллизии на высоте 0"""
	ground_plane = StaticBody3D.new()
	ground_plane.name = "GroundPlane"
	ground_plane.collision_layer = 1
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1000, 1, 1000)  # Огромная плоскость
	collision.shape = shape
	collision.position = Vector3(0, -2, 0)  # Чуть ниже уровня земли
	
	ground_plane.add_child(collision)
	add_child(ground_plane)
	print("✅ Создана простая плоскость для коллизии")

func _process(_delta):
	if camera:
		_update_chunks_for_camera()

func _create_materials():
	terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_color = Color(0.3, 0.5, 0.2)
	
	water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.1, 0.3, 0.6, 0.8)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _update_chunks_for_camera():
	if not camera:
		return
	
	var camera_chunk = get_chunk_position(camera.global_position)
	
	for x in range(camera_chunk.x - chunk_load_distance, camera_chunk.x + chunk_load_distance + 1):
		for z in range(camera_chunk.y - chunk_load_distance, camera_chunk.y + chunk_load_distance + 1):
			var chunk_pos = Vector2i(x, z)
			if not loaded_chunks.has(chunk_pos):
				_generate_chunk(chunk_pos)
	
	var chunks_to_remove = []
	for chunk_pos in loaded_chunks.keys():
		if abs(chunk_pos.x - camera_chunk.x) > chunk_load_distance + 1 or \
		   abs(chunk_pos.y - camera_chunk.y) > chunk_load_distance + 1:
			chunks_to_remove.append(chunk_pos)
	
	for chunk_pos in chunks_to_remove:
		_unload_chunk(chunk_pos)

func get_chunk_position(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)

func _generate_chunk(chunk_pos: Vector2i):
	var mesh = _create_chunk_mesh(chunk_pos)
	
	# ТОЛЬКО ВИЗУАЛЬНЫЙ МЕШ, БЕЗ КОЛЛИЗИИ
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = terrain_material
	
	var world_x = chunk_pos.x * chunk_size
	var world_z = chunk_pos.y * chunk_size
	mesh_instance.position = Vector3(world_x, 0, world_z)
	
	add_child(mesh_instance)
	loaded_chunks[chunk_pos] = mesh_instance
	
	_generate_water_chunk(chunk_pos, world_x, world_z)
	
	chunk_generated.emit(chunk_pos, mesh)
	print("Чанк ", chunk_pos, " сгенерирован (без коллизии)")

func _create_chunk_mesh(chunk_pos: Vector2i) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	
	var resolution = chunk_size + 1
	
	for z in range(resolution):
		for x in range(resolution):
			var world_x = chunk_pos.x * chunk_size + x
			var world_z = chunk_pos.y * chunk_size + z
			var height = _get_height(world_x, world_z)
			
			vertices.append(Vector3(x, height, z))
			uvs.append(Vector2(float(x) / chunk_size, float(z) / chunk_size))
	
	for z in range(chunk_size):
		for x in range(chunk_size):
			var top_left = z * resolution + x
			var top_right = top_left + 1
			var bottom_left = (z + 1) * resolution + x
			var bottom_right = bottom_left + 1
			
			indices.append(top_left)
			indices.append(bottom_left)
			indices.append(top_right)
			
			indices.append(top_right)
			indices.append(bottom_left)
			indices.append(bottom_right)
	
	normals = _calculate_normals(vertices, indices)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh

func _get_height(x: float, z: float) -> float:
	var height = noise.get_noise_2d(x, z) * terrain_height
	height += noise.get_noise_2d(x * 2, z * 2) * (terrain_height * 0.3)
	height += noise.get_noise_2d(x * 4, z * 4) * (terrain_height * 0.1)
	height = clamp(height, -terrain_height * 0.5, terrain_height)
	return height

func _calculate_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	
	for i in range(0, indices.size(), 3):
		var i1 = indices[i]
		var i2 = indices[i + 1]
		var i3 = indices[i + 2]
		
		var v1 = vertices[i1]
		var v2 = vertices[i2]
		var v3 = vertices[i3]
		
		var normal = (v2 - v1).cross(v3 - v1).normalized()
		
		normals[i1] = (normals[i1] + normal).normalized()
		normals[i2] = (normals[i2] + normal).normalized()
		normals[i3] = (normals[i3] + normal).normalized()
	
	return normals

func _generate_water_chunk(chunk_pos: Vector2i, world_x: float, world_z: float):
	var has_water = false
	for z in range(0, chunk_size + 1, 4):
		for x in range(0, chunk_size + 1, 4):
			var wx = world_x + x
			var wz = world_z + z
			if _get_height(wx, wz) < water_level:
				has_water = true
				break
		if has_water:
			break
	
	if not has_water:
		return
	
	var water_mesh = PlaneMesh.new()
	water_mesh.size = Vector2(chunk_size, chunk_size)
	water_mesh.subdivide_width = 4
	water_mesh.subdivide_depth = 4
	
	var water_node = MeshInstance3D.new()
	water_node.mesh = water_mesh
	water_node.material_override = water_material
	water_node.position = Vector3(world_x + chunk_size / 2.0, water_level, world_z + chunk_size / 2.0)
	water_node.name = "Water_" + str(chunk_pos.x) + "_" + str(chunk_pos.y)
	
	add_child(water_node)

func _unload_chunk(chunk_pos: Vector2i):
	if loaded_chunks.has(chunk_pos):
		var chunk = loaded_chunks[chunk_pos]
		chunk.queue_free()
		loaded_chunks.erase(chunk_pos)
