extends Node
class_name EventManager

## Управление событиями: выбросы (radiation pulse)
## Координирует логику выбросов

signal radiation_pulse_started(level: int)
signal radiation_pulse_ended
signal game_over
signal game_won(run_number: int, reward: float)

@export var pulse_duration: float = 5.0
@export var pulses_to_win: int = 5
@export var difficulty_increase_per_pulse: float = 0.2

var is_radiating: bool = false
var pulse_count: int = 0
var current_difficulty: float = 1.0
var run_number: int = 1
var accumulated_biomass: float = 0.0

# Референсы
var _monolith: Node = null
var _anomaly_manager: Node = null
var _spawn_manager: Node = null


func _ready():
	_monolith = get_tree().get_first_node_in_group("monolith")
	_anomaly_manager = get_tree().get_first_node_in_group("anomaly_manager")
	_spawn_manager = get_tree().get_first_node_in_group("spawn_manager")
	add_to_group("event_manager")


func set_difficulty(difficulty: float):
	current_difficulty = difficulty


func set_pulses_to_win(count: int):
	pulses_to_win = count


func set_run_number(run: int):
	run_number = run


func start_radiation_pulse() -> bool:
	if is_radiating:
		return false
	
	is_radiating = true
	pulse_count += 1
	current_difficulty += difficulty_increase_per_pulse
	
	print("⚠️ ВЫБРОС #", pulse_count, " | Сложность: ", current_difficulty)
	radiation_pulse_started.emit(pulse_count)
	
	# Останавливаем таймеры артефактов
	if _anomaly_manager and _anomaly_manager.has_method("stop_all_timers"):
		_anomaly_manager.stop_all_timers()
	
	# Сбрасываем артефакты у сталкеров
	_drop_all_artifacts()
	
	# Перемешиваем аномалии
	_shuffle_all_anomalies()
	
	# Завершаем выброс через duration
	await get_tree().create_timer(pulse_duration).timeout
	
	is_radiating = false
	radiation_pulse_ended.emit()
	print("✅ Выброс закончен")
	
	# Проверка на победу
	if pulse_count >= pulses_to_win:
		_win_game()
	
	return true


func _drop_all_artifacts():
	if not _spawn_manager:
		return
	
	var stalkers = _spawn_manager.get_active_stalkers()
	var dropped = 0
	
	for s in stalkers:
		if is_instance_valid(s) and s.has_method("has_artifact") and s.has_artifact():
			if s.has_method("drop_artifact"):
				s.drop_artifact()
				droped += 1
	
	print("💥 Сброшено артефактов: ", dropped)


func _shuffle_all_anomalies():
	if not _monolith or not _anomaly_manager:
		return
	
	var anomalies = _anomaly_manager.get_active_anomalies()
	if anomalies.is_empty():
		return
	
	# Группируем по уровням сложности
	var by_level = {1: [], 2: [], 3: []}
	
	for a in anomalies:
		if not is_instance_valid(a):
			continue
		var level = 1
		if a.has_method("get_difficulty"):
			level = a.get_difficulty()
		by_level[level].append(a)
	
	# Перемещаем каждую группу в свой радиус
	for level in [1, 2, 3]:
		for a in by_level[level]:
			var new_pos = _get_random_position_for_level(level)
			if new_pos != Vector3.ZERO:
				a.global_position = new_pos
				print("  ➡️ Аномалия ур.", level, " перемещена")


func _get_random_position_for_level(level: int) -> Vector3:
	if not _monolith:
		return Vector3.ZERO
	
	var min_r = 0.0
	var max_r = 0.0
	
	match level:
		1:  # слабые - дальний радиус
			min_r = _monolith.get_middle_radius()
			max_r = _monolith.get_outer_radius()
		2:  # средние
			min_r = _monolith.get_inner_radius()
			max_r = _monolith.get_middle_radius()
		3:  # сильные - ближний
			min_r = 0.0
			max_r = _monolith.get_inner_radius()
		_: return Vector3.ZERO
	
	return _get_random_position(min_r, max_r)


func _get_random_position(min_r: float, max_r: float) -> Vector3:
	if not _monolith:
		return Vector3.ZERO
	
	for attempt in range(30):
		var angle = randf() * TAU
		var distance = min_r + randf() * (max_r - min_r)
		var pos = _monolith.global_position + Vector3(cos(angle) * distance, 50, sin(angle) * distance)
		
		var space = get_viewport().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.new()
		query.from = pos
		query.to = pos + Vector3(0, -100, 0)
		query.collision_mask = 1
		
		var result = space.intersect_ray(query)
		if result:
			pos.y = result.position.y + 0.5
			return pos
	
	return Vector3.ZERO


func check_stalker_touch_monolith(stalker: Node):
	if not _monolith:
		return false
	
	if _monolith.global_position.distance_to(stalker.global_position) < 5.0:
		trigger_game_over()
		return true
	return false


func trigger_game_over():
	print("💀 GAME OVER - Сталкер коснулся Монолита!")
	game_over.emit()
	get_tree().paused = true


func _win_game():
	var reward = _calculate_reward()
	print("🏆 ПОБЕДА! Забег #", run_number, " | Награда: ", reward)
	game_won.emit(run_number, reward)
	get_tree().paused = true


func _calculate_reward() -> float:
	var base_reward = 100.0 * run_number
	return base_reward * current_difficulty


func add_biomass(amount: float):
	accumulated_biomass += amount


func reset():
	is_radiating = false
	pulse_count = 0
	current_difficulty = 1.0
	accumulated_biomass = 0.0


func get_pulse_count() -> int:
	return pulse_count


func get_pulses_remaining() -> int:
	return max(0, pulses_to_win - pulse_count)


func is_pulse_active() -> bool:
	return is_radiating


func get_current_difficulty() -> float:
	return current_difficulty


func has_won() -> bool:
	return pulse_count >= pulses_to_win


func set_game_over(success: bool):
	"""Устанавливает результат игры вручную"""
	if success:
		_win_game()
	else:
		trigger_game_over()
