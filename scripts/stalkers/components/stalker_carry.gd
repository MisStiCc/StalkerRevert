extends Node
class_name StalkerCarry

## Управление переносом артефактов

signal artifact_picked_up(artifact: Node)
signal artifact_dropped(artifact: Node)
signal artifact_stolen(artifact: Node)

var owner_stalker: CharacterBody3D

# Переносимый артефакт
var carried_artifact: Node = null
var is_carrying: bool = false


func _init(stalker: CharacterBody3D):
	owner_stalker = stalker


# ==================== ПУБЛИЧНОЕ API ====================

func pick_up_artifact(artifact: Node) -> bool:
	"""Подобрать артефакт"""
	if is_carrying:
		return false
	
	if not is_instance_valid(artifact):
		return false
	
	# Проверяем что это артефакт
	if not artifact.has_method("is_collected"):
		return false
	
	# Подбираем
	carried_artifact = artifact
	carried_artifact.set_collected(true)
	carried_artifact.visible = false  # Скрываем визуально
	
	# Перемещаем в сталкера
	if owner_stalker.has_method("add_child"):
		owner_stalker.add_child(artifact)
		artifact.reparent(owner_stalker)
		artifact.position = Vector3(0, 1.5, 0)
	
	is_carrying = true
	artifact_picked_up.emit(artifact)
	
	# Обновляем визуал
	_update_carry_visual(true)
	
	return true


func drop_artifact() -> bool:
	"""Выбросить артефакт"""
	if not is_carrying or not is_instance_valid(carried_artifact):
		return false
	
	# Перемещаем в мир
	var world_pos = owner_stalker.global_position + Vector3(0, 1, 0)
	carried_artifact.reparent(owner_stalker.get_tree().current_scene)
	carried_artifact.global_position = world_pos
	carried_artifact.visible = true
	carried_artifact.set_collected(false)
	
	artifact_dropped.emit(carried_artifact)
	
	carried_artifact = null
	is_carrying = false
	
	# Обновляем визуал
	_update_carry_visual(false)
	
	return true


func steal_artifact() -> bool:
	"""Украсть артефакт (доставить к краю карты)"""
	if not is_carrying:
		return false
	
	# Вычисляем позицию края карты
	var edge_pos = _get_edge_position()
	
	carried_artifact.reparent(owner_stalker.get_tree().current_scene)
	carried_artifact.global_position = edge_pos
	carried_artifact.visible = true
	carried_artifact.set_collected(false)
	
	artifact_stolen.emit(carried_artifact)
	
	carried_artifact = null
	is_carrying = false
	
	# Обновляем визуал
	_update_carry_visual(false)
	
	return true


func has_artifact() -> bool:
	return is_carrying and is_instance_valid(carried_artifact)


func get_carried_artifact() -> Node:
	return carried_artifact


func get_artifact_value() -> int:
	if not has_artifact() or not carried_artifact.has_method("get_value"):
		return 0
	return carried_artifact.get_value()


func get_artifact_type() -> String:
	if not has_artifact() or not carried_artifact.has_method("get_rarity"):
		return ""
	return carried_artifact.get_rarity()


# ==================== ВНУТРЕННИЕ МЕТОДЫ ====================

func _get_edge_position() -> Vector3:
	"""Получить позицию края карты"""
	var monolith = owner_stalker.get_tree().get_first_node_in_group("monolith")
	
	if not monolith:
		# Просто возвращаем позицию сталкера + 100 в направлении движения
		return owner_stalker.global_position + owner_stalker.velocity.normalized() * 100
	
	# Направление от монолита
	var dir = (owner_stalker.global_position - monolith.global_position).normalized()
	return monolith.global_position + dir * 100


func _update_carry_visual(is_carrying: bool):
	"""Обновить визуальное отображение"""
	if owner_stalker.has_method("_update_carry_visual"):
		owner_stalker._update_carry_visual(is_carrying)
