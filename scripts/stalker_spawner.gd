extends Node3D
class_name StalkerSpawner

signal wave_started(wave_number)
signal wave_ended(wave_number, stalkers_spawned)
signal stalker_spawned(stalker)

@export var spawn_interval: float = 30.0
@export var min_stalkers_per_wave: int = 3
@export var max_stalkers_per_wave: int = 6
@export var spawn_radius: float = 30.0
@export var min_spawn_distance: float = 5.0

# Разные типы сталкеров для разных уровней сложности
@export var novice_stalker_scene: PackedScene
@export var veteran_stalker_scene: PackedScene
@export var master_stalker_scene: PackedScene  # Для будущего расширения

var current_wave: int = 0
var is_spawning: bool = false
var active_stalkers: Array[BaseStalker] = []

var _wave_timer: Timer
var _zone_controller: Node = null

func _ready():
	_zone_controller = get_tree().get_first_node_in_group("zone_controller")
	
	_wave_timer = Timer.new()
	_wave_timer.wait_time = spawn_interval
	_wave_timer.timeout.connect(_start_wave)
	add_child(_wave_timer)
	_wave_timer.start()
	
	call_deferred("_start_wave")

func _get_current_difficulty() -> float:
	"""Получаем текущую сложность из ZoneController"""
	if _zone_controller and _zone_controller.has_method("get_difficulty"):
		return _zone_controller.get_difficulty()
	return 1.0  # По умолчанию нормальная сложность

func _get_stalker_scene() -> PackedScene:
	"""Выбираем тип сталкера в зависимости от сложности"""
	var difficulty = _get_current_difficulty()
	var rand = randf()
	
	# Чем выше сложность, тем больше шанс спавна сильных сталкеров
	match difficulty:
		0.0:  # Очень легко
			return novice_stalker_scene
		0.5:  # Легко
			return novice_stalker_scene if rand < 0.8 else veteran_stalker_scene
		1.0:  # Нормально
			return novice_stalker_scene if rand < 0.5 else veteran_stalker_scene
		1.5:  # Сложно
			return veteran_stalker_scene if rand < 0.7 else novice_stalker_scene
		2.0:  # Очень сложно
			return veteran_stalker_scene
		_:
			# Для будущих уровней сложности
			if difficulty >= 3.0 and master_stalker_scene:
				if rand < 0.3:
					return master_stalker_scene
			return veteran_stalker_scene if rand < 0.5 else novice_stalker_scene

func _start_wave():
	if is_spawning: return
	is_spawning = true
	current_wave += 1
	wave_started.emit(current_wave)
	
	# Количество сталкеров тоже зависит от сложности
	var difficulty = _get_current_difficulty()
	var base_count = randi_range(min_stalkers_per_wave, max_stalkers_per_wave)
	var actual_count = ceil(base_count * difficulty)  # Больше сталкеров на высокой сложности
	
	var spawned = 0
	
	for i in range(actual_count):
		if _spawn_stalker():
			spawned += 1
		await get_tree().create_timer(0.3).timeout
	
	is_spawning = false
	wave_ended.emit(current_wave, spawned)

func _spawn_stalker() -> bool:
	var scene = _get_stalker_scene()
	if not scene:
		return false
	
	for attempt in range(10):
		var pos = _get_spawn_position()
		if pos == Vector3.ZERO:
			continue
		
		var stalker = scene.instantiate() as BaseStalker
		if not stalker:
			continue
		
		stalker.position = pos
		get_tree().current_scene.add_child(stalker)
		
		# Поворот к центру
		var dir = -pos.normalized()
		if dir.length_squared() > 0:
			stalker.look_at(pos + dir, Vector3.UP)
		
		if stalker.has_signal("died"):
			stalker.died.connect(_on_stalker_died)
		
		active_stalkers.append(stalker)
		stalker_spawned.emit(stalker)
		return true
	
	return false

func _get_spawn_position() -> Vector3:
	var angle = randf() * TAU
	var dist = min_spawn_distance + randf() * (spawn_radius - min_spawn_distance)
	var start = Vector3(cos(angle) * dist, 100, sin(angle) * dist)
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = start
	query.to = start + Vector3(0, -500, 0)
	query.collision_mask = 1
	
	var result = space.intersect_ray(query)
	if result:
		return result.position + Vector3(0, 1.2, 0)
	
	return Vector3.ZERO

func _on_stalker_died(stalker: BaseStalker):
	if stalker in active_stalkers:
		active_stalkers.erase(stalker)
	
	if _zone_controller and _zone_controller.has_method("add_biomass"):
		_zone_controller.add_biomass(stalker._get_biomass_value())

# Методы для управления
func set_spawn_interval(new_interval: float):
	spawn_interval = new_interval
	if _wave_timer:
		_wave_timer.wait_time = spawn_interval

func force_wave():
	if not is_spawning:
		_start_wave()
