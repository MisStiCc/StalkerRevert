# entities/stalkers/base_stalker.gd
extends Entity
class_name BaseStalker

## Базовый класс для всех сталкеров

# Сигналы
signal artifact_picked_up(artifact: Node, value: int)
signal artifact_dropped(artifact: Node)
signal artifact_stolen(artifact: Node, value: int)
signal target_acquired(target: Node, type: String)
signal target_lost(target: Node)

# Параметры сталкера
@export var stalker_type: GameEnums.StalkerType = GameEnums.StalkerType.NOVICE:
	set(value):
		stalker_type = value
		_apply_type_parameters()

@export var behavior_type: GameEnums.StalkerBehavior = GameEnums.StalkerBehavior.GREEDY:
	set(value):
		behavior_type = value
		if behavior_strategy:
			behavior_strategy = StalkerBehaviorStrategy.create(behavior_type, self)

@export var damage: float = 10.0
@export var vision_range: float = 20.0
@export var detection_range: float = 30.0
@export var attack_range: float = 3.0
@export var attack_cooldown: float = 1.0
@export var critical_chance: float = 0.1
@export var biomass_return: float = 10.0

# Компоненты
var memory_component: MemoryComponent
var carry_component: CarryComponent
var state_machine: StateMachineComponent
var behavior_strategy: StalkerBehaviorStrategy

# Ссылки на важные объекты
var monolith: Node

# Таймеры
var attack_timer: Timer
var detection_timer: Timer

# Текущая цель
var current_target: Node = null
var last_attack_time: float = 0.0


func _ready():
	# Устанавливаем имя
	entity_name = "Stalker_" + GameEnums.StalkerType.keys()[stalker_type].capitalize()
	
	# Применяем параметры типа
	_apply_type_parameters()
	
	# СНАЧАЛА создаем стратегию поведения
	behavior_strategy = StalkerBehaviorStrategy.create(behavior_type, self)
	
	# ПОТОМ инициализируем компоненты
	_initialize_stalker_components()
	
	# Поиск важных объектов
	zone_controller = get_tree().get_first_node_in_group("zone_controller")
	monolith = get_tree().get_first_node_in_group("monolith")
	
	# Подключаемся к ZoneController
	if zone_controller and zone_controller.has_method("register_stalker"):
		zone_controller.register_stalker(self)
	
	# Настройка таймеров
	_setup_timers()
	
	# Хук для наследников
	_ready_hook()
	
	# Добавляем в группы
	add_to_group("stalkers")
	add_to_group("stalkers_" + GameEnums.StalkerType.keys()[stalker_type].to_lower())
	
	# Настраиваем подпись
	_setup_label()
	
	super._ready()
	
	print("BaseStalker инициализирован: тип=" + str(stalker_type) + " поведение=" + str(behavior_type))


func _setup_label():
	if label:
		match stalker_type:
			GameEnums.StalkerType.NOVICE:
				label.text = "🟢 НОВИЧОК"
				label.modulate = Color(0.2, 0.8, 0.2)
			GameEnums.StalkerType.VETERAN:
				label.text = "🔵 ВЕТЕРАН"
				label.modulate = Color(0.2, 0.4, 1.0)
			GameEnums.StalkerType.MASTER:
				label.text = "🟣 МАСТЕР"
				label.modulate = Color(0.8, 0.2, 0.8)


func _apply_type_parameters():
	match stalker_type:
		GameEnums.StalkerType.NOVICE:
			max_health = 80.0
			move_speed = 4.0
			damage = 8.0
			vision_range = 20.0
			detection_range = 25.0
			biomass_return = 8.0
		
		GameEnums.StalkerType.VETERAN:
			max_health = 150.0
			move_speed = 5.5
			damage = 15.0
			vision_range = 25.0
			detection_range = 30.0
			biomass_return = 15.0
		
		GameEnums.StalkerType.MASTER:
			max_health = 250.0
			move_speed = 6.0
			damage = 25.0
			vision_range = 30.0
			detection_range = 35.0
			biomass_return = 30.0
	
	print("Параметры типа применены: " + str(stalker_type))


func _initialize_stalker_components():
	# MemoryComponent
	memory_component = MemoryComponent.new()
	memory_component.stalker = self
	memory_component.vision_range = vision_range
	add_child(memory_component)
	memory_component.threat_detected.connect(_on_threat_detected)
	memory_component.threat_lost.connect(_on_threat_lost)
	memory_component.artifact_detected.connect(_on_artifact_detected)
	
	# CarryComponent
	carry_component = CarryComponent.new()
	carry_component.stalker = self
	add_child(carry_component)
	carry_component.artifact_picked_up.connect(_on_artifact_picked_up)
	carry_component.artifact_dropped.connect(_on_artifact_dropped)
	carry_component.artifact_stolen.connect(_on_artifact_stolen)
	
	# StateMachineComponent
	state_machine = StateMachineComponent.new()
	state_machine.stalker = self
	add_child(state_machine)
	state_machine.setup({
		"behavior": behavior_strategy,
		"navigation": navigation_component,
		"memory": memory_component,
		"carry": carry_component,
		"health": health_component,
		"monolith": monolith
	})


func _setup_timers():
	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_cooldown_ended)
	add_child(attack_timer)
	
	detection_timer = Timer.new()
	detection_timer.wait_time = 0.5
	detection_timer.timeout.connect(_check_detection)
	add_child(detection_timer)
	detection_timer.start()


func _check_detection():
	if not is_alive or not monolith:
		return
	
	# Проверяем, не коснулся ли монолита
	if global_position.distance_to(monolith.global_position) < 5.0:
		if zone_controller:
			zone_controller.finish_run(false)
		return
	
	# Если нет цели, заставляем state machine переоценить ситуацию
	if not current_target and state_machine:
		state_machine._check_transitions()


func _on_threat_detected(threat: Node, type: String):
	if not current_target:
		current_target = threat
		target_acquired.emit(threat, type)
		print("Цель обнаружена: " + str(threat) + " тип: " + type)
		
		# Двигаемся к цели
		if navigation_component and threat is Node3D:
			navigation_component.move_to(threat.global_position)


func _on_threat_lost(threat: Node):
	if current_target == threat:
		current_target = null
		target_lost.emit(threat)
		print("Цель потеряна: " + str(threat))


func _on_artifact_detected(artifact: Node):
	# Проверяем, можем ли подобрать
	if carry_component and not carry_component.has_artifact():
		if carry_component.can_pick_up(artifact):
			# Двигаемся к артефакту
			if navigation_component:
				navigation_component.move_to(artifact.global_position)
				print("Движение к артефакту")


func _on_artifact_picked_up(artifact: Node):
	var value = artifact.get_value() if artifact.has_method("get_value") else 0
	artifact_picked_up.emit(artifact, value)
	print("Артефакт поднят, ценность: " + str(value))


func _on_artifact_dropped(artifact: Node):
	artifact_dropped.emit(artifact)
	print("Артефакт выброшен")


func _on_artifact_stolen(artifact: Node):
	var value = artifact.get_value() if artifact.has_method("get_value") else 0
	artifact_stolen.emit(artifact, value)
	print("Артефакт украден, ценность: " + str(value))


func _on_attack_cooldown_ended():
	# Можно атаковать снова
	pass


func _ready_hook():
	"""Для переопределения в наследниках"""
	pass


func _physics_hook(_delta):
	"""Для переопределения в наследниках"""
	pass


func _physics_process(delta):
	if not is_alive:
		return
	
	# Обновляем компоненты
	if navigation_component:
		navigation_component._physics_process(delta)
	
	if memory_component:
		memory_component._process(delta)
	
	if state_machine:
		state_machine._physics_process(delta)
		state_machine._process(delta)
	
	# Проверка состояния после обновления state machine
	if state_machine and state_machine.is_in_combat() and current_target:
		_try_attack()
	
	# Хук для наследников
	_physics_hook(delta)


func _try_attack():
	if not current_target or not is_instance_valid(current_target):
		return
	
	if attack_timer.time_left > 0:
		return
	
	var dist = global_position.distance_to(current_target.global_position)
	if dist <= attack_range:
		# Наносим урон
		var final_damage = damage
		if randf() < critical_chance:
			final_damage *= 2.0
			print("Критический удар!")
		
		if current_target.has_method("take_damage"):
			current_target.take_damage(final_damage, self)
			attack_timer.start()
			last_attack_time = Time.get_ticks_msec() / 1000.0


# ==================== ПУБЛИЧНОЕ API ====================

func pick_up_artifact(artifact: Node) -> bool:
	if carry_component:
		return carry_component.pick_up_artifact(artifact)
	return false


func drop_artifact() -> bool:
	if carry_component:
		return carry_component.drop_artifact()
	return false


func has_artifact() -> bool:
	return carry_component and carry_component.has_artifact()


func get_carried_artifact() -> Node:
	return carry_component.carried_artifact if carry_component else null


func get_carried_artifact_value() -> int:
	return carry_component.get_artifact_value() if carry_component else 0


func get_stalker_type() -> String:
	return GameEnums.StalkerType.keys()[stalker_type].to_lower()


func get_stalker_type_enum() -> GameEnums.StalkerType:
	return stalker_type


func get_behavior() -> String:
	return GameEnums.StalkerBehavior.keys()[behavior_type].to_lower()


func get_current_state() -> GameEnums.StalkerState:
	return state_machine.current_state if state_machine else GameEnums.StalkerState.IDLE


func get_current_state_name() -> String:
	return state_machine.get_state_name() if state_machine else "UNKNOWN"


func set_behavior(behavior: GameEnums.StalkerBehavior):
	behavior_type = behavior
	if state_machine and state_machine.behavior_strategy:
		state_machine.behavior_strategy = StalkerBehaviorStrategy.create(behavior, self)
	print("Поведение изменено на: " + str(behavior))


func get_target() -> Node:
	return current_target


func has_target() -> bool:
	return current_target != null and is_instance_valid(current_target)


func get_status() -> Dictionary:
	var status = super.get_status()
	status["type"] = get_stalker_type()
	status["behavior"] = get_behavior()
	status["state"] = get_current_state_name()
	status["has_artifact"] = has_artifact()
	status["artifact_value"] = get_carried_artifact_value() if has_artifact() else 0
	status["target"] = str(current_target) if current_target else "none"
	status["damage"] = damage
	status["vision_range"] = vision_range
	
	if memory_component:
		status["memory"] = memory_component.get_memory_stats()
	
	return status