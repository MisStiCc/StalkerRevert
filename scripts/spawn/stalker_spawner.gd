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
	print("✅ StalkerSpawner: _ready()")
	print("   Сцены сталкеров: ", stalker_scenes)
	
	# Ждём немного и ищем монолит
	await get_tree().create_timer(0.5).timeout
	_monolith = get_tree().get_first_node_in_group("monolith")
	print("   Монолит найден: ", _monolith != null)


func set_difficulty(diff: float):
	_difficulty = diff
	print("📊 Сложность установлена: ", _difficulty)


func spawn_stalker() -> Node:
	print("🔄 spawn_stalker() вызван")
	
	# Проверяем монолит
	if not _monolith:
		print("❌ Монолит не найден!")
		# Пробуем найти ещё раз
		_monolith = get_tree().get_first_node_in_group("monolith")
		if not _monolith:
			print("❌ Монолит всё ещё не найден!")
			return null
	
	var scene = _get_stalker_scene_by_difficulty()
	if not scene:
		print("❌ Нет сцены для сталкера!")
		return null
	
	var pos = _get_spawn_position()
	if pos == Vector3.ZERO:
		print("❌ Не удалось найти позицию для спавна!")
		return null
	
	print("✅ Позиция найдена: ", pos)
	var stalker = scene.instantiate()
	stalker.position = pos
	
	if _monolith:
		var dir = (_monolith.global_position - pos).normalized()
		stalker.look_at(pos + dir, Vector3.UP)
	
	get_tree().current_scene.add_child(stalker)
	
	var stalker_type = "novice"
	if scene == stalker_scenes.get("veteran"):
		stalker_type = "veteran"
	elif scene == stalker_scenes.get("master"):
		stalker_type = "master"
	
	stalker_spawned.emit(stalker, stalker_type)
	print("✅ Сталкер заспавнен! Тип: ", stalker_type)
	return stalker


func _get_stalker_scene_by_difficulty() -> PackedScene:
	var rand_val = randf()
	
	if _difficulty < 1.2:
		if rand_val < 0.6: 
			print("🎲 Выбран novice (легко)")
			return stalker_scenes.get("novice")
		elif rand_val < 0.9: 
			print("🎲 Выбран veteran (легко)")
			return stalker_scenes.get("veteran")
		else: 
			print("🎲 Выбран master (легко)")
			return stalker_scenes.get("master")
	elif _difficulty < 1.5:
		if rand_val < 0.4: 
			print("🎲 Выбран novice (средне)")
			return stalker_scenes.get("novice")
		elif rand_val < 0.8: 
			print("🎲 Выбран veteran (средне)")
			return stalker_scenes.get("veteran")
		else: 
			print("🎲 Выбран master (средне)")
			return stalker_scenes.get("master")
	elif _difficulty < 2.0:
		if rand_val < 0.3: 
			print("🎲 Выбран novice (сложно)")
			return stalker_scenes.get("novice")
		elif rand_val < 0.7: 
			print("🎲 Выбран veteran (сложно)")
			return stalker_scenes.get("veteran")
		else: 
			print("🎲 Выбран master (сложно)")
			return stalker_scenes.get("master")
	else:
		if rand_val < 0.2: 
			print("🎲 Выбран novice (очень сложно)")
			return stalker_scenes.get("novice")
		elif rand_val < 0.6: 
			print("🎲 Выбран veteran (очень сложно)")
			return stalker_scenes.get("veteran")
		else: 
			print("🎲 Выбран master (очень сложно)")
			return stalker_scenes.get("master")


func _get_spawn_position() -> Vector3:
	if not _monolith:
		print("❌ Нет монолита для определения позиции!")
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
	
	print("❌ Raycast не нашёл землю!")
	return Vector3.ZERO