extends Artifact
class_name RareArtifact

## Редкий артефакт - сложнее получить, но дает особые эффекты

# Параметры редкого артефакта
@export var effect_duration: float = 5.0  # длительность эффекта в секундах
@export var effect_power: float = 1.5  # сила эффекта


func _ready() -> void:
	"""Инициализация редкого артефакта"""
	# Устанавливаем параметры через свойства базового класса
	artifact_type = "rare"
	artifact_value = 25
	artifact_name = "Rare Artifact"
	effect = "speed_boost"
	color = Color(0.5, 0, 1, 1)  # фиолетовый
	
	# Вызываем базовый _ready
	super._ready()
	
	print("Редкий артефакт создан с ценностью ", artifact_value)


func apply_effect(target: Node3D) -> void:
	"""Применение эффекта редкого артефакта к сталкеру"""
	if not is_instance_valid(target):
		return
	
	if target.has_method("apply_artifact_effect"):
		target.apply_artifact_effect(effect, effect_duration, effect_power)
		print("Применен эффект ", effect, " к сталкеру ", target.name, " на ", effect_duration, " сек с силой ", effect_power)
	elif target.has_method("apply_effect"):
		# Альтернативный метод
		target.apply_effect(effect, effect_duration, effect_power)
		print("Применен эффект ", effect, " к сталкеру ", target.name)
	else:
		print("Сталкер ", target.name, " не поддерживает эффекты артефактов")


# Для совместимости со старым кодом
func apply_effect_to_stalker(stalker: Node3D) -> void:
	apply_effect(stalker)


func update(delta: float) -> void:
	"""Обновление редкого артефакта (пустой, для совместимости)"""
	# Редкие артефакты могут иметь визуальные эффекты или анимации
	# В данном случае просто ничего не делаем
	pass