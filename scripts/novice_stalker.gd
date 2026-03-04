class_name NoviceStalker
extends "res://scripts/stalker.gd"

## Сталкер-новичок - слабый, но дешевый противник

func _init() -> void:
	"""Инициализация новичка с соответствующими параметрами"""
	super._init("Novice")
	max_health = 50.0
	health = max_health
	armor = 0.0
	damage = 10.0
	speed = 80.0
	name = "NoviceStalker"

func avoid_anomaly(anomaly) -> void:
	"""Новичок слабо реагирует на аномалии"""
	# Просто немного меняет курс, не особо опасаясь аномалий
	var new_pos = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	move_to(new_pos)
	print("Новичок слабо избегает аномалию ", anomaly.name)

func update(delta: float) -> void:
	"""Обновление поведения новичка"""
	# Новички менее осторожны и могут идти прямо к цели
	# даже если рядом есть аномалии
	pass