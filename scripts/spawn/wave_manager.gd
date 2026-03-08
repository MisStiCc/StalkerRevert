extends Node
# WaveManager - управление волнами

## Управление волнами сталкеров
## Таймеры, количество, сложность

signal wave_started(wave_number: int)
signal wave_ended(wave_number: int, spawned_count: int)

var _parent_node: Node

# Параметры волн
@export var spawn_interval: float = 30.0
@export var min_stalkers_per_wave: int = 3
@export var max_stalkers_per_wave: int = 6

# Состояние
var current_wave: int = 0
var is_spawning: bool = false
var is_active: bool = true

# Таймер
var _wave_timer: Timer = null
var _stalker_spawner: Node = null
var _difficulty: float = 1.0


func _init(node: Node):
	_parent_node = node


func _ready():
	_wave_timer = Timer.new()
	_wave_timer.wait_time = spawn_interval
	_wave_timer.timeout.connect(_start_wave)
	_parent_node.add_child(_wave_timer)


func setup(spawner: Node):
	_stalker_spawner = spawner


func start():
	is_active = true
	_wave_timer.start()
	_start_wave()


func stop():
	is_active = false
	_wave_timer.stop()


func force_wave():
	"""Принудительно запустить волну"""
	if is_active and not is_spawning:
		_start_wave()


func set_difficulty(difficulty: float):
	_difficulty = difficulty


func set_interval(interval: float):
	spawn_interval = interval
	if _wave_timer:
		_wave_timer.wait_time = interval


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
		await _parent_node.get_tree().create_timer(0.3).timeout
	
	is_spawning = false
	wave_ended.emit(current_wave, spawned)
	print("🌊 Волна ", current_wave, " завершена. Создано сталкеров: ", spawned)


func _spawn_stalker() -> bool:
	if not _stalker_spawner:
		return false
	
	var stalker = _stalker_spawner.spawn_stalker()
	return stalker != null


func _calculate_stalker_count() -> int:
	var base = randi_range(min_stalkers_per_wave, max_stalkers_per_wave)
	return int(ceil(base * _difficulty))


# ==================== ПУБЛИЧНОЕ API ====================

func get_current_wave() -> int:
	return current_wave


func is_wave_active() -> bool:
	return is_spawning


func is_active_state() -> bool:
	return is_active


func get_time_to_next_wave() -> float:
	if _wave_timer:
		return _wave_timer.time_left
	return 0.0


func reset():
	current_wave = 0
	is_spawning = false
	is_active = false
	if _wave_timer:
		_wave_timer.stop()
