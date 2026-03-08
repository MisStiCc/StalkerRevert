extends Node
# ChunkManager - управление чанками

## Управление чанками ландшафта
## Загрузка/выгрузка, отрисовка

signal chunk_loaded(chunk_pos: Vector2i)
signal chunk_unloaded(chunk_pos: Vector2i)

var _parent_node: Node

# Параметры
var chunk_size: int = 32
var load_distance: int = 3

# Загруженные чанки
var loaded_chunks: Dictionary = {}  # Vector2i -> Node
var chunk_meshes: Dictionary = {}   # Vector2i -> ArrayMesh

# Кэш
var _chunk_cache: Dictionary = {}

# Ссылки
var height_generator: Node
var biome_manager: Node


func _init(owner_node: Node):
	_parent_node = owner_node


func setup(deps: Dictionary):
	height_generator = deps.get("height_generator")
	biome_manager = deps.get("biome_manager")


func set_chunk_size(size: int):
	chunk_size = size


func set_load_distance(distance: int):
	load_distance = distance


func _process(_delta):
	# Обновляем загрузку чанков вокруг игрока
	var camera = _parent_node.get_viewport().get_camera_3d()
	if not camera:
		return
	
	var player_pos = camera.global_position
	var current_chunk = world_to_chunk(player_pos)
	
	# Загружаем новые чанки
	for x in range(current_chunk.x - load_distance, current_chunk.x + load_distance + 1):
		for z in range(current_chunk.y - load_distance, current_chunk.y + load_distance + 1):
			var chunk_pos = Vector2i(x, z)
			if not loaded_chunks.has(chunk_pos):
				_load_chunk(chunk_pos)
	
	# Выгружаем далекие чанки
	var to_unload = []
	for chunk_pos in loaded_chunks.keys():
		if abs(chunk_pos.x - current_chunk.x) > load_distance + 1 or \
		   abs(chunk_pos.y - current_chunk.y) > load_distance + 1:
			to_unload.append(chunk_pos)
	
	for chunk_pos in to_unload:
		_unload_chunk(chunk_pos)


func world_to_chunk(world_pos: Vector3) -> Vector2i:
	var x = floor(world_pos.x / chunk_size)
	var z = floor(world_pos.z / chunk_size)
	return Vector2i(x, z)


func chunk_to_world(chunk_pos: Vector2i) -> Vector3:
	return Vector3(chunk_pos.x * chunk_size, 0, chunk_pos.y * chunk_size)


func _load_chunk(chunk_pos: Vector2i):
	var chunk_node = Node3D.new()
	chunk_node.name = "Chunk_%d_%d" % [chunk_pos.x, chunk_pos.y]
	chunk_node.position = chunk_to_world(chunk_pos)
	_parent_node.add_child(chunk_node)
	
	# Создаём меш
	_create_chunk_mesh(chunk_node, chunk_pos)
	
	loaded_chunks[chunk_pos] = chunk_node
	chunk_loaded.emit(chunk_pos)


func _unload_chunk(chunk_pos: Vector2i):
	if loaded_chunks.has(chunk_pos):
		var chunk = loaded_chunks[chunk_pos]
		chunk.queue_free()
		loaded_chunks.erase(chunk_pos)
		chunk_unloaded.emit(chunk_pos)


func _create_chunk_mesh(chunk_node: Node, chunk_pos: Vector2i):
	if not height_generator or not biome_manager:
		return
	
	# Создаёмmesh
	var plane = PlaneMesh.new()
	plane.size = Vector2(chunk_size, chunk_size)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = plane
	chunk_node.add_child(mesh_instance)
	
	# Настраиваем материал
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	mesh_instance.material_override = material
	
	# Применяем высоты к вершинам
	_apply_heights_to_mesh(mesh_instance, chunk_pos)


func _apply_heights_to_mesh(mesh_instance: MeshInstance3D, chunk_pos: Vector2i):
	# Это упрощённая версия - в реальности нужно работать с ArrayMesh
	pass


func is_chunk_loaded(chunk_pos: Vector2i) -> bool:
	return loaded_chunks.has(chunk_pos)


func get_chunk_node(chunk_pos: Vector2i) -> Node:
	return loaded_chunks.get(chunk_pos)


func get_loaded_chunks() -> Array:
	return loaded_chunks.keys()


func get_chunk_count() -> int:
	return loaded_chunks.size()
