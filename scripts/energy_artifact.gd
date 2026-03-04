class_name EnergyArtifact
extends "res://scripts/artifact.gd"

## Энергетический артефакт - дает особые энергетические способности

var energy_pulse_radius: float = 100.0  # радиус энергетического импульса
var energy_damage: float = 15.0  # урон от энергетического импульса
var pulse_cooldown: float = 2.0  # перезарядка между импульсами
var pulse_timer: float = 0.0

func _init(pos: Vector3) -> void:
	"""Инициализация энергетического артефакта"""
	super._init(pos, "energy", 40)
	name = "EnergyArtifact"
	effect = "energy_pulse"
	pulse_timer = pulse_cooldown  # начинаем с готовности к импульсу

func collect(stalker) -> void:
	"""Сбор энергетического артефакта сталкером"""
	if stalker != null:
		emit_signal("collected_by_stalker", stalker)
		emit_signal("picked_up")
		print("Сталкер ", stalker.name, " собрал энергетический артефакт! Ценность: ", value)
		
		# Создаем энергетический импульс при сборе
		create_energy_pulse()
		
		queue_free()  # удаляем артефакт после сбора

func update(delta: float) -> void:
	"""Обновление энергетического артефакта"""
	pulse_timer -= delta
	if pulse_timer <= 0:
		create_energy_pulse()
		pulse_timer = pulse_cooldown

func create_energy_pulse() -> void:
	"""Создание энергетического импульса вокруг артефакта"""
	print("Энергетический артефакт создает импульс! Радиус: ", energy_pulse_radius)
	
	# В реальной реализации тут будет поиск всех объектов в радиусе
	# и нанесение урона сталкерам или эффектов
	
	# Эмитируем сигнал для ZoneController или других систем
	emit_signal("energy_pulse_created", global_position, energy_pulse_radius, energy_damage)

func apply_effect_to_stalker(stalker) -> void:
	"""Применение эффекта энергетического артефакта к сталкеру"""
	if stalker.has_method("apply_artifact_effect"):
		stalker.apply_artifact_effect("energy_shield", 8.0, 0.7)
		print("Применен эффект энергетического щита к сталкеру ", stalker.name)
	else:
		print("Сталкер ", stalker.name, " не поддерживает эффекты артефактов")

# Дополнительные сигналы для энергетического артефакта
signal energy_pulse_created(position: Vector3, radius: float, damage: float)