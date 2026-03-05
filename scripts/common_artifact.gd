extends Artifact
class_name CommonArtifact

## Коллекционный артефакт - простой для получения, базовая цель для новичков


func _ready() -> void:
	"""Инициализация коллекционного артефакта"""
	# Устанавливаем параметры через свойства базового класса
	artifact_type = "common"
	artifact_value = 10
	artifact_name = "Common Artifact"
	effect = "none"
	color = Color(1, 1, 0, 1)  # желтый
	
	# Вызываем базовый _ready
	super._ready()
	
	print("Коллекционный артефакт создан с ценностью ", artifact_value)


# Не нужно переопределять collect, так как базовый класс уже делает всё правильно
# Оставляем для специфичного поведения, если нужно

func apply_effect(target: Node3D) -> void:
	"""У простого артефакта нет эффекта"""
	# Переопределяем, чтобы ничего не делать
	pass