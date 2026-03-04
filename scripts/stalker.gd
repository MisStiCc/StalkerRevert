class_name Stalker
extends CharacterBody3D

## Базовый класс для всех сталкеров в игре "Сталкер наоборот"
## Сталкеры приходят на территорию Зоны, чтобы украсть артефакты

# Параметры сталкера
var health: float  # текущее здоровье
var max_health: float  # максимальное здоровье
var armor: float  # уровень брони
var damage: float  # урон, который может нанести сталкер
var speed: float  # скорость перемещения
var stalker_name: String  # имя/тип сталкера

# Навигация
var navigation_agent: NavigationAgent3D  # для поиска пути

# Сигналы
signal stalker_damaged(amount: float, type: String)
signal stalker_died
signal artifact_collected(artifact)
signal entered_zone
signal left_zone

func _init(name: String = "Stalker") -> void:
	"""Инициализация сталкера с заданными параметрами"""
	stalker_name = name
	max_health = 100.0
	health = max_health
	armor = 0.0
	damage = 10.0
	speed = 5.0

func _ready() -> void:
	"""Подготовка сталкера к игре"""
	print("Сталкер ", stalker_name, " появился")
	
	# Установка навигационного агента
	navigation_agent = NavigationAgent3D.new()
	add_child(navigation_agent)
	
	# Настройка навигационного агента
	navigation_agent.target_desired_distance = 2.0
	navigation_agent.path_desired_distance = 1.0
	navigation_agent.navigation_layers = 1

func _physics_process(delta: float) -> void:
	"""Обработка физики движения"""
	# Обновление направления движения через навигационный агент
	if navigation_agent.is_navigation_finished():
		velocity = Vector3.ZERO
	else:
		var next_waypoint = navigation_agent.get_next_path_position()
		var direction = (next_waypoint - global_position).normalized()
		velocity = direction * speed
	
	move_and_slide()

func take_damage(amount: float, damage_type: String = "physical") -> void:
	"""Получение урона сталкером"""
	# Учет брони
	var actual_damage = max(0, amount - armor)
	health -= actual_damage
	
	emit_signal("stalker_damaged", actual_damage, damage_type)
	
	if health <= 0:
		die()

func die() -> void:
	"""Смерть сталкера"""
	print("Сталкер ", stalker_name, " убит")
	emit_signal("stalker_died")
	queue_free()  # удаляем ноду из сцены

func move_to(target_position: Vector3) -> void:
	"""Движение к целевой позиции"""
	navigation_agent.set_target_position(target_position)

func collect_artifact(artifact) -> void:
	"""Сбор артефакта"""
	if artifact != null:
		emit_signal("artifact_collected", artifact)
		print("Сталкер ", stalker_name, " собрал артефакт")

func avoid_anomaly(anomaly) -> void:
	"""Избегание аномалии (реализация в подклассах)"""
	# В базовом классе просто записываем, что сталкер обходит аномалию
	print("Сталкер ", stalker_name, " избегает аномалию ", anomaly.name)

func update(delta: float) -> void:
	"""Метод обновления (для совместимости с архитектурой)"""
	# В базовом классе ничего не делаем, но подклассы могут переопределить
	pass