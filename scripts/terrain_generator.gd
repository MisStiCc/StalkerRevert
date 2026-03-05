extends Node3D
class_name TerrainGenerator

## Процедурный генератор 3D-ландшафта
## Поддерживает бесконечный мир через систему чанков

signal chunk_generated(chunk_pos: Vector2i, mesh: ArrayMesh)
signal terrain_ready

# Настройки генерации
@export var chunk_size: int = 32  # Размер чанка
@export var chunk_load_distance: int = 3  # Сколько чанков загружать вокруг игрока
@export var terrain_height: float = 10.0  # Максимальная высота
@export var terrain_scale: float = 0.02  # Масштаб шума (меньше = более плавно)
@export var water_level: float = 2.0  # Уровень воды

# Ссылка на игрока для загрузки чанков
var player: Node3D = null

# Загруженные чанки
var loaded_chunks: Dictionary = {}
var noise: FastNoiseLite

# Материалы ландшафта
var terrain_material: StandardMaterial3D
var water_material: StandardMaterial3D

func _ready():
	# Инициализация шума
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = terrain_scale
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 6
	noise.fractal_gain = 0.5
	
	# Создание материалов
	_create_materials()
	
	# Поиск игрока
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().get_first_node_in_group("stalkers")
	
	print("TerrainGenerator: инициализирован")

func _process(_delta):
	if player:
		_update_chunks()

func _create_materials():
	# Материал земли
	terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_color = Color(0.3, 0.5, 0.2)  # Зелёный
	terrain_material.roughness = 0.9
	terrain_material.metallic = 0.0
	
	# Материал воды
	water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.1, 0.3, 0.6, 0.8)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.1
	water_material.metallic = 0.3
	water_material.emission = Color(0.05, 0.15, 0.3)
	water_material.emission_energy = 0.5

func _update_chunks():
	"""Обновление загруженных чанков вокруг игрока"""
	var player_chunk = get_chunk_position(player.global_position)
	
	# Загружаем чанки вокруг
	for x in range(player_chunk.x - chunk_load_distance, player_chunk.x + chunk_load_distance + 1):
		for z in range(player_chunk.y - chunk_load_distance, player_chunk.y + chunk_load_distance + 1):
			var chunk_pos = Vector2i(x, z)
			if not loaded_chunks.has(chunk_pos):
				_generate_chunk(chunk_pos)
	
	# Выгружаем дальние чанки
	var chunks_to_remove = []
	for chunk_pos in loaded_chunks.keys():
		if abs(chunk_pos.x - player_chunk.x) > chunk_load_distance + 1 or \
		   abs(chunk_pos.y - player_chunk.y) > chunk_load_distance + 1:
			chunks_to_remove.append(chunk_pos)
	
	for chunk_pos in chunks_to_remove:
		_unload_chunk(chunk_pos)

func get_chunk_position(world_pos: Vector3) -> Vector2i:
	"""Получение позиции чанка по мировой позиции"""
	return Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)

func _generate_chunk(chunk_pos: Vector2i):
	"""Генерация одного чанка"""
	var mesh = _create_chunk_mesh(chunk_pos)
	var chunk_node = MeshInstance3D.new()
	chunk_node.mesh = mesh
	chunk_node.material_override = terrain_material
	chunk_node.name = "Chunk_" + str(chunk_pos.x) + "_" + str(chunk_pos.y)
	
	# Позиция чанка
	var world_x = chunk_pos.x * chunk_size
	var world_z = chunk_pos.y * chunk_size
	chunk_node.position = Vector3(world_x, 0, world_z)
	
	add_child(chunk_node)
	loaded_chunks[chunk_pos] = chunk_node
	
	# Генерация воды для чанка
	_generate_water_chunk(chunk_pos, world_x, world_z)
	
	# Генерация объектов (деревья, камни и т.д.)
	_generate_vegetation(chunk_pos, world_x, world_z)
	
	chunk_generated.emit(chunk_pos, mesh)

func _create_chunk_mesh(chunk_pos: Vector2i) -> ArrayMesh:
	"""Создание меша чанка"""
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	
	var resolution = chunk_size + 1  # Количество вершин по одной стороне
	
	# Генерация вершин
	for z in range(resolution):
		for x in range(resolution):
			var world_x = chunk_pos.x * chunk_size + x
			var world_z = chunk_pos.y * chunk_size + z
			
			# Получение высоты через шум
			var height = _get_height(world_x, world_z)
			
			vertices.append(Vector3(x, height, z))
			normals.append(Vector3.UP)  # Пока заглушка
			uvs.append(Vector2(float(x) / chunk_size, float(z) / chunk_size))
	
	# Генерация индексов (две треугольника на квадрат)
	for z in range(chunk_size):
		for x in range(chunk_size):
			var top_left = z * resolution + x
			var top_right = top_left + 1
			var bottom_left = (z + 1) * resolution + x
			var bottom_right = bottom_left + 1
			
			# Первый треугольник
			indices.append(top_left)
			indices.append(bottom_left)
			indices.append(top_right)
			
			# Второй треугольник
			indices.append(top_right)
			indices.append(bottom_left)
			indices.append(bottom_right)
	
	# Вычисление нормалей
	normals = _calculate_normals(vertices, indices)
	
	# Создание массива
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh

func _get_height(x: float, z: float) -> float:
	"""Получение высоты ландшафта через шум"""
	var height = noise.get_noise_2d(x, z) * terrain_height
	
	# Добавляем несколько слоёв шума для деталей
	height += noise.get_noise_2d(x * 2, z * 2) * (terrain_height * 0.3)
	height += noise.get_noise_2d(x * 4, z * 4) * (terrain_height * 0.1)
	
	# Сглаживание
	height = clamp(height, -terrain_height * 0.5, terrain_height)
	
	return height

func _calculate_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	"""Вычисление нормалей для меша"""
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	
	# Простое вычисление нормалей (можно улучшить)
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
	"""Генерация воды для чанка"""
	# Проверяем, есть ли вода в этом чанке
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
	
	# Создаём воду
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

func _generate_vegetation(chunk_pos: Vector2i, world_x: float, world_z: float):
	"""Генерация растительности (деревья, камни)"""
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_pos)
	
	var vegetation_count = rng.randf_range(3, 8)
	
	for i in range(vegetation_count):
		var local_x = rng.randf_range(2, chunk_size - 2)
		var local_z = rng.randf_range(2, chunk_size - 2)
		
		var wx = world_x + local_x
		var wz = world_z + local_z
		var height = _get_height(wx, wz)
		
		# Не размещаем на воде или слишком высоко
		if height < water_level + 1 or height > terrain_height * 0.8:
			continue
		
		# Случайный выбор объекта
		if rng.randf() < 0.6:
			_create_tree(wx, height, wz)
		else:
			_create_rock(wx, height, wz)

func _create_tree(x: float, y: float, z: float):
	"""Создание дерева"""
	var tree = Node3D.new()
	tree.name = "Tree"
	tree.position = Vector3(x, y, z)
	
	# Ствол
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.2
	trunk_mesh.bottom_radius = 0.3
	trunk_mesh.height = 2.0
	trunk.mesh = trunk_mesh
	
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.3, 0.2)
	trunk.material_override = trunk_mat
	trunk.position.y = 1.0
	tree.add_child(trunk)
	
	# Крона
	var crown = MeshInstance3D.new()
	var crown_mesh = SphereMesh.new()
	crown_mesh.radius = 1.5
	crown_mesh.height = 3.0
	crown.mesh = crown_mesh
	
	var crown_mat = StandardMaterial3D.new()
	crown_mat.albedo_color = Color(0.1, 0.4, 0.1)
	crown.material_override = crown_mat
	crown.position.y = 3.0
	tree.add_child(crown)
	
	add_child(tree)

func _create_rock(x: float, y: float, z: float):
	"""Создание камня"""
	var rock = MeshInstance3D.new()
	var rock_mesh = SphereMesh.new()
	rock_mesh.radius = 0.5
	rock_mesh.height = 1.0
	
	var rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.5, 0.5, 0.5)
	rock.material_override = rock_mat
	
	rock.mesh = rock_mesh
	rock.position = Vector3(x, y + 0.3, z)
	rock.scale = Vector3(1.0, 0.6, 1.0)
	
	add_child(rock)

func _unload_chunk(chunk_pos: Vector2i):
	"""Выгрузка чанка"""
	if loaded_chunks.has(chunk_pos):
		var chunk = loaded_chunks[chunk_pos]
		chunk.queue_free()
		loaded_chunks.erase(chunk_pos)

func get_height_at(position: Vector3) -> float:
	"""Получение высоты ландшафта в указанной позиции"""
	return _get_height(position.x, position.z)

func regenerate_seed():
	"""Перегенерация с новым сидом"""
	noise.seed = randi()
	
	# Перегенерация всех чанков
	for chunk_pos in loaded_chunks.keys():
		_unload_chunk(chunk_pos)
		_generate_chunk(chunk_pos)
	
	print("TerrainGenerator: перегенерация завершена")

func set_seed(new_seed: int):
	"""Установка конкретного сида"""
	noise.seed = new_seed
	
	# Перегенерация
	for chunk_pos in loaded_chunks.keys():
		_unload_chunk(chunk_pos)
		_generate_chunk(chunk_pos)
