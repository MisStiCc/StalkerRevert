# components/state_machine_component.gd
extends Node
class_name StateMachineComponent

## Компонент конечного автомата - управляет состояниями сталкера

signal state_changed(old_state: GameEnums.StalkerState, new_state: GameEnums.StalkerState)
signal state_entered(state: GameEnums.StalkerState)
signal state_exited(state: GameEnums.StalkerState)

# Владелец
var stalker: BaseStalker

# Текущее состояние
var current_state: GameEnums.StalkerState = GameEnums.StalkerState.SEEK_MONOLITH:
	set(value):
		if current_state != value:
			var old = current_state
			current_state = value
			print("StateMachine: состояние изменено с ", _get_state_name(old), " на ", _get_state_name(value))
			state_changed.emit(old, value)
			_on_state_entered(value)

# Предыдущее состояние
var previous_state: GameEnums.StalkerState = GameEnums.StalkerState.SEEK_MONOLITH

# Зависимости
var behavior_strategy: StalkerBehaviorStrategy
var navigation: NavigationComponent
var memory: MemoryComponent
var carry: CarryComponent
var health: HealthComponent
var monolith: Node

# Таймеры состояний
var current_state_time: float = 0.0

# Флаги
var can_transition: bool = true
var debug_mode: bool = true  # Включаем debug
var _last_target_position: Vector3 = Vector3.ZERO
var _target_update_timer: float = 0.0
var _log_timer: float = 0.0
# Одноразовый триггер прибытия к монолиту
var _monolith_reached: bool = false


func _ready():
	set_process(true)
	print("StateMachineComponent инициализирован")


func setup(deps: Dictionary):
	behavior_strategy = deps.get("behavior")
	navigation = deps.get("navigation")
	memory = deps.get("memory")
	carry = deps.get("carry")
	health = deps.get("health")
	monolith = deps.get("monolith")
	
	print("StateMachine: зависимости установлены")
	print("  - поведение: ", behavior_strategy)
	print("  - навигация: ", navigation != null)
	print("  - память: ", memory != null)
	print("  - переноска: ", carry != null)
	print("  - здоровье: ", health != null)
	print("  - монолит: ", monolith != null)


func _process(delta):
	if not stalker or not stalker.is_alive():
		return
	
	current_state_time += delta
	_target_update_timer += delta
	_log_timer += delta
	
	# Логируем состояние каждые 3 секунды
	if _log_timer > 3.0:
		_log_timer = 0.0
		print("StateMachine: текущее состояние=", _get_state_name(current_state))
	
	# Обработка текущего состояния
	match current_state:
		GameEnums.StalkerState.IDLE:
			_process_idle(delta)
		GameEnums.StalkerState.PATROL:
			_process_patrol(delta)
		GameEnums.StalkerState.SEEK_ARTIFACT:
			_process_seek_artifact(delta)
		GameEnums.StalkerState.SEEK_MONOLITH:
			_process_seek_monolith(delta)
		GameEnums.StalkerState.FLEE:
			_process_flee(delta)
		GameEnums.StalkerState.ATTACK_ANOMALY:
			_process_attack_anomaly(delta)
		GameEnums.StalkerState.ATTACK_MUTANT:
			_process_attack_mutant(delta)
		GameEnums.StalkerState.CARRY_ARTIFACT:
			_process_carry_artifact(delta)
	
	# Проверка переходов
	_check_transitions()


# ==================== ОБРАБОТЧИКИ СОСТОЯНИЙ ====================

func _process_idle(_delta):
	if current_state_time > 2.0:
		print("StateMachine: IDLE -> PATROL (таймаут)")
		set_state(GameEnums.StalkerState.PATROL)


func _process_patrol(_delta):
	if navigation and not navigation.is_navigating():
		var random_pos = stalker.global_position + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		print("StateMachine: PATROL - двигаюсь к случайной точке ", random_pos)
		navigation.move_to(random_pos)


func _process_seek_artifact(_delta):
	if memory and memory.has_artifacts():
		var target = memory.get_nearest_artifact()
		if target and is_instance_valid(target):
			var dist = stalker.global_position.distance_to(target.global_position)
			if dist < 2.0 and carry and not carry.has_artifact():
				if carry.can_pick_up(target):
					print("StateMachine: SEEK_ARTIFACT - подбираю артефакт")
					carry.pick_up_artifact(target)
			elif navigation and (not navigation.is_navigating() or _target_update_timer > 1.0):
				print("StateMachine: SEEK_ARTIFACT - двигаюсь к артефакту ", target.global_position)
				navigation.move_to(target.global_position)
				_target_update_timer = 0.0
				_last_target_position = target.global_position
	elif navigation and navigation.is_navigating():
		print("StateMachine: SEEK_ARTIFACT - нет артефактов, останавливаюсь")
		navigation.stop()


func _process_seek_monolith(_delta):
	if _monolith_reached:
		return
	if monolith and is_instance_valid(monolith):
		var dist = stalker.global_position.distance_to(monolith.global_position)
		if dist < 5.0:
			_monolith_reached = true
			print("StateMachine: SEEK_MONOLITH - достиг монолита!")
			if navigation:
				navigation.stop()
			var zc = get_tree().get_first_node_in_group("zone_controller")
			if zc:
				zc.finish_run(false)
		elif navigation and (not navigation.is_navigating() or _target_update_timer > 2.0):
			print("StateMachine: SEEK_MONOLITH - двигаюсь к монолиту ", monolith.global_position)
			navigation.move_to(monolith.global_position)
			_target_update_timer = 0.0


func _process_flee(_delta):
	if not navigation or not navigation.is_navigating():
		if memory and memory.has_threats():
			var threat = memory.get_nearest_threat()
			if threat and is_instance_valid(threat):
				var flee_dir = (stalker.global_position - threat.global_position).normalized()
				var flee_pos = stalker.global_position + flee_dir * 30
				print("StateMachine: FLEE - убегаю от ", threat.name, " в ", flee_pos)
				navigation.move_to(flee_pos)


func _process_attack_anomaly(_delta):
	var target = _get_attack_target()
	if target and is_instance_valid(target):
		var dist = stalker.global_position.distance_to(target.global_position)
		if dist < 5.0:
			# Атака с кулдауном сталкера: без проверки attack_timer урон
			# наносился каждый кадр (~480 DPS) и мутанты умирали мгновенно
			if target.has_method("take_damage") and stalker.attack_timer <= 0.0:
				target.take_damage(stalker.damage, stalker)
				stalker.attack_timer = stalker.attack_cooldown
		elif navigation and (not navigation.is_navigating() or _target_update_timer > 1.0):
			print("StateMachine: ATTACK_ANOMALY - двигаюсь к аномалии")
			navigation.move_to(target.global_position)
			_target_update_timer = 0.0


func _process_attack_mutant(_delta):
	var target = _get_attack_target()
	if target and is_instance_valid(target):
		var dist = stalker.global_position.distance_to(target.global_position)
		if dist < 3.0:
			# Атака с кулдауном сталкера (общий attack_timer с _check_attack)
			if target.has_method("take_damage") and stalker.attack_timer <= 0.0:
				target.take_damage(stalker.damage, stalker)
				stalker.attack_timer = stalker.attack_cooldown
		elif navigation and (not navigation.is_navigating() or _target_update_timer > 1.0):
			print("StateMachine: ATTACK_MUTANT - двигаюсь к мутанту")
			navigation.move_to(target.global_position)
			_target_update_timer = 0.0


func _process_carry_artifact(_delta):
	if carry and carry.has_artifact():
		var edge_pos = _get_edge_position()
		if navigation:
			if not navigation.is_navigating() or _target_update_timer > 2.0:
				print("StateMachine: CARRY_ARTIFACT - несу артефакт к краю")
				navigation.move_to(edge_pos)
				_target_update_timer = 0.0
		
		if navigation and navigation.get_distance_to_target() < 5.0:
			print("StateMachine: CARRY_ARTIFACT - артефакт украден")
			carry.steal_artifact()
			set_state(GameEnums.StalkerState.SEEK_MONOLITH)


# ==================== ЛОГИКА ПЕРЕХОДОВ ====================

func _check_transitions():
	if not can_transition:
		return
	
	# 1. Проверка на смерть
	if health and not health.is_alive:
		return
	
	# 2. Если несем артефакт
	if carry and carry.has_artifact():
		if current_state != GameEnums.StalkerState.CARRY_ARTIFACT:
			print("StateMachine: переход в CARRY_ARTIFACT (есть артефакт)")
			set_state(GameEnums.StalkerState.CARRY_ARTIFACT)
		return
	
	# 3. Проверка опасностей
	if memory:
		var nearest_threat = memory.get_nearest_threat()
		if nearest_threat and is_instance_valid(nearest_threat):
			# Реагируем только на угрозы в зоне видимости, а не «по памяти»:
			# иначе сталкер вечно возвращается к забытому противнику
			var threat_dist = stalker.global_position.distance_to(nearest_threat.global_position)
			if threat_dist <= memory.vision_range:
				if behavior_strategy and behavior_strategy.should_flee_from(nearest_threat):
					if current_state != GameEnums.StalkerState.FLEE:
						print("StateMachine: переход в FLEE от ", nearest_threat.name)
						set_state(GameEnums.StalkerState.FLEE)
						if navigation:
							var flee_dir = (stalker.global_position - nearest_threat.global_position).normalized()
							navigation.move_to(stalker.global_position + flee_dir * 30)
					return
				elif behavior_strategy and behavior_strategy.should_attack(nearest_threat):
					var target_state = GameEnums.StalkerState.ATTACK_ANOMALY
					if nearest_threat.is_in_group("mutants"):
						target_state = GameEnums.StalkerState.ATTACK_MUTANT
					
					if current_state != target_state:
						print("StateMachine: переход в атаку на ", nearest_threat.name)
						set_state(target_state)
					return
	
	# 4. Поиск артефактов
	if memory and memory.has_artifacts() and behavior_strategy and behavior_strategy.prefers_artifacts():
		if current_state != GameEnums.StalkerState.SEEK_ARTIFACT:
			print("StateMachine: переход в SEEK_ARTIFACT")
			set_state(GameEnums.StalkerState.SEEK_ARTIFACT)
		return
	
	# 5. По умолчанию цель сталкера - монолит. После победы над угрозой
	# стейт вернётся сюда автоматически (угроза исчезнет из памяти).
	# Без монолита - патрулируем.
	if current_state != GameEnums.StalkerState.SEEK_MONOLITH:
		if monolith and is_instance_valid(monolith):
			print("StateMachine: переход в SEEK_MONOLITH (цель по умолчанию)")
			set_state(GameEnums.StalkerState.SEEK_MONOLITH)
		elif current_state != GameEnums.StalkerState.PATROL:
			set_state(GameEnums.StalkerState.PATROL)


func _on_state_entered(state: GameEnums.StalkerState):
	current_state_time = 0.0
	state_entered.emit(state)
	
	print("StateMachine: вход в состояние ", _get_state_name(state))
	
	match state:
		GameEnums.StalkerState.IDLE:
			if navigation:
				navigation.stop()
		
		GameEnums.StalkerState.PATROL:
			if navigation:
				navigation.set_patrol_points(_generate_patrol_points())
		
		GameEnums.StalkerState.FLEE:
			if navigation and stalker:
				navigation.set_speed(stalker.speed * 1.3)
		
		GameEnums.StalkerState.SEEK_ARTIFACT, GameEnums.StalkerState.SEEK_MONOLITH:
			_target_update_timer = 1.0


func _on_state_exited(state: GameEnums.StalkerState):
	state_exited.emit(state)
	
	print("StateMachine: выход из состояния ", _get_state_name(state))
	
	match state:
		GameEnums.StalkerState.FLEE:
			if navigation and stalker:
				navigation.set_speed(stalker.speed)


# ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

func _get_attack_target() -> Node:
	if current_state == GameEnums.StalkerState.ATTACK_ANOMALY and memory:
		return memory.get_nearest_anomaly()
	elif current_state == GameEnums.StalkerState.ATTACK_MUTANT and memory:
		return memory.get_nearest_mutant()
	return null


func _get_edge_position() -> Vector3:
	if monolith and is_instance_valid(monolith):
		var dir = (stalker.global_position - monolith.global_position).normalized()
		return monolith.global_position + dir * 200
	return stalker.global_position + Vector3(100, 0, 0)


func _generate_patrol_points(count: int = 3) -> Array[Vector3]:
	var points = []
	var center = stalker.global_position
	
	for i in range(count):
		var angle = (TAU / count) * i + randf_range(-0.5, 0.5)
		var distance = 15.0 + randf_range(-5, 5)
		var pos = center + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		
		var space = stalker.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.new()
		query.from = pos + Vector3(0, 20, 0)
		query.to = pos - Vector3(0, 20, 0)
		query.collision_mask = 1
		
		var result = space.intersect_ray(query)
		if result:
			pos.y = result.position.y + 0.5
		
		points.append(pos)
	
	return points


func _get_state_name(state: GameEnums.StalkerState) -> String:
	return GameEnums.StalkerState.keys()[state]


# ==================== ПУБЛИЧНОЕ API ====================

func set_state(new_state: GameEnums.StalkerState):
	if current_state == new_state:
		return
	
	_on_state_exited(current_state)
	previous_state = current_state
	current_state = new_state


func get_state() -> GameEnums.StalkerState:
	return current_state


func get_state_name() -> String:
	return _get_state_name(current_state)


func get_previous_state() -> GameEnums.StalkerState:
	return previous_state


func get_time_in_state() -> float:
	return current_state_time


func is_in_state(state: GameEnums.StalkerState) -> bool:
	return current_state == state


func is_in_combat() -> bool:
	return current_state in [GameEnums.StalkerState.ATTACK_ANOMALY, GameEnums.StalkerState.ATTACK_MUTANT]


func is_fleeing() -> bool:
	return current_state == GameEnums.StalkerState.FLEE


func is_carrying() -> bool:
	return current_state == GameEnums.StalkerState.CARRY_ARTIFACT


func is_moving_to_target() -> bool:
	return current_state in [
		GameEnums.StalkerState.SEEK_ARTIFACT,
		GameEnums.StalkerState.SEEK_MONOLITH,
		GameEnums.StalkerState.CARRY_ARTIFACT
	]


func enable_debug(enable: bool):
	debug_mode = enable


func get_status() -> Dictionary:
	return {
		"current_state": _get_state_name(current_state),
		"previous_state": _get_state_name(previous_state),
		"time_in_state": current_state_time,
		"in_combat": is_in_combat(),
		"fleeing": is_fleeing(),
		"carrying": is_carrying()
	}
