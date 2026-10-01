# terrain/terrain_generator.gd
extends Node3D
class_name TerrainGenerator

signal chunk_generated(chunk_pos: Vector2i)

@export var chunk_size: int = 32
@export var load_distance: int = 2
@export var terrain_height: float = 10.0
@export var noise_scale: float = 0.02
@export var ground_y: float = 0.0  # Высота земли
@export var debug_mode: bool = false

var noise: FastNoiseLite
var loaded_chunks: Dictionary = {}
var camera: Camera3D

# НАВИГАЦИЯ
var navigation_region: NavigationRegion3D
var navigation_source: NavigationMeshSourceGeometryData3D
var has_navigation_geometry: bool = false
# Реестр геометрии чанков: Vector2i -> {faces: PackedVector3Array, transform: Transform3D}
# Единственный источник геометрии для навмеша: NavigationMeshSourceGeometryData3D
# не умеет удалять отдельные меши, поэтому при любом изменении чанков
# source собирается заново из реестра
var _chunk_geometry: Dictionary = {}

# Константы для высоты
const GROUND_HEIGHT: float = 0.0
const NAVMESH_HEIGHT: float = 0.0  # Навмеш на той же высоте что и земля!
# Сталкеры стоят на Y=1.8 (origin тела при капсуле 1.8 со смещением -0.9)
const STALKER_HEIGHT: float = 1.8


func _ready():
	print("TerrainGenerator: _ready() START")
	_setup_noise()
	_setup_navigation()
	
	add_to_group("terrain_generator")
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	camera = get_viewport().get_camera_3d()
	print("TerrainGenerator: камера найдена = ", camera != null)
	
	_update_chunks()
	
	print("TerrainGenerator: _ready() DONE, загружено чанков: ", loaded_chunks.size())


func _setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_scale
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4


func _setup_navigation():
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "GlobalNavigationRegion"
	add_child(navigation_region)
	
	navigation_source = NavigationMeshSourceGeometryData3D.new()
	_bake_navigation_mesh()


func _rebuild_navigation_source():
	"""Собирает source-геометрию навмеша заново из реестра чанков"""
	navigation_source.clear()
	for chunk_pos in _chunk_geometry:
		var entry: Dictionary = _chunk_geometry[chunk_pos]
		navigation_source.add_faces(entry.faces, entry.transform)
	has_navigation_geometry = _chunk_geometry.size() > 0


func _bake_navigation_mesh():
	var nav_mesh = NavigationMesh.new()
	nav_mesh.cell_size = 0.3
	nav_mesh.cell_height = 0.25  # Должен совпадать с cell_height карты (0.25 по умолчанию)
	# Значения выровнены по сетке (кратны cell_size/cell_height), иначе Godot
	# при бейке округляет их и пишет warning о потере точности
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.6
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	
	if has_navigation_geometry:
		NavigationServer3D.bake_from_source_geometry_data(nav_mesh, navigation_source)
	
	navigation_region.navigation_mesh = nav_mesh
	
	var poly_count = nav_mesh.get_polygon_count()
	if poly_count > 0:
		print("TerrainGenerator: навмеш испечён, полигонов: ", poly_count)
	elif has_navigation_geometry:
		print("TerrainGenerator: ОШИБКА - навмеш ПУСТ при наличии геометрии чанков!")


func _process(_delta):
	if camera:
		_update_chunks()


func _update_chunks():
	if not camera:
		return
	
	var cam_pos = camera.global_position
	var current_chunk = _world_to_chunk(cam_pos)
	
	var chunks_to_load = []
	for x in range(current_chunk.x - load_distance, current_chunk.x + load_distance + 1):
		for z in range(current_chunk.y - load_distance, current_chunk.y + load_distance + 1):
			var chunk_pos = Vector2i(x, z)
			if not loaded_chunks.has(chunk_pos):
				chunks_to_load.append(chunk_pos)
	
	var navigation_updated = false
	for chunk_pos in chunks_to_load:
		_load_chunk(chunk_pos)
		navigation_updated = true
	
	var chunks_to_unload = []
	for chunk_pos in loaded_chunks.keys():
		if abs(chunk_pos.x - current_chunk.x) > load_distance + 1 or \
		   abs(chunk_pos.y - current_chunk.y) > load_distance + 1:
			chunks_to_unload.append(chunk_pos)
	
	for chunk_pos in chunks_to_unload:
		_unload_chunk(chunk_pos)
		navigation_updated = true
	
	if navigation_updated:
		_rebuild_navigation_source()
		_bake_navigation_mesh()


func _world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)


func _load_chunk(chunk_pos: Vector2i):
	var chunk = Node3D.new()
	chunk.name = "Chunk_%d_%d" % [chunk_pos.x, chunk_pos.y]
	chunk.position = Vector3(chunk_pos.x * chunk_size, 0, chunk_pos.y * chunk_size)
	
	# Создаём меш ландшафта НА ВЫСОТЕ GROUND_HEIGHT
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	var plane = PlaneMesh.new()
	plane.size = Vector2(chunk_size, chunk_size)
	mesh_instance.mesh = plane
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.5, 0.2)
	mesh_instance.material_override = material
	mesh_instance.position = Vector3(chunk_size / 2.0, GROUND_HEIGHT, chunk_size / 2.0)
	chunk.add_child(mesh_instance)
	
	# Добавляем коллизию НА ТОЙ ЖЕ ВЫСОТЕ
	_add_collision(chunk, chunk_pos)
	
	# Регистрируем геометрию чанка для навигации (навмеш пересобирается из реестра).
	# Квад собираем процедурно через add_faces: add_mesh forced парсит визуальный меш
	# из RenderingServer (GPU->CPU) и пишет warning о производительности
	var half = chunk_size / 2.0
	var a := Vector3(-half, 0.0, -half)
	var b := Vector3(half, 0.0, -half)
	var c := Vector3(half, 0.0, half)
	var d := Vector3(-half, 0.0, half)
	var faces := PackedVector3Array([a, b, c, a, c, d])
	var mesh_transform = Transform3D.IDENTITY
	mesh_transform.origin = mesh_instance.position + chunk.position
	mesh_transform.origin.y = NAVMESH_HEIGHT
	_chunk_geometry[chunk_pos] = {"faces": faces, "transform": mesh_transform}
	
	add_child(chunk)
	loaded_chunks[chunk_pos] = chunk
	chunk_generated.emit(chunk_pos)


func _add_collision(chunk: Node3D, _chunk_pos: Vector2i):
	var static_body = StaticBody3D.new()
	# Коллизия на высоте GROUND_HEIGHT
	static_body.position = Vector3(chunk_size / 2.0, GROUND_HEIGHT - 0.5, chunk_size / 2.0)
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(chunk_size, 1, chunk_size)
	collision.shape = shape
	
	static_body.add_child(collision)
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	
	chunk.add_child(static_body)


func _unload_chunk(chunk_pos: Vector2i):
	if loaded_chunks.has(chunk_pos):
		var chunk = loaded_chunks[chunk_pos]
		chunk.queue_free()
		loaded_chunks.erase(chunk_pos)
	_chunk_geometry.erase(chunk_pos)


func get_height_at(_position: Vector3) -> float:
	return GROUND_HEIGHT


func get_loaded_chunks_count() -> int:
	return loaded_chunks.size()


func clear_all_chunks():
	for chunk in loaded_chunks.values():
		if is_instance_valid(chunk):
			chunk.queue_free()
	loaded_chunks.clear()
	_chunk_geometry.clear()
	
	_rebuild_navigation_source()
	_bake_navigation_mesh()


func force_rebuild_navigation():
	_rebuild_navigation_source()
	_bake_navigation_mesh()
	print("TerrainGenerator: навигация перестроена. Чанков с геометрией: ", _chunk_geometry.size(),
		  ", полигонов навмеша: ", navigation_region.navigation_mesh.get_polygon_count())