class_name CommonArtifact
extends "res://scripts/artifact.gd"

## Коллекционный артефакт - простой для получения, базовая цель для новичков

func _init(pos: Vector2) -> void:
	"""Инициализация коллекционного артефакта"""
	super._init(pos, "common", 10)
	name = "CommonArtifact"
	effect = "none"  # у простого артефакта нет эффекта

func collect(stalker) -> void:
	"""Сбор коллекционного артефакта сталкером"""
	if stalker != null:
		# Простой артефакт просто дает базовую ценность
		emit_signal("collected_by_stalker", stalker)
		emit_signal("picked_up")
		print("Сталкер ", stalker.name, " собрал коллекционный артефакт. Ценность: ", value)
		queue_free()  # удаляем артефакт после сбора