extends Node
class_name SpawnManager

## Управление спавном сталкеров и мутантов
## Волны, сложность, поведения

signal wave_started(wave_number: int)
signal wave_ended(wave_number: int, stalkers_spawned: int)
signal stalker_spawned(stalker: Node)
signal mutant_spawned(mutant: Node, mutant_type: String)
signal stalker_died(stalker: Node, biomass_returned: float)

@export var spawn_interval: float = 30.0
@export var min_stalkers_per_wave: int = 3
@export var max_stalkers_per_wave: int = 6
@export var spawn_radius: float = 80.0
@export var min_spawn_distance: float = 60.0

# Сцены сталкеров
@export var stalker_scenes: Dictionary = {
	"novice": null,
	"veteran": null,
	"master": null
}

# Сцены мутантов
@export var mutant_scenes: Dictionary = {
	"dog_mutant": null,
	"flesh": null,
	"snork_mutant": null,
	"pseudodog": null,
	"controller_mutant": null,
	"poltergeist": null,
	"bloodsucker": null,
	"chimera": null,
	"pseudogiant": null,
	"zombie": null
}

# Стоимость мутантов
@export var mutant_costs: Dictionary = {
	"dog_mutant": 15.0,
	"flesh": 15.0,
	"snork_mutant": 25.0,
	"pseudodog": 25.0,
	"controller_mutant": 40.0,
	"poltergeist": 40.0,
	"bloodsucker": 50.0,
	"chimera": 75.0,
	"pseudogiant": 75.0,
	"zombie": 10.0
}

# Возврат биомассы за сталкеров
@export var stalker_biomass_returns: Dictionary = {
	"novice": 8.0,
	"veteran": 15.0,
	"master": 30.0,
	"greedy": 8.0,
	"brave": 12.0,
	"cautious": 10.0,
	"aggressive": 15.0,
	"stealthy": 6.0
}

# Скрипты поведения
@export var behavior_scripts: Dictionary = {
	"greedy": preload("res://scripts/stalkers/greedy_stalker.gd"),
	"brave": preload("res://scripts/stalkers/brave_stalker.gd"),
	"cautious": preload("res://scripts/stalkers/cautious_stalker.gd"),
	"aggressive": preload("res://scripts/stalkers/aggressive_stalker.gd"),
	"stealthy": preload("res://scripts/stalkers/stealthy_stalker.gd")
}

var current_wave: int = 0
var is_spawning: bool = false
var is_active: bool = true
var active_stalkers: Array[Node] = []
var active_mutants: Array[Node] = []

var _wave_timer: Timer
var _monolith: Node = null
var _difficulty: float = 1.0


func _ready():
	_monolith = get_tree().get_first_node_in_group("monolith")
	add_to_group("spawn_manager")
	_setup_timer()


func _setup_timer():
	_wave_timer = Timer.new()
	_wave_timer.wait_time = spawn_interval
	_wave_timer.timeout.connect(_start_wave)
	add_child(_wave_timer)


func start_spawning():
	is_active = true
	_wave_timer.start()
	_start_wave()


func stop_spawning():
	is_active = false
	_wave_timer.stop()


func force_wave():
	if is_active and not is_spawning:
		_start_wave()


func set_difficulty(difficulty: float):
	_difficulty = difficulty


# ==================== ВОЛНЫ СТАЛКЕРОВ ====================

func _start_wave():
	if is_spawning or not is_active:
		return
	
	is_spawning = true
	current_wave += 1
	wave_started.emit(current_wave)
	
	var stalkers_to_spawn = _calculate_stalker_count()
	var spawned = 0
	
	for i in range(stalkers_to_spawn):
		if _spawn_stalker():
			spawned += 1
		await get_tree().create_timer(0.3).timeout
	
	is_spawning = false
	wave_ended.emit(current_wave, spawned)


func _calculate_stalker_count() -> int:
	var base = randi_range(min_stalkers_per_wave, max_stalkers_per_wave)
	return ceil(base * _difficulty)


func _spawn_stalker() -> bool:
	var scene = _get_stalker_scene_by_difficulty()
	if not scene:
		return false
	
	var behavior = _get_random_behavior()
	
	for attempt in range(10):
		var pos = _get_spawn_position()
		if pos == Vector3.ZERO:
			continue
		
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
		
		get_tree().current_scene.add_child(stalker)
		
		# Подключаем смерть
		if stalker.has_signal("died"):
			stalker.died.connect(_on_stalker_died)
		
		active_stalkers.append(stalker)
		stalker_spawned.emit(stalker)
		return true
	
	return false


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
	var space = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = pos
	query.to = pos + Vector3(0, -100, 0)
	query.collision_mask = 1
	
	var result = space.intersect_ray(query)
	if result:
		return result.position + Vector3(0, 1.2, 0)
	
	return Vector3.ZERO


func _on_stalker_died(stalker: Node):
	if stalker in active_stalkers:
		active_stalkers.erase(stalker)
	
	# Возвращаем биомассу
	var return_value = 8.0
	if stalker.has_method("get_stalker_type"):
		var stalker_type = stalker.get_stalker_type()
		return_value = stalker_biomass_returns.get(stalker_type, 8.0)
	
	stalker_died.emit(stalker, return_value)


# ==================== МУТАНТЫ ====================

func spawn_mutant(mutant_type: String, position: Vector3, biomass_cost: float) -> Node:
	if not mutant_scenes.has(mutant_type):
		push_error("SpawnManager: неизвестный тип мутанта - ", mutant_type)
		return null
	
	var scene = mutant_scenes[mutant_type]
	if not scene:
		return null
	
	var mutant = scene.instantiate()
	mutant.position = position
	
	get_tree().current_scene.add_child(mutant)
	active_mutants.append(mutant)
	
	mutant_spawned.emit(mutant, mutant_type)
	return mutant


func remove_mutant(mutant: Node):
	if mutant in active_mutants:
		active_mutants.erase(mutant)
	if is_instance_valid(mutant):
		mutant.queue_free()


func get_mutant_cost(mutant_type: String) -> float:
	return mutant_costs.get(mutant_type, 20.0)


func get_active_stalkers() -> Array[Node]:
	return active_stalkers.filter(func(s): return is_instance_valid(s))


func get_active_mutants() -> Array[Node]:
	return active_mutants.filter(func(m): return is_instance_valid(m))


func get_stalker_count() -> int:
	return active_stalkers.size()


func get_mutant_count() -> int:
	return active_mutants.size()


# ==================== СТАТИСТИКА ====================

var _stalkers_killed_count: int = 0
var _artifacts_stolen_count: int = 0
var _mutants_spawned_count: int = 0


func record_stalker_killed():
	_stalkers_killed_count += 1


func record_artifact_stolen():
	_artifacts_stolen_count += 1


func record_mutant_spawned():
	_mutants_spawned_count += 1


func get_stalkers_killed() -> int:
	return _stalkers_killed_count


func get_artifacts_stolen() -> int:
	return _artifacts_stolen_count


func get_total_mutants_spawned() -> int:
	return _mutants_spawned_count


func reset_statistics():
	_stalkers_killed_count = 0
	_artifacts_stolen_count = 0
	_mutants_spawned_count = 0
