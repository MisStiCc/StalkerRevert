extends Area3D
class_name Artifact

## Базовый класс для всех артефактов в игре "Сталкер наоборот"
## Артефакты являются целью сталкеров и ресурсом для Зоны

# Сигналы
signal collected_by_stalker(stalker: Node3D)
signal picked_up

# Параметры артефакта
@export var artifact_type: String = "common"  # тип артефакта
@export var artifact_value: int = 10  # ценность артефакта
@export var artifact_name: String = "Artifact"
@export var effect: String = "none"  # эффект артефакта (опционально)
@export var color: Color = Color(1, 1, 0, 1)  # цвет артефакта (желтый)
@export var pickup_radius: float = 1.5  # радиус подбора


func _ready() -> void:
	"""Подготовка артефакта к игре"""
	# Настройка имени
	name = "Artifact_" + artifact_type
	
	# Настройка коллизии
	_setup_collision()
	
	# Настройка визуального представления
	_setup_visuals()
	
	# Подключаем сигналы входа
	body_entered.connect(_on_body_entered)
	
	# Добавляем в группу для поиска
	add_to_group("artifacts")
	
	print("Артефакт ", artifact_type, " создан на позиции: ", global_position)


func _setup_collision():
	"""Настройка коллизии артефакта"""
	var collision_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = pickup_radius
	collision_shape.shape = sphere
	add_child(collision_shape)


func _setup_visuals():
	"""Настройка визуального представления"""
	# Создаем MeshInstance3D для отображения
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	mesh_instance.mesh = sphere_mesh
	
	# Создаем материал с цветом
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.5
	mesh_instance.material_override = material
	
	add_child(mesh_instance)
	
	# Добавляем легкий свет
	var omni_light = OmniLight3D.new()
	omni_light.light_color = color
	omni_light.light_energy = 1.0
	omni_light.omni_range = 3.0
	add_child(omni_light)


func _on_body_entered(body: Node3D) -> void:
	"""Обработчик входа тела в зону артефакта"""
	if body.has_method("collect_artifact") or body.has_method("add_artifact"):
		collect(body)


func collect(stalker: Node3D) -> void:
	"""Сбор артефакта сталкером"""
	if not is_instance_valid(stalker):
		return
	
	# Испускаем сигналы
	collected_by_stalker.emit(stalker)
	picked_up.emit()
	
	print("Артефакт ", artifact_type, " собран сталкером ", stalker.name)
	
	# Если у сталкера есть метод add_artifact, вызываем его
	if stalker.has_method("add_artifact"):
		stalker.add_artifact(artifact_type)
	
	# Применяем эффект к сталкеру
	apply_effect(stalker)
	
	# Удаляем артефакт
	queue_free()


func apply_effect(target: Node3D) -> void:
	"""Применение эффекта артефакта к цели (реализация в подклассах)"""
	if effect != "none":
		print("Применение эффекта ", effect, " от артефакта ", artifact_type, " к ", target.name)
		
		# Здесь можно реализовать разные эффекты
		match effect:
			"heal":
				if target.has_method("heal"):
					target.heal(artifact_value)
			"energy":
				if target.has_method("add_energy"):
					target.add_energy(artifact_value)
			"shield":
				if target.has_method("add_shield"):
					target.add_shield(artifact_value)


# Для совместимости со старым кодом
func update(delta: float) -> void:
	"""Метод обновления (пустой, для совместимости)"""
	pass


# Получение ценности артефакта
func get_value() -> int:
	return artifact_value


# Получение типа артефакта
func get_type() -> String:
	return artifact_type