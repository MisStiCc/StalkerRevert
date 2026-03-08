# entities/artifacts/base_artifact.gd
extends Collectible
class_name BaseArtifact

## Базовый класс для всех артефактов

# Параметры
@export var artifact_name: String = "Artifact"
@export var artifact_value: int = 10
@export var artifact_rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
@export var energy_reward: float = 5.0
@export var effect_duration: float = 0.0

# Визуал
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var light: OmniLight3D = $OmniLight3D if has_node("OmniLight3D") else null
@onready var particles: GPUParticles3D = $GPUParticles3D if has_node("GPUParticles3D") else null

# Состояние
var rotation_speed: float = 1.0
var float_amplitude: float = 0.2
var float_speed: float = 2.0
var original_y: float = 0.0


func _ready():
    collectible_name = artifact_name
    value = artifact_value
    rarity = artifact_rarity
    
    add_to_group("artifacts")
    add_to_group("artifacts_" + get_rarity_name())
    
    original_y = position.y
    _update_visual()
    _ready_hook()
    
    Logger.debug("Артефакт создан: " + artifact_name + " (" + get_rarity_name() + ") ценность: " + str(value), "Artifact")


func _process(delta):
    # Вращение
    rotate_y(rotation_speed * delta)
    
    # Парение
    if float_amplitude > 0:
        position.y = original_y + sin(Time.get_ticks_msec() * 0.001 * float_speed) * float_amplitude


func _ready_hook():
    """Для переопределения в наследниках"""
    pass


func _collect_hook(collector: Node):
    # Применяем эффект к коллектору
    if collector.has_method("add_energy"):
        collector.add_energy(energy_reward)
    
    if effect_duration > 0 and collector.has_method("apply_effect"):
        collector.apply_effect(artifact_name, effect_duration)
    
    Logger.debug("Эффект артефакта применен к " + str(collector), "Artifact")


func _update_visual():
    var rarity_color = _get_rarity_color()
    
    if mesh_instance and mesh_instance.material_override:
        mesh_instance.material_override.albedo_color = rarity_color
        mesh_instance.material_override.emission = rarity_color
    
    if light:
        light.light_color = rarity_color
    
    if particles and particles.process_material:
        var material = particles.process_material as ParticleProcessMaterial
        if material:
            material.color = rarity_color


func _get_rarity_color() -> Color:
    match rarity:
        GameEnums.Rarity.COMMON:
            return Color(0.7, 0.7, 0.7)
        GameEnums.Rarity.RARE:
            return Color(0.3, 0.5, 1.0)
        GameEnums.Rarity.LEGENDARY:
            return Color(1.0, 0.8, 0.2)
    return Color.WHITE


func _spawn_collect_effect():
    if particles:
        particles.emitting = true
        await get_tree().create_timer(particles.lifetime).timeout


func set_rarity_and_value(new_rarity: GameEnums.Rarity, new_value: int):
    rarity = new_rarity
    value = new_value
    _update_visual()
    Logger.debug("Редкость изменена на " + get_rarity_name() + ", ценность: " + str(value), "Artifact")


func get_artifact_name() -> String:
    return artifact_name


func get_energy_reward() -> float:
    return energy_reward


func get_info() -> Dictionary:
    var info = super.get_info()
    info["artifact_name"] = artifact_name
    info["energy_reward"] = energy_reward
    info["effect_duration"] = effect_duration
    return info