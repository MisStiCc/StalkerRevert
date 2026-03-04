class_name Artifact
extends Node2D

## Базовый класс для всех артефактов в игре "Сталкер наоборот"
## Артефакты являются целью сталкеров и ресурсом для Зоны

# Параметры артефакта
var position: Vector2  # позиция артефакта на карте
var artifact_type: String  # тип артефакта
var value: int  # ценность артефакта
var effect: String  # эффект артефакта (опционально)

func _init(pos: Vector2, type: String = "common", val: int = 10) -> void:
	"""Инициализация артефакта с заданными параметрами"""
	position = pos
	global_position = pos
	artifact_type = type
	value = val
	effect = "none"
	name = "Artifact_" + artifact_type

func _ready() -> void:
	"""Подготовка артефакта к игре"""
	print("Артефакт ", artifact_type, " создан на позиции: ", position)

func collect(stalker) -> void:
	"""Сбор артефакта сталкером"""
	if stalker != null:
		emit_signal("collected_by_stalker", stalker)
		emit_signal("picked_up")
		print("Артефакт ", artifact_type, " собран сталкером ", stalker.name)
		# В реальной реализации тут будет начисление очков сталкеру
		# и возможно какие-то эффекты от артефакта
		queue_free()  # удаляем артефакт после сбора

func apply_effect(target) -> void:
	"""Применение эффекта артефакта к цели (реализация в подклассах)"""
	if effect != "none":
		print("Применение эффекта ", effect, " от артефакта ", artifact_type, " к ", target.name)

func update(delta: float) -> void:
	"""Метод обновления (для совместимости с архитектурой)"""
	# В базовом классе ничего не делаем, но подклассы могут переопределить

# Сигналы
signal collected_by_stalker(stalker)
signal picked_up