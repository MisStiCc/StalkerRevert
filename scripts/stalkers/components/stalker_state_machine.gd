extends Node
class_name StalkerStateMachine

## Управление состояниями сталкера
## State Machine паттерн

signal state_changed(old_state: int, new_state: int)

enum StalkerState {
	IDLE, PATROL, SEEK_ARTIFACT, SEEK_MONOLITH, FLEE,
	ATTACK_ANOMALY, ATTACK_MUTANT, CARRY_ARTIFACT
}

var owner_stalker: CharacterBody3D
var current_state: StalkerState = StalkerState.PATROL
var previous_state: StalkerState = StalkerState.PATROL

# Ссылки на другие компоненты
var behavior: Node
var navigation: Node
var memory: Node
var health: Node
var carry: Node


func _init(stalker: CharacterBody3D):
	owner_stalker = stalker


func setup(deps: Dictionary):
	behavior = deps.get("behavior")
	navigation = deps.get("navigation")
	memory = deps.get("memory")
	health = deps.get("health")
	carry = deps.get("carry")


func _physics_process(delta: float):
	if not _can_update():
		return
	
	# Обрабатываем текущее состояние
	match current_state:
		StalkerState.IDLE:
			_process_idle(delta)
		StalkerState.PATROL:
			_process_patrol(delta)
		StalkerState.SEEK_ARTIFACT, StalkerState.SEEK_MONOLITH, StalkerState.CARRY_ARTIFACT:
			_process_seek(delta)
		StalkerState.ATTACK_ANOMALY, StalkerState.ATTACK_MUTANT:
			_process_attack(delta)
		StalkerState.FLEE:
			_process_flee(delta)


func _can_update() -> bool:
	if not owner_stalker:
		return false
	
	# Проверяем жив ли сталкер
	if health and health.has_method("is_alive"):
		if not health.is_alive():
			return false
	
	# Проверяем радиацию
	var zone_controller = owner_stalker.get_tree().get_first_node_in_group("zone_controller")
	if zone_controller and zone_controller.is_radiating:
		return false
	
	return true


func set_state(new_state: StalkerState):
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state
	state_changed.emit(previous_state, current_state)
	
	# Выход из старого состояния
	_on_exit_state(previous_state)
	# Вход в новое состояние
	_on_enter_state(new_state)


func _on_enter_state(state: StalkerState):
	match state:
		StalkerState.IDLE:
			# Остановка на небольшое время
			if navigation:
				navigation.stop()
		StalkerState.PATROL:
			if navigation:
				navigation.set_patrol_mode(true)


func _on_exit_state(state: StalkerState):
	match state:
		StalkerState.PATROL:
			if navigation:
				navigation.set_patrol_mode(false)


# ==================== ОБРАБОТЧИКИ СОСТОЯНИЙ ====================

func _process_idle(_delta: float):
	# Через некоторое время переходим к патрулированию
	if navigation and not navigation.is_moving():
		set_state(StalkerState.PATROL)


func _process_patrol(_delta: float):
	# Оцениваем ситуацию и переключаемся если нужно
	_evaluate_state_transitions()


func _process_seek(_delta: float):
	# Движение к цели
	if navigation:
		navigation.continue_path()


func _process_attack(_delta: float):
	# Атака цели
	var target = _get_attack_target()
	if target and owner_stalker.global_position.distance_to(target.global_position) < 3.0:
		if target.has_method("take_damage"):
			var damage = 8.0
			if health:
				damage = health.get_damage()
			target.take_damage(damage, owner_stalker)


func _process_flee(_delta: float):
	# Бегство
	if navigation:
		navigation.continue_path()


func _evaluate_state_transitions():
	"""Оценивает переходы между состояниями"""
	# 1. Если несём артефакт
	if carry and carry.has_method("has_artifact"):
		if carry.has_artifact():
			set_state(StalkerState.CARRY_ARTIFACT)
			return
	
	# 2. Проверка опасностей
	if memory:
		var nearest_danger = memory.get_nearest_threat()
		if nearest_danger:
			if behavior and behavior.should_flee_from(nearest_danger):
				if navigation:
					navigation.set_flee_target(nearest_danger.global_position)
				set_state(StalkerState.FLEE)
				return
			elif behavior and behavior.should_attack(nearest_danger):
				if navigation:
					navigation.set_target(nearest_danger.global_position)
				set_state(StalkerState.ATTACK_ANOMALY)
				return
	
	# 3. Поиск артефактов
	if memory:
		var nearest_artifact = memory.get_nearest_artifact()
		if nearest_artifact and behavior and behavior.prefers_artifacts():
			if navigation:
				navigation.set_target(nearest_artifact.global_position)
			set_state(StalkerState.SEEK_ARTIFACT)
			return
	
	# 4. Идём к монолиту (умолчание)
	var monolith = owner_stalker.get_tree().get_first_node_in_group("monolith")
	if monolith:
		if navigation:
			navigation.set_target(monolith.global_position)
		set_state(StalkerState.SEEK_MONOLITH)


func _get_attack_target() -> Node:
	if current_state == StalkerState.ATTACK_ANOMALY and memory:
		return memory.get_nearest_threat()
	elif current_state == StalkerState.ATTACK_MUTANT and memory:
		return memory.get_nearest_mutant()
	return null


# ==================== ПУБЛИЧНОЕ API ====================

func get_state() -> int:
	return current_state


func get_state_name() -> String:
	return StalkerState.find_key(current_state)


func is_in_combat() -> bool:
	return current_state in [StalkerState.ATTACK_ANOMALY, StalkerState.ATTACK_MUTANT]


func is_fleeing() -> bool:
	return current_state == StalkerState.FLEE


func is_carrying() -> bool:
	return current_state == StalkerState.CARRY_ARTIFACT
