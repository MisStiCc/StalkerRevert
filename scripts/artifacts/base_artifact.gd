extends Node3D
class_name BaseArtifact

## Базовый класс для всех артефактов
## Содержит ТОЛЬКО общий функционал

# Сигналы
signal collected(artifact: BaseArtifact, collector: Node)
signal stolen(artifact: BaseArtifact, collector: Node)
signal expired

# Параметры (обязательные для всех)
@export var artifact_name: String = "Artifact"
@export var artifact_type: String = "base"
@export var artifact_value: float = 10.0  # ценность в биомассе
@export var energy_reward: float = 5.0    # сколько энергии дает при сборе
@export var color: Color = Color.WHITE

# Редкость
@export var rarity: String = "common"  # common, rare, legendary
@export_group("Rarity Colors")
@export var common_color: Color = Color(0.7, 0.7, 0.7, 1)
@export var rare_color: Color = Color(0.3, 0.5, 1.0, 1)
@export var legendary_color: Color = Color(1.0, 0.8, 0.2, 1)

# Состояние
var is_collected: bool = false
var lifespan: float = 0.0  # 0 = бесконечно

# Референсы
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var particles: GPUParticles3D = $GPUParticles3D


func _ready():
	add_to_group("artifacts")
	
	# Вызываем хуки
	_ready_hook()
	_update_visual()


# --- Хуки для наследников ---
func _ready_hook(): pass
func _process_hook(_delta): pass
func _collect_hook(_collector: Node): pass
func _expire_hook(): pass


# --- Визуал ---
func _update_visual():
	"""Настройка базового визуала"""
	if light:
		light.light_color = color
	
	if particles and particles.process_material:
		var material = particles.process_material as ParticleProcessMaterial
		material.color = color


func _update_visual_by_rarity():
	"""Визуальные отличия по редкости"""
	var rarity_color = common_color
	match rarity:
		"rare":
			rarity_color = rare_color
		"legendary":
			rarity_color = legendary_color
	
	if mesh_instance and mesh_instance.material_override:
		mesh_instance.material_override.albedo_color = rarity_color
		mesh_instance.material_override.emission = rarity_color
	
	if light:
		light.light_color = rarity_color


# --- Основные методы ---
func collect(collector: Node):
	if is_collected: return
	
	is_collected = true
	
	if collector.has_method("get_stalker_type"):
		# Сталкер украл артефакт
		stolen.emit(self, collector)
	else:
		# Зона собрала артефакт
		collected.emit(self, collector)
	
	_collect_hook(collector)
	
	# Эффект сбора
	_spawn_collect_effect()
	
	queue_free()


func _spawn_collect_effect():
	"""Эффект при сборе - можно переопределить"""
	pass


func apply_effect(collector: Node):
	"""Применение эффекта к сталкеру"""
	if collector.has_method("add_energy"):
		collector.add_energy(energy_reward)


# --- Установка редкости и ценности ---
func set_rarity_and_value(new_rarity: String, value: float):
	rarity = new_rarity
	artifact_value = value
	_update_visual_by_rarity()


# --- Лайфтайм ---
func set_lifespan(seconds: float):
	lifespan = seconds
	if lifespan > 0:
		await get_tree().create_timer(lifespan).timeout
		if not is_collected and is_instance_valid(self):
			expired.emit()
			queue_free()


# --- Геттеры ---
func get_value() -> float:
	return artifact_value


func get_artifact_name() -> String:
	return artifact_name


func get_rarity() -> String:
	return rarity
