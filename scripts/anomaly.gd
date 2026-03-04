class_name Anomaly
extends Node2D

## Базовый класс для всех аномалий в игре "Сталкер наоборот"
## Аномалии служат защитным механизмом Зоны, нанося урон сталкерам и ограничивая их передвижение

# Параметры аномалии
var position: Vector2  # позиция аномалии на карте
var radius: float = 50.0  # радиус действия аномалии
var duration: float = 60.0  # длительность существования аномалии (в секундах)
var pulse_interval: float = 2.0  # интервал между импульсами эффекта (в секундах)
var pulse_timer: float = 0.0  # таймер до следующего импульса
var lifetime: float = 0.0  # время, которое аномалия существует
var detection_area: Area2D  # область для обнаружения целей

# Сигналы
signal anomaly_activated
signal anomaly_deactivated
signal effect_applied(target)

func _init(pos: Vector2) -> void:
	"""Инициализация аномалии с заданной позицией"""
	position = pos
	global_position = pos

func _ready() -> void:
	"""Подготовка аномалии к работе"""
	print("Аномалия создана на позиции: ", position)
	
	# Создаем область обнаружения
	detection_area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	detection_area.add_child(collision_shape)
	detection_area.position = Vector2.ZERO
	
	# Подключаем сигнал обнаружения цели
	detection_area.body_entered.connect(_on_body_entered)
	
	add_child(detection_area)
	emit_signal("anomaly_activated")

func _process(delta: float) -> void:
	"""Основной цикл обновления аномалии"""
	lifetime += delta
	
	# Проверка, не истекло ли время существования
	if lifetime >= duration:
		deactivate()
		return
	
	# Обновление таймера импульса
	pulse_timer += delta
	if pulse_timer >= pulse_interval:
		pulse_timer = 0.0
		apply_pulse_effect()

func apply_effect(target) -> void:
	"""Применение эффекта аномалии к цели (будет переопределен в подклассах)"""
	print("Базовый эффект аномалии применен к ", target)

func apply_pulse_effect() -> void:
	"""Применение эффекта по таймеру (реализация в подклассах)"""
	# Находим цели в радиусе действия
	var targets = get_targets_in_range()
	for target in targets:
		apply_effect(target)
		emit_signal("effect_applied", target)

func get_targets_in_range():
	"""Поиск целей в радиусе действия аномалии"""
	var targets = []
	if detection_area:
		for body in detection_area.get_overlapping_bodies():
			if body.is_in_group("stalker"):
				targets.append(body)
	return targets

func _on_body_entered(body):
	"""Обработка входа объекта в зону действия аномалии"""
	if body.is_in_group("stalker"):
		print("Сталкер ", body.stalker_name, " вошел в зону действия аномалии ", name)

func is_active() -> bool:
	"""Проверка, активна ли аномалия"""
	return lifetime < duration

func deactivate() -> void:
	"""Деактивация аномалии"""
	emit_signal("anomaly_deactivated")
	queue_free()  # удаляем ноду из сцены

func update(delta: float) -> void:
	"""Метод обновления (для совместимости с архитектурой)"""
	_process(delta)