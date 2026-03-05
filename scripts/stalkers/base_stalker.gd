extends CharacterBody3D
class_name BaseStalker

# Базовые параметры сталкера
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var speed: float = 5.0
@export var damage: float = 10.0
@export var armor: float = 0.0
@export var detection_range: float = 20.0
@export var attack_range: float = 2.0
@export var carry_capacity: int = 5
@export var stalker_type: String = "common"

# Состояния сталкера
enum StalkerState {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	FLEE,
	DEAD
}

var current_state: StalkerState = StalkerState.IDLE
var target: Node3D = null
var navigation_agent: NavigationAgent3D

# Дополнительные состояния
var carried_artifacts: Array[String] = []
var current_target: Node3D = null
var is_in_zone: bool = false
var is_alive: bool = true

# Интеграция с ZoneController
var zone_controller: Node = null

# Сигналы
signal health_changed(current_health: float, max_health: float)
signal state_changed(new_state: StalkerState)
signal died(stalker: BaseStalker)
signal entered_zone(zone_name: String)
signal exited_zone(zone_name: String)
signal artifact_collected(artifact_name: String)


func _ready():
	# Инициализация навигации
	_setup_navigation()
	
	# Подписка на сигналы
	health_changed.emit(health, max_health)
	state_changed.emit(current_state)
	
	# Инициализация состояний
	is_alive = true
	
	# Добавляем себя в группу сталкеров
	add_to_group("stalkers")
	add_to_group("player")  # Для камеры
	
	# Поиск и подключение к ZoneController
	_connect_to_zone_controller()
	
	# Подписка на сигнал сбора артефактов
	artifact_collected.connect(_on_artifact_collected)


func _setup_navigation():
	# Получаем или создаём NavigationAgent3D
	if has_node("NavigationAgent3D"):
		navigation_agent = $NavigationAgent3D
	else:
		navigation_agent = NavigationAgent3D.new()
		add_child(navigation_agent)
	
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	
	# Настройка параметров навигации (Godot 4 правильные названия)
	navigation_agent.target_desired_distance = 2.0
	navigation_agent.path_desired_distance = 1.0
	navigation_agent.path_max_distance = 1000.0
	navigation_agent.avoidance_enabled = true
	navigation_agent.max_speed = speed


func _connect_to_zone_controller():
	"""Поиск и подключение к ZoneController"""
	zone_controller = get_tree().get_first_node_in_group("zone_controller")
	if zone_controller:
		# Подписка на сигналы ZoneController
		if zone_controller.has_signal("stalker_entered_zone"):
			zone_controller.stalker_entered_zone.connect(_on_entered_zone)
		if zone_controller.has_signal("stalker_left_zone"):
			zone_controller.stalker_left_zone.connect(_on_exited_zone)
		
		# Сообщаем ZoneController о нашем присутствии
		if zone_controller.has_method("update_stalker_status"):
			zone_controller.update_stalker_status(self)
		
		print("Сталкер подключен к ZoneController: ", zone_controller.name)
	else:
		print("ZoneController не найден")


func _find_target() -> Node3D:
	"""Поиск цели в пределах диапазона обнаружения"""
	var targets = []
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# Создание сферы обнаружения
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = detection_range
	query.shape = sphere_shape
	query.transform = global_transform
	query.collision_mask = 1  # Сталкеры ищут цели в слое 1
	query.exclude = [self]  # Исключаем себя
	
	var result = space_state.intersect_shape(query)
	for item in result:
		var collider = item.collider
		# Проверяем, что это не аномалия и не другой сталкер (если нужно)
		if collider != self and collider.has_method("take_damage"):
			# Дополнительная проверка, что это не сталкер (если нужно)
			if not collider.is_in_group("stalkers") or collider != self:
				targets.append(collider)
	
	# Возвращаем ближайшую цель
	if targets.size() > 0:
		var closest_target = targets[0]
		var closest_distance = global_position.distance_to(closest_target.global_position)
		
		for target in targets:
			var distance = global_position.distance_to(target.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_target = target
		
		return closest_target
	
	return null


func _physics_process(delta):
	if current_state == StalkerState.DEAD:
		return
	
	# Обновляем цель, если текущая невалидна
	if target and not is_instance_valid(target):
		target = null
	
	# Поиск новой цели, если нет текущей
	if not target and current_state != StalkerState.DEAD:
		var new_target = _find_target()
		if new_target:
			set_target(new_target)
	
	# Обработка состояний
	match current_state:
		StalkerState.IDLE:
			_handle_idle_state(delta)
		StalkerState.PATROL:
			_handle_patrol_state(delta)
		StalkerState.CHASE:
			_handle_chase_state(delta)
		StalkerState.ATTACK:
			_handle_attack_state(delta)
		StalkerState.FLEE:
			_handle_flee_state(delta)
	
	# Применяем движение (если не используем NavigationAgent)
	if not navigation_agent.is_navigation_finished() and current_state == StalkerState.CHASE:
		move_and_slide()


func _process(delta):
	# Обновление статуса в ZoneController (только в _process)
	if zone_controller and zone_controller.has_method("update_stalker_status"):
		zone_controller.update_stalker_status(self)


func _handle_idle_state(delta):
	# Логика состояния ожидания
	if target:
		_change_state(StalkerState.CHASE)


func _handle_patrol_state(delta):
	# Логика патрулирования
	pass


func _handle_chase_state(delta):
	if target and navigation_agent and is_instance_valid(target):
		# Устанавливаем цель для навигации
		if navigation_agent.is_navigation_finished() or navigation_agent.target_position.distance_to(target.global_position) > 0.1:
			navigation_agent.target_position = target.global_position
		
		# Если цель достигнута, переходим к атаке
		if navigation_agent.is_navigation_finished():
			var distance_to_target = global_position.distance_to(target.global_position)
			if distance_to_target < attack_range:
				_change_state(StalkerState.ATTACK)
		else:
			# Движение к цели через навигацию
			var next_position = navigation_agent.get_next_path_position()
			var direction = (next_position - global_position).normalized()
			if direction.length() > 0:
				velocity = direction * speed
			else:
				velocity = Vector3.ZERO
			
			# Запрашиваем скорость у NavigationAgent для обхода препятствий
			navigation_agent.velocity = velocity
	else:
		_change_state(StalkerState.IDLE)


func _handle_attack_state(delta):
	if target and is_instance_valid(target):
		# Нанесение урона цели
		_attack_target()
		
		# Проверка расстояния
		var distance_to_target = global_position.distance_to(target.global_position)
		if distance_to_target > attack_range * 2:
			_change_state(StalkerState.CHASE)
		elif health < max_health * 0.3:
			_change_state(StalkerState.FLEE)
	else:
		_change_state(StalkerState.IDLE)


func _handle_flee_state(delta):
	# Логика бегства от опасности
	# Просто бежим от текущей цели
	if target and is_instance_valid(target):
		var flee_direction = (global_position - target.global_position).normalized()
		velocity = flee_direction * speed
		move_and_slide()
	else:
		_change_state(StalkerState.IDLE)


func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()


func _change_state(new_state: StalkerState):
	if current_state != new_state:
		current_state = new_state
		state_changed.emit(new_state)


func take_damage(amount: float, damage_type: String = "physical"):
	if not is_alive:
		return
	
	# Применение брони
	var actual_damage = max(1, amount - armor)  # минимум 1 урон
	health -= actual_damage
	health_changed.emit(health, max_health)
	
	if health <= 0:
		die()


func die():
	if not is_alive:
		return
	
	is_alive = false
	current_state = StalkerState.DEAD
	died.emit(self)
	
	# Добавляем биомассу в ZoneController
	if zone_controller and zone_controller.has_method("add_biomass"):
		zone_controller.add_biomass(_get_biomass_value())
	
	# Удаляем сталкера через небольшой промежуток времени
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()


func _get_biomass_value() -> float:
	"""Получение ценности биомассы за сталкера"""
	match stalker_type:
		"novice":
			return 8.0
		"veteran":
			return 15.0
		_:
			return 10.0


func _attack_target():
	"""Внутренний метод атаки цели"""
	if target and target.has_method("take_damage") and is_instance_valid(target):
		target.take_damage(damage)
		print("Сталкер ", name, " атакует цель ", target.name, ", нанося ", damage, " урона")


func set_target(new_target: Node3D):
	if not is_alive:
		return
	
	target = new_target
	current_target = new_target
	
	if target:
		_change_state(StalkerState.CHASE)
	else:
		_change_state(StalkerState.IDLE)


# Методы для работы с артефактами
func add_artifact(artifact_type: String):
	"""Добавление артефакта в инвентарь"""
	carried_artifacts.append(artifact_type)
	print("Артефакт ", artifact_type, " добавлен в инвентарь сталкера ", name)
	
	# Применяем эффект артефакта
	_apply_artifact_effect(artifact_type)


func _apply_artifact_effect(artifact_type: String):
	"""Применение эффекта артефакта"""
	match artifact_type:
		"energy":
			# Энергетический артефакт - увеличивает здоровье
			health = min(health + 20, max_health)
			health_changed.emit(health, max_health)
		"rare":
			# Редкий артефакт - увеличивает броню
			armor += 5
		"common":
			# Обычный артефакт - небольшое восстановление здоровья
			health = min(health + 10, max_health)
			health_changed.emit(health, max_health)


func _on_artifact_collected(artifact_type: String):
	"""Обработчик сигнала о сборе артефакта"""
	print("Сталкер ", name, " собрал артефакт: ", artifact_type)
	
	# Добавляем артефакт в инвентарь
	add_artifact(artifact_type)


# Обработчики сигналов ZoneController
func _on_entered_zone():
	"""Обработчик входа в зону"""
	is_in_zone = true
	entered_zone.emit(name)
	print("Сталкер ", name, " вошел в зону")


func _on_exited_zone():
	"""Обработчик выхода из зоны"""
	is_in_zone = false
	exited_zone.emit(name)
	print("Сталкер ", name, " вышел из зоны")


# Получение имени сталкера (для спавнера)
func get_stalker_name() -> String:
	return stalker_type