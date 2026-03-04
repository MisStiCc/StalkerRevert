class_name Anomaly
extends Node3D

## Базовый класс для всех аномалий в игре "Сталкер наоборот"
## Аномалии служат защитным механизмом Зоны, нанося урон сталкерам и ограничивая их передвижение

# Параметры аномалии
var position: Vector3  # позиция аномалии на карте
var radius: float = 50.0  # радиус действия аномалии
var duration: float = 60.0  # длительность существования аномалии (в секундах)
var pulse_interval: float = 2.0  # интервал между импульсами эффекта (в секундах)
var pulse_timer: float = 0.0  # таймер до следующего импульса
var lifetime: float = 0.0  # время, которое аномалия существует

# Сигналы
signal anomaly_activated
signal anomaly_deactivated
signal effect_applied(target)

func _init(pos: Vector3) -> void:
	"""Инициализация аномалии с заданной позицией"""
	position = pos
	global_position = pos

func _ready() -> void:
	"""Подготовка аномалии к работе"""
	print("Аномалия создана на позиции: ", position)
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
	# В реальной реализации будет использоваться Area3D или PhysicsBody3D
	# для обнаружения сталкеров и других объектов в радиусе
	var targets = []
	# Заглушка - возвращаем пустой массив
	# В реальной игре тут будет поиск объектов в радиусе
	return targets

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