# terrain/terrain_generator.gd
extends Node3D
class_name TerrainGenerator

## Чанковый генератор рельефа Зоны: холмы и лощины по шуму, плоская арена
## вокруг монолита, болотные низины, мёртвые деревья. Навмеш печётся из
## реальных треугольников рельефа.

signal chunk_generated(chunk_pos: Vector2i)

@export var chunk_size: int = 32
@export var load_distance: int = 4
@export var debug_mode: bool = false

# Рельеф: детерминированный (мир одинаков от забега к забегу)
@export var terrain_seed: int = 1979
@export var terrain_amplitude: float = 4.5
@export var monolith_flat_radius: float = 35.0
@export var monolith_blend: float = 35.0
@export var props_per_chunk: int = 3

var noise: FastNoiseLite
var noise_detail: FastNoiseLite
var noise_patch: FastNoiseLite
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

# Материалы и меши декора (создаются лениво, общие для всех чанков)
var _terrain_mat: StandardMaterial3D
var _bark_mat: StandardMaterial3D
var _trunk_mesh: CylinderMesh
var _branch_mesh: CylinderMesh

const NAV_SEGMENTS: int = 12  # сетка вершин на чанк (12x12 = 288 треугольников)
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
	# Крупная рябь рельефа
	noise = FastNoiseLite.new()
	noise.seed = terrain_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.008
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	# Мелкие детали (овражки, бугры)
	noise_detail = FastNoiseLite.new()
	noise_detail.seed = terrain_seed + 101
	noise_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_detail.frequency = 0.045
	noise_detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_detail.fractal_octaves = 2
	# Пятна почвы (сухой грунт / трава)
	noise_patch = FastNoiseLite.new()
	noise_patch.seed = terrain_seed + 707
	noise_patch.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_patch.frequency = 0.02


func get_terrain_height(x: float, z: float) -> float:
	"""Высота рельефа в мировой точке. Вокруг монолита - плоская арена."""
	var h = noise.get_noise_2d(x, z) * terrain_amplitude
	h += noise_detail.get_noise_2d(x, z) * terrain_amplitude * 0.25
	var dist = Vector2(x, z).length()
	var flat = clamp((dist - monolith_flat_radius) / monolith_blend, 0.0, 1.0)
	return h * flat


func _terrain_color(x: float, z: float, h: float) -> Color:
	var patch = (noise_patch.get_noise_2d(x, z) + 1.0) * 0.5
	var col = Color(0.23, 0.27, 0.14).lerp(Color(0.38, 0.33, 0.19), patch)
	if h < -1.2:
		# Болотные низины - мокрая тёмная жижа
		col = col.lerp(Color(0.14, 0.16, 0.11), clamp((-1.2 - h) / 2.0, 0.0, 0.8))
	elif h > 2.5:
		# Сухие вершины - выцветший грунт
		col = col.lerp(Color(0.33, 0.31, 0.26), clamp((h - 2.5) / 2.5, 0.0, 0.6))
	return col


func _terrain_material() -> StandardMaterial3D:
	if _terrain_mat == null:
		_terrain_mat = StandardMaterial3D.new()
		_terrain_mat.albedo_color = Color.WHITE
		_terrain_mat.vertex_color_use_as_albedo = true
		_terrain_mat.roughness = 1.0
	return _terrain_mat


func _build_chunk_mesh(chunk_pos: Vector2i) -> ArrayMesh:
	var origin = Vector3(chunk_pos.x * chunk_size, 0.0, chunk_pos.y * chunk_size)
	var step = float(chunk_size) / NAV_SEGMENTS
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for iz in NAV_SEGMENTS + 1:
		for ix in NAV_SEGMENTS + 1:
			var wx = origin.x + ix * step
			var wz = origin.z + iz * step
			var h = get_terrain_height(wx, wz)
			verts.append(Vector3(wx, h, wz))
			# Нормаль из высотного поля - корректна независимо от winding
			var nx = get_terrain_height(wx - step, wz) - get_terrain_height(wx + step, wz)
			var nz = get_terrain_height(wx, wz - step) - get_terrain_height(wx, wz + step)
			norms.append(Vector3(nx, 2.0 * step, nz).normalized())
			colors.append(_terrain_color(wx, wz, h))

	for iz in NAV_SEGMENTS:
		for ix in NAV_SEGMENTS:
			var a = iz * (NAV_SEGMENTS + 1) + ix
			var b = a + 1
			var c = a + NAV_SEGMENTS + 1
			var d = c + 1
			# Winding проверен на плоских квадратах - навмеш печётся
			indices.append_array([a, b, d, a, d, c])

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


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
		# Чанки вокруг монолита всегда загружены: арена спавна сталкеров,
		# из них не должен исчезать пол при уходе камеры
		if abs(chunk_pos.x) <= load_distance + 1 and abs(chunk_pos.y) <= load_distance + 1:
			continue
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

	var mesh = _build_chunk_mesh(chunk_pos)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _terrain_material()
	chunk.add_child(mesh_instance)

	_add_collision(chunk, mesh)
	_add_props(chunk, chunk_pos)

	add_child(chunk)
	loaded_chunks[chunk_pos] = chunk
	# Рельеф уже в мировых координатах
	_chunk_geometry[chunk_pos] = {"faces": mesh.get_faces(), "transform": Transform3D.IDENTITY}
	chunk_generated.emit(chunk_pos)


func _add_collision(chunk: Node3D, mesh: ArrayMesh):
	var body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0

	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	shape.backface_collision = true

	var col = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	chunk.add_child(body)


func _add_props(chunk: Node3D, chunk_pos: Vector2i):
	"""Мёртвые деревья: детерминированно по чанку, мимо арены монолита"""
	var origin = Vector3(chunk_pos.x * chunk_size, 0.0, chunk_pos.y * chunk_size)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_pos) ^ terrain_seed

	for i in range(props_per_chunk):
		if rng.randf() < 0.45:
			continue
		var px = origin.x + rng.randf() * chunk_size
		var pz = origin.z + rng.randf() * chunk_size
		var dist = Vector2(px, pz).length()
		if dist < monolith_flat_radius + 10.0 or dist > 155.0:
			continue
		var h = get_terrain_height(px, pz)
		if abs(get_terrain_height(px + 1.0, pz) - h) > 1.2:
			continue  # не сажаем на крутых склонах
		var tree = _make_dead_tree(rng)
		tree.position = Vector3(px, h - 0.15, pz)
		chunk.add_child(tree)


func _make_dead_tree(rng: RandomNumberGenerator) -> Node3D:
	if _bark_mat == null:
		_bark_mat = StandardMaterial3D.new()
		_bark_mat.albedo_color = Color(0.16, 0.13, 0.10)
		_bark_mat.roughness = 1.0
		_trunk_mesh = CylinderMesh.new()
		_trunk_mesh.top_radius = 0.06
		_trunk_mesh.bottom_radius = 0.34
		_trunk_mesh.height = 1.0
		_branch_mesh = CylinderMesh.new()
		_branch_mesh.top_radius = 0.02
		_branch_mesh.bottom_radius = 0.09
		_branch_mesh.height = 1.0

	var root = Node3D.new()
	var trunk = MeshInstance3D.new()
	trunk.mesh = _trunk_mesh
	var trunk_h = rng.randf_range(4.5, 7.0)
	trunk.scale = Vector3(1, trunk_h, 1)
	trunk.position.y = trunk_h / 2.0
	trunk.material_override = _bark_mat
	root.add_child(trunk)

	for i in range(rng.randi_range(2, 3)):
		var branch = MeshInstance3D.new()
		branch.mesh = _branch_mesh
		var bl = rng.randf_range(1.4, 2.4)
		branch.scale = Vector3(1, bl, 1)
		branch.position.y = trunk_h * rng.randf_range(0.45, 0.8)
		branch.rotation = Vector3(rng.randf_range(0.7, 1.3), rng.randf() * TAU, 0)
		branch.material_override = _bark_mat
		root.add_child(branch)

	root.rotation.y = rng.randf() * TAU
	root.rotation.z = rng.randf_range(-0.08, 0.08)
	return root


func _unload_chunk(chunk_pos: Vector2i):
	if loaded_chunks.has(chunk_pos):
		var chunk = loaded_chunks[chunk_pos]
		chunk.queue_free()
		loaded_chunks.erase(chunk_pos)
	_chunk_geometry.erase(chunk_pos)


func get_height_at(position: Vector3) -> float:
	return get_terrain_height(position.x, position.z)


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
