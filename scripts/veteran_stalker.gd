class_name VeteranStalker
extends "res://scripts/stalker.gd"

## Сталкер-ветеран - более сильный и осторожный противник

func _init() -> void:
	"""Инициализация ветерана с соответствующими параметрами"""
	super._init("Veteran")
	max_health = 100.0
	health = max_health
	armor = 10.0
	damage = 20.0
	speed = 100.0
	name = "VeteranStalker"

func avoid_anomaly(anomaly) -> void:
	"""Ветеран более осторожно избегает аномалий"""
	# Ветеран лучше понимает опасность аномалий и активно их избегает
	var safe_pos = find_safe_position_around_anomaly(anomaly)
	if safe_pos != global_position:
		move_to(safe_pos)
		print("Ветеран осторожно избегает аномалию ", anomaly.name)

func find_safe_position_around_anomaly(anomaly) -> Vector2:
	"""Поиск безопасной позиции вокруг аномалии"""
	# В реальной реализации тут будет более сложная логика
	# с использованием навигационной сетки
	var direction_to_anomaly = (anomaly.global_position - global_position).normalized()
	var safe_distance = anomaly.radius + 30.0  # немного больше радиуса аномалии
	return anomaly.global_position + direction_to_anomaly * safe_distance

func update(delta: float) -> void:
	"""Обновление поведения ветерана"""
	# Ветеран может координировать действия с другими сталкерами
	# и более осторожно подходить к аномалиям
	pass

func get_biomass_value() -> int:
	return 15