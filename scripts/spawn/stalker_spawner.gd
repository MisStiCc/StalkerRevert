extends Node
class_name StalkerSpawner

## Спавн сталкеров
## Только логика создания сталкеров

signal stalker_spawned(stalker: Node, stalker_type: String)

var owner: Node

# Сцены сталкеров
@export var stalker_scenes: Dictionary = {
	"novice": null,
	"veteran": null,
	"master": null
}

# Скрипты поведения
@export var behavior_scripts: Dictionary = {
	"greedy": preload("res://scripts/stalkers/greedy_stalker.gd"),
	"brave": preload("res://scripts/stalkers/brave_stalker.gd"),
	"cautious": preload("res://scripts/stalkers/cautious_stalker.gd"),
	"aggressive": preload("res://scripts/stalkers/aggressive_stalker.gd"),
	"stealthy": preload("res://scripts/stalkers/stealthy_stalker.gd")
}

# Возврат биомассы
@export var biomass_returns: Dictionary = {
	"novice": 8.0,
	"veteran": 15.0,
	"master": 30.0
}

# Параметры
@export var spawn_radius: float = 80.0
@export var min_spawn_distance: float = 60.0

var _monolith: Node = null
var _difficulty: float = 1.0


func _init(node: Node):
	owner = node


func setup(monolith: Node):
	_monolith = monolith


func set_difficulty(difficulty: float):
	_difficulty = difficulty


func spawn_stalker() -> Node:
	"""Создать одного сталкера"""
	var scene = _get_stalker_scene_by_difficulty()
	if not scene:
		return null
	
	var behavior = _get_random_behavior()
	var pos = _get_spawn_position()
	
	if pos == Vector3.ZERO:
		return null
	
	var stalker = scene.instantiate()
	stalker.position = pos
	
	# Применяем поведение
	if behavior_scripts.has(behavior):
		stalker.set_script(behavior_scripts[behavior])
		stalker._ready()
	
	# Поворот к центру
	if _monolith:
		var dir = (_monolith.global_position - pos).normalized()
		stalker.look_at(pos + dir, Vector3.UP)
	
	owner.get_tree().current_scene.add_child(stalker)
	
	var stalker_type = "novice"
	if scene == stalker_scenes.get("veteran"):
		stalker_type = "veteran"
	elif scene == stalker_scenes.get("master"):
		stalker_type = "master"
	
	stalker_spawned.emit(stalker, stalker_type)
	return stalker


func spawn_stalker_of_type(type: String, behavior: String = "") -> Node:
	"""Создать сталкера определённого типа"""
	if not stalker_scenes.has(type):
		return null
	
	var scene = stalker_scenes[type]
	if not scene:
		return null
	
	var pos = _get_spawn_position()
	if pos == Vector3.ZERO:
		return null
	
	var stalker = scene.instantiate()
	stalker.position = pos
	
	# Применяем поведение
	var beh = behavior if behavior else _get_random_behavior()
	if behavior_scripts.has(beh):
		stalker.set_script(behavior_scripts[beh])
		stalker._ready()
	
	if _monolith:
		var dir = (_monolith.global_position - pos).normalized()
		stalker.look_at(pos + dir, Vector3.UP)
	
	owner.get_tree().current_scene.add_child(stalker)
	stalker_spawned.emit(stalker, type)
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


func _get_random_behavior() -> String:
	var behaviors = ["greedy", "brave", "cautious", "aggressive", "stealthy"]
	return behaviors[randi() % behaviors.size()]


func _get_spawn_position() -> Vector3:
	if not _monolith:
		return Vector3.ZERO
	
	var angle = randf() * TAU
	var distance = min_spawn_distance + randf() * (spawn_radius - min_spawn_distance)
	var pos = _monolith.global_position + Vector3(cos(angle) * distance, 50, sin(angle) * distance)
	
	# Raycast для поиска земли
	var space = owner.get_viewport().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = pos
	query.to = pos + Vector3(0, -100, 0)
	query.collision_mask = 1
	
	var result = space.intersect_ray(query)
	if result:
		return result.position + Vector3(0, 1.2, 0)
	
	return Vector3.ZERO


func get_biomass_return(stalker_type: String) -> float:
	return biomass_returns.get(stalker_type, 8.0)


func set_stalker_scenes(scenes: Dictionary):
	stalker_scenes = scenes
