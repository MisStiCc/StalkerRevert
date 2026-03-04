class_name HeatAnomaly
extends "res://scripts/anomaly.gd"

## Аномалия "Жарка" - наносит урон огнем всем объектам в радиусе действия

# Специфические параметры "Жарки"
var damage: float = 10.0  # урон за импульс
var damage_type: String = "fire"  # тип урона
var color: Color = Color.RED  # цвет аномалии

func _init(pos: Vector3) -> void:
	"""Инициализация аномалии 'Жарка' с заданной позицией"""
	super._init(pos)
	radius = 40.0
	duration = 45.0
	pulse_interval = 1.5
	name = "HeatAnomaly"

func apply_effect(target) -> void:
	"""Применение огненного эффекта к цели"""
	if target != null and target.has_method("take_damage"):
		target.take_damage(damage, damage_type)
		print("Жарка нанесла ", damage, " урона огнем объекту ", target.name)
	
	# Визуальный эффект (в реальной реализации)
	visual_effect(target)

func visual_effect(target) -> void:
	"""Создание визуального эффекта для цели"""
	# В реальной игре тут будет создание частиц огня и т.д.
	pass

func apply_pulse_effect() -> void:
	"""Применение импульса жара к целям в радиусе"""
	super.apply_pulse_effect()

func get_targets_in_range():
	"""Поиск целей в радиусе действия 'Жарки'"""
	# В реальной реализации будет использоваться Area3D для обнаружения объектов
	var targets = []
	
	# Заглушка - возвращаем пустой массив
	# В реальной игре тут будет поиск сталкеров и других уязвимых объектов
	return targets