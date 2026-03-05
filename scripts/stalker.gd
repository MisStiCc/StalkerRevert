extends CharacterBody3D
class_name Stalker

## Базовый класс для всех сталкеров в игре "Сталкер наоборот"
## Сталкеры приходят на территорию Зоны, чтобы украсть артефакты

# Сигналы
signal stalker_damaged(amount: float, type: String)
signal stalker_died(stalker: Stalker)
signal artifact_collected(artifact: Node3D)
signal entered_zone
signal left_zone

# Параметры сталкера
@export var stalker_name: String = "Stalker"  # имя/тип сталкера
@export var max_health: float = 100.0  # максимальное здоровье
@export var armor: float = 0.0  # уровень брони
@export var damage: float = 10.0  # урон, который может нанести сталкер
@export var speed: float = 5.0  # скорость перемещения
@export var detection_range: float = 20.0  # дальность обнаружения артефактов
@export var attack_range: float = 2.0  # дальность атаки

# Текущие значения
var health: float  # текущее здоровье
var current_target: Node3D = null  # текущая цель (артефакт)
var carried_artifacts: Array[Node] = []  # собранные артефакты

# Навигация
var navigation_agent: NavigationAgent3D  # для поиска пути

# ZoneController
var zone_controller: Node = null
var is_in_zone: bool = false


func _ready() -> void:
	"""Подготовка сталкера к игре"""
	health = max_health
	
	# Настройка навигационного агента
	_setup_navigation()
	
	# Поиск ZoneController
	zone_controller = get_tree().get_first_node_in_group("zone_controller")
	
	# Добавляем в группу сталкеров
	add_to_group("stalkers")
	
	# Запускаем поиск цели
	_find_nearest_artifact()
	
	print("Сталкер ", stalker_name, " появился на позиции ", global_position)


func _setup_navigation():
	"""Настройка навигации"""
	# Используем существующий NavigationAgent3D или создаем новый
	if has_node("NavigationAgent3D"):
		navigation_agent = $NavigationAgent3D
	else:
		navigation_agent = NavigationAgent3D.new()
		add_child(navigation_agent)
	
	# Настройка параметров
	navigation_agent.target_desired_distance = 2.0
	navigation_agent.path_desired_distance = 1.0
	navigation_agent.path_max_distance = 1000.0
	navigation_agent.velocity_computed.connect(_on_velocity_computed)


func _physics_process(delta: float) -> void:
	"""Обработка физики движения"""
	# Обновляем цель, если текущая исчезла
	if current_target and not is_instance_valid(current_target):
		current_target = null
		_find_nearest_artifact()
	
	# Если нет цели, ищем новую
	if not current_target:
		_find_nearest_artifact()
		return
	
	# Движение к цели
	if navigation_agent and current_target:
		navigation_agent.target_position = current_target.global_position
		
		if navigation_agent.is_navigation_finished():
			# Достигли цели - собираем артефакт
			if current_target is Artifact:
				_collect_artifact(current_target)
		else:
			# Двигаемся к цели
			var next_pos = navigation_agent.get_next_path_position()
			var direction = (next_pos - global_position).normalized()
			if direction.length() > 0:
				velocity = direction * speed
			else:
				velocity = Vector3.ZERO
			
			# Запрашиваем скорость у NavigationAgent для обхода препятствий
			navigation_agent.velocity = velocity
	else:
		velocity = Vector3.ZERO
	
	move_and_slide()
	
	# Обновляем статус в зоне
	_update_zone_status()


func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()


func _find_nearest_artifact() -> void:
	"""Поиск ближайшего артефакта"""
	var artifacts = get_tree().get_nodes_in_group("artifacts")
	var nearest = null
	var min_dist = INF
	
	for artifact in artifacts:
		if not is_instance_valid(artifact):
			continue
		
		var dist = global_position.distance_to(artifact.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = artifact
	
	if nearest:
		set_target(nearest)
	else:
		current_target = null


func set_target(target: Node3D) -> void:
	"""Установка цели"""
	current_target = target
	if navigation_agent and target:
		navigation_agent.target_position = target.global_position


func _collect_artifact(artifact: Node3D) -> void:
	"""Сбор артефакта"""
	if not is_instance_valid(artifact):
		return
	
	if artifact.has_method("collect"):
		artifact.collect(self)
		carried_artifacts.append(artifact)
		artifact_collected.emit(artifact)
		print("Сталкер ", stalker_name, " собрал артефакт")
	
	# Ищем следующий артефакт
	_find_nearest_artifact()


func take_damage(amount: float, damage_type: String = "physical") -> void:
	"""Получение урона сталкером"""
	# Учет брони
	var actual_damage = max(1, amount - armor)  # минимум 1 урон
	health -= actual_damage
	
	stalker_damaged.emit(actual_damage, damage_type)
	
	if health <= 0:
		die()


func die() -> void:
	"""Смерть сталкера"""
	print("Сталкер ", stalker_name, " убит")
	stalker_died.emit(self)
	
	# Добавляем биомассу в ZoneController
	if zone_controller and zone_controller.has_method("add_biomass"):
		var biomass_value = _get_biomass_value()
		zone_controller.add_biomass(biomass_value)
	
	queue_free()


func _get_biomass_value() -> float:
	"""Получение ценности биомассы за сталкера"""
	# Можно переопределить в подклассах
	return 10.0


func move_to(target_position: Vector3) -> void:
	"""Движение к целевой позиции (для внешнего вызова)"""
	if navigation_agent:
		navigation_agent.target_position = target_position


func avoid_anomaly(anomaly: Node3D) -> void:
	"""Избегание аномалии (реализация в подклассах)"""
	# В базовом классе просто записываем, что сталкер обходит аномалию
	print("Сталкер ", stalker_name, " избегает аномалию ", anomaly.name)


func _update_zone_status():
	"""Обновление статуса нахождения в зоне"""
	if not zone_controller:
		return
	
	var was_in_zone = is_in_zone
	is_in_zone = zone_controller.is_stalker_in_zone(self)
	
	if is_in_zone and not was_in_zone:
		entered_zone.emit()
		zone_controller.stalker_entered_zone.emit(self)
	elif not is_in_zone and was_in_zone:
		left_zone.emit()
		zone_controller.stalker_left_zone.emit(self)


# Для совместимости
func update(delta: float) -> void:
	"""Метод обновления (для совместимости)"""
	pass