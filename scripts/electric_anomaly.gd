class_name ElectricAnomaly
extends "res://scripts/anomaly.gd"

## Аномалия "Электра" - наносит урон электричеством и может оглушать цели

# Специфические параметры "Электры"
var damage: float = 15.0  # урон за импульс
var stun_chance: float = 0.3  # шанс оглушения (30%)
var stun_duration: float = 1.5  # длительность оглушения в секундах
var damage_type: String = "electric"  # тип урона
var color: Color = Color.BLUE  # цвет аномалии

func _init(pos: Vector2) -> void:
	"""Инициализация аномалии 'Электра' с заданной позицией"""
	super._init(pos)
	radius = 35.0
	duration = 50.0
	pulse_interval = 2.0
	name = "ElectricAnomaly"

func apply_effect(target) -> void:
	"""Применение электрического эффекта к цели"""
	if target != null and target.has_method("take_damage"):
		# Наносим урон
		target.take_damage(damage, damage_type)
		print("Электра нанесла ", damage, " урона электричеством объекту ", target.name)
		
		# Проверяем шанс оглушения
		if randf() < stun_chance and target.has_method("apply_stun"):
			target.apply_stun(stun_duration)
			print("Цель ", target.name, " оглушена на ", stun_duration, " секунд")
	
	# Визуальный эффект (в реальной реализации)
	visual_effect(target)

func visual_effect(target) -> void:
	"""Создание визуального эффекта для цели"""
	# В реальной игре тут будет создание эффекта разряда и т.д.
	pass

func apply_pulse_effect() -> void:
	"""Применение импульса электричества к целям в радиусе"""
	super.apply_pulse_effect()

func get_targets_in_range():
	"""Поиск целей в радиусе действия 'Электры'"""
	# В реальной реализации будет использоваться Area2D для обнаружения объектов
	var targets = []
	
	# Заглушка - возвращаем пустой массив
	# В реальной игре тут будет поиск сталкеров и других уязвимых объектов
	return targets