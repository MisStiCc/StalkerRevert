class_name RareArtifact
extends "res://scripts/artifact.gd"

## Редкий артефакт - сложнее получить, но дает особые эффекты

var effect_duration: float = 5.0  # длительность эффекта в секундах
var effect_power: float = 1.5  # сила эффекта

func _init(pos: Vector3) -> void:
	"""Инициализация редкого артефакта"""
	super._init(pos, "rare", 25)
	name = "RareArtifact"
	effect = "speed_boost"  # эффект увеличения скорости

func collect(stalker) -> void:
	"""Сбор редкого артефакта сталкером"""
	if stalker != null:
		emit_signal("collected_by_stalker", stalker)
		emit_signal("picked_up")
		print("Сталкер ", stalker.name, " собрал редкий артефакт! Ценность: ", value)
		
		# Применяем эффект к сталкеру
		apply_effect_to_stalker(stalker)
		
		queue_free()  # удаляем артефакт после сбора

func apply_effect_to_stalker(stalker) -> void:
	"""Применение эффекта редкого артефакта к сталкеру"""
	if stalker.has_method("apply_artifact_effect"):
		stalker.apply_artifact_effect(effect, effect_duration, effect_power)
		print("Применен эффект ", effect, " к сталкеру ", stalker.name)
	else:
		print("Сталкер ", stalker.name, " не поддерживает эффекты артефактов")

func update(delta: float) -> void:
	"""Обновление редкого артефакта"""
	# Редкие артефакты могут иметь визуальные эффекты или анимации
	# В данном случае просто вызываем родительский метод
	super.update(delta)