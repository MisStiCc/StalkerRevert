# entities/stalkers/stalker_spawner.gd
extends Node
class_name StalkerSpawner

signal stalker_spawned(stalker: Node, stalker_type: String)

@export var stalker_scenes: Dictionary = {
    "novice": null,
    "veteran": null,
    "master": null
}
@export var spawn_radius: float = 80.0
@export var min_spawn_distance: float = 60.0

var _monolith: Node = null
var _difficulty: float = 1.0


func _ready():
    add_to_group("spawner")
    print("StalkerSpawner: _ready()")


func set_difficulty(diff: float):
    _difficulty = diff


func spawn_stalker() -> Node:
    if not _monolith:
        _monolith = get_tree().get_first_node_in_group("monolith")
        if not _monolith:
            print("Монолит не найден!")
            return null
    
    var scene = _get_stalker_scene_by_difficulty()
    if not scene:
        print("Нет сцены для сталкера!")
        return null
    
    var pos = _get_spawn_position()
    if pos == Vector3.ZERO:
        print("Не удалось найти позицию для спавна!")
        return null
    
    var stalker = scene.instantiate()
    stalker.position = pos
    get_tree().current_scene.add_child(stalker)
    
    if _monolith:
        var dir = (_monolith.global_position - pos).normalized()
        stalker.look_at(pos + dir, Vector3.UP)
    
    var stalker_type = "novice"
    if scene == stalker_scenes.get("veteran"):
        stalker_type = "veteran"
    elif scene == stalker_scenes.get("master"):
        stalker_type = "master"
    
    stalker_spawned.emit(stalker, stalker_type)
    return stalker


func _get_stalker_scene_by_difficulty() -> PackedScene:
    var rand_val = randf()
    
    if _difficulty < 1.2:
        if rand_val < 0.6: return stalker_scenes.get("novice")
        elif rand_val < 0.9: return stalker_scenes.get("veteran")
        else: return stalker_scenes.get("master")
    elif _difficulty < 1.5:
        if rand_val < 0.4: return stalker_scenes.get("novice")
        elif rand_val < 0.8: return stalker_scenes.get("veteran")
        else: return stalker_scenes.get("master")
    elif _difficulty < 2.0:
        if rand_val < 0.3: return stalker_scenes.get("novice")
        elif rand_val < 0.7: return stalker_scenes.get("veteran")
        else: return stalker_scenes.get("master")
    else:
        if rand_val < 0.2: return stalker_scenes.get("novice")
        elif rand_val < 0.6: return stalker_scenes.get("veteran")
        else: return stalker_scenes.get("master")


func _get_spawn_position() -> Vector3:
    if not _monolith:
        return Vector3.ZERO
    
    var angle = randf() * TAU
    var distance = min_spawn_distance + randf() * (spawn_radius - min_spawn_distance)
    var pos = _monolith.global_position + Vector3(cos(angle) * distance, 50, sin(angle) * distance)
    
    var space = get_viewport().get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.new()
    query.from = pos
    query.to = pos + Vector3(0, -100, 0)
    query.collision_mask = 1
    
    var result = space.intersect_ray(query)
    if result:
        return result.position + Vector3(0, 1.2, 0)
    
    return Vector3.ZERO