# terrain/terrain_generator.gd
extends Node3D
class_name TerrainGenerator

## Генератор ландшафта (упрощенная версия)

signal chunk_generated(chunk_pos: Vector2i)

@export var chunk_size: int = 32
@export var load_distance: int = 2
@export var terrain_height: float = 10.0
@export var noise_scale: float = 0.02

var noise: FastNoiseLite
var loaded_chunks: Dictionary = {}  # Vector2i -> Node3D
var camera: Camera3D


func _ready():
    noise = FastNoiseLite.new()
    noise.seed = randi()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    noise.frequency = noise_scale
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = 4
    
    add_to_group("terrain_generator")
    
    await get_tree().process_frame
    camera = get_viewport().get_camera_3d()
    
    Logger.info("TerrainGenerator инициализирован", "TerrainGenerator")


func _process(_delta):
    if camera:
        _update_chunks()


func _update_chunks():
    var cam_pos = camera.global_position
    var current_chunk = _world_to_chunk(cam_pos)
    
    # Загружаем новые чанки
    for x in range(current_chunk.x - load_distance, current_chunk.x + load_distance + 1):
        for z in range(current_chunk.y - load_distance, current_chunk.y + load_distance + 1):
            var chunk_pos = Vector2i(x, z)
            if not loaded_chunks.has(chunk_pos):
                _load_chunk(chunk_pos)
    
    # Выгружаем старые
    var to_unload = []
    for chunk_pos in loaded_chunks.keys():
        if abs(chunk_pos.x - current_chunk.x) > load_distance + 1 or \
           abs(chunk_pos.y - current_chunk.y) > load_distance + 1:
            to_unload.append(chunk_pos)
    
    for chunk_pos in to_unload:
        _unload_chunk(chunk_pos)


func _world_to_chunk(world_pos: Vector3) -> Vector2i:
    return Vector2i(
        int(floor(world_pos.x / chunk_size)),
        int(floor(world_pos.z / chunk_size))
    )


func _load_chunk(chunk_pos: Vector2i):
    var chunk = Node3D.new()
    chunk.name = "Chunk_%d_%d" % [chunk_pos.x, chunk_pos.y]
    chunk.position = Vector3(chunk_pos.x * chunk_size, 0, chunk_pos.y * chunk_size)
    
    # Создаем простую плоскость
    var mesh_instance = MeshInstance3D.new()
    var plane = PlaneMesh.new()
    plane.size = Vector2(chunk_size, chunk_size)
    plane.subdivide_width = 4
    plane.subdivide_depth = 4
    mesh_instance.mesh = plane
    
    # Настраиваем материал
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.3, 0.5, 0.2)
    mesh_instance.material_override = material
    
    chunk.add_child(mesh_instance)
    
    # Добавляем коллизию
    var static_body = StaticBody3D.new()
    var collision = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = Vector3(chunk_size, 1, chunk_size)
    collision.shape = shape
    static_body.add_child(collision)
    static_body.position = Vector3(chunk_size / 2.0, -0.5, chunk_size / 2.0)
    chunk.add_child(static_body)
    
    add_child(chunk)
    loaded_chunks[chunk_pos] = chunk
    chunk_generated.emit(chunk_pos)
    
    Logger.debug("Чанк загружен: " + str(chunk_pos), "TerrainGenerator")


func _unload_chunk(chunk_pos: Vector2i):
    if loaded_chunks.has(chunk_pos):
        loaded_chunks[chunk_pos].queue_free()
        loaded_chunks.erase(chunk_pos)
        Logger.debug("Чанк выгружен: " + str(chunk_pos), "TerrainGenerator")


func get_height_at(position: Vector3) -> float:
    var h = noise.get_noise_2d(position.x, position.z) * terrain_height
    h += noise.get_noise_2d(position.x * 2, position.z * 2) * (terrain_height * 0.3)
    return max(0, h)


func get_loaded_chunks_count() -> int:
    return loaded_chunks.size()


func clear_all_chunks():
    for chunk in loaded_chunks.values():
        if is_instance_valid(chunk):
            chunk.queue_free()
    loaded_chunks.clear()
    Logger.info("Все чанки очищены", "TerrainGenerator")