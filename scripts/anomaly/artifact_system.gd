extends Node
class_name ArtifactSystem

## Система артефактов
## Таймеры, превращения, сбор

signal artifact_created(artifact: Node, artifact_type: String, position: Vector3)
signal artifact_collected(artifact: Node, value: int)
signal artifact_timer_expired(artifact: Node)

var _parent_node: Node

# Сцены артефактов
@export var artifact_scenes: Dictionary = {}

# Ценности артефактов
@export var artifact_values: Dictionary = {}

# Редкость по сложности
@export var difficulty_to_rarity: Dictionary = {}

# Активные артефакты
var active_artifacts: Array[Node] = []

# Таймеры артефактов
var _timers: Dictionary = {}  # artifact_instance_id -> Timer


func _init(node: Node):
	_parent_node = node


func setup(values: Dictionary, rarity: Dictionary):
	artifact_values = values
	difficulty_to_rarity = rarity


func create_artifact(artifact_type: String, position: Vector3, rarity: String = "common", value: float = 10.0, lifetime: float = 0.0) -> Node:
	"""Создать артефакт"""
	if not artifact_scenes.has(artifact_type):
		# Создаём базовый если нет сцены
		return _create_basic_artifact(position, rarity, value)
	
	var scene = artifact_scenes[artifact_type]
	if not scene:
		return _create_basic_artifact(position, rarity, value)
	
	var artifact = scene.instantiate()
	artifact.position = position
	artifact.add_to_group("artifacts")
	artifact.add_to_group("artifacts_" + rarity)
	
	# Настраиваем
	if artifact.has_method("set_rarity"):
		artifact.set_rarity(rarity)
	if artifact.has_method("set_value"):
		artifact.set_value(int(value))
	
	_parent_node.get_tree().current_scene.add_child(artifact)
	active_artifacts.append(artifact)
	
	# Запускаем таймер если есть lifetime
	if lifetime > 0:
		_start_lifetime_timer(artifact, lifetime)
	
	artifact_created.emit(artifact, artifact_type, position)
	return artifact


func _create_basic_artifact(position: Vector3, rarity: String, value: float) -> Node:
	"""Создать базовый артефакт (заглушка)"""
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.position = position
	
	# Простой меш
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh_instance.mesh = sphere
	
	# Материал по редкости
	var mat = StandardMaterial3D.new()
	match rarity:
		"common": mat.albedo_color = Color.WHITE
		"rare": mat.albedo_color = Color(1, 0.8, 0)
		"legendary": mat.albedo_color = Color(0.8, 0.4, 1)
	mesh_instance.material_override = mat
	
	mesh_instance.add_to_group("artifacts")
	mesh_instance.add_to_group("artifacts_" + rarity)
	
	# Методы-заглушки
	mesh_instance.set_rarity = func(r): pass
	mesh_instance.set_value = func(v): pass
	mesh_instance.get_rarity = func(): return rarity
	mesh_instance.get_value = func(): return int(value)
	mesh_instance.is_collected = false
	mesh_instance.set_collected = func(c): mesh_instance.is_collected = c
	
	owner.get_tree().current_scene.add_child(mesh_instance)
	active_artifacts.append(mesh_instance)
	
	artifact_created.emit(mesh_instance, "basic_" + rarity, position)
	return mesh_instance


func collect_artifact(artifact: Node) -> int:
	"""Собрать артефакт"""
	if not is_instance_valid(artifact):
		return 0
	
	var value = 0
	if artifact.has_method("get_value"):
		value = artifact.get_value()
	
	# Останавливаем таймер
	_stop_lifetime_timer(artifact)
	
	var pos = artifact.global_position
	var rarity = "common"
	if artifact.has_method("get_rarity"):
		rarity = artifact.get_rarity()
	
	# Удаляем
	if artifact in active_artifacts:
		active_artifacts.erase(artifact)
	artifact.queue_free()
	
	artifact_collected.emit(artifact, value)
	return value


func get_artifact_at_position(pos: Vector3, radius: float = 2.0) -> Node:
	"""Получить артефакт в радиусе"""
	for a in active_artifacts:
		if not is_instance_valid(a):
			continue
		if a.is_collected if a.has_method("is_collected") else false:
			continue
		if a.global_position.distance_to(pos) <= radius:
			return a
	return null


func get_all_artifacts() -> Array[Node]:
	return active_artifacts.filter(func(a): return is_instance_valid(a))


func get_collected_artifacts() -> Array[Dictionary]:
	"""Получить все собранные артефакты (для ЛК)"""
	var result = []
	for a in active_artifacts:
		if not is_instance_valid(a):
			continue
		var rarity = a.get_rarity() if a.has_method("get_rarity") else "common"
		var value = a.get_value() if a.has_method("get_value") else 10
		result.append({"type": rarity, "value": value})
	return result


func get_rarity_for_difficulty(difficulty: int) -> String:
	var rand_val = randf()
	
	match difficulty:
		1:
			if rand_val < 0.7: return "common"
			elif rand_val < 0.95: return "rare"
			else: return "legendary"
		2:
			if rand_val < 0.5: return "common"
			elif rand_val < 0.9: return "rare"
			else: return "legendary"
		3:
			if rand_val < 0.3: return "common"
			elif rand_val < 0.8: return "rare"
			else: return "legendary"
	
	return "common"


func _start_lifetime_timer(artifact: Node, lifetime: float):
	var timer = owner.get_tree().create_timer(lifetime)
	timer.timeout.connect(func(): _on_artifact_timer_expired(artifact))
	_timers[artifact.get_instance_id()] = timer


func _stop_lifetime_timer(artifact: Node):
	var id = artifact.get_instance_id()
	if _timers.has(id):
		_timers[id].queue_free()
		_timers.erase(id)


func _on_artifact_timer_expired(artifact: Node):
	artifact_timer_expired.emit(artifact)
	# Удаляем артефакт
	if artifact in active_artifacts:
		active_artifacts.erase(artifact)
		artifact.queue_free()


func stop_all_timers():
	for timer in _timers.values():
		if is_instance_valid(timer):
			timer.queue_free()
	_timers.clear()


func clear_all():
	stop_all_timers()
	for artifact in active_artifacts:
		if is_instance_valid(artifact):
			artifact.queue_free()
	active_artifacts.clear()


func set_artifact_scenes(scenes: Dictionary):
	artifact_scenes = scenes


func set_values(values: Dictionary):
	artifact_values = values
