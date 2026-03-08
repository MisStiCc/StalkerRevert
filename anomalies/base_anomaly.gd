# anomalies/base_anomaly.gd
extends Area3D
class_name BaseAnomaly

## Базовый класс для всех аномалий

signal stalker_entered(stalker: Node3D)
signal stalker_exited(stalker: Node3D)
signal energy_consumed(amount: float)
signal destroyed(anomaly: BaseAnomaly)
signal damaged(amount: float, current_health: float)

# Параметры
@export var anomaly_type: GameEnums.AnomalyType = GameEnums.AnomalyType.HEAT
@export var anomaly_name: String = "Base Anomaly"
@export var damage_per_second: float = 10.0
@export var is_active: bool = true
@export var difficulty_level: int = 1
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var radius: float = 5.0
@export var color: Color = Color.WHITE

# Визуал
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var particles: GPUParticles3D = $GPUParticles3D if has_node("GPUParticles3D") else null
@onready var light: OmniLight3D = $OmniLight3D if has_node("OmniLight3D") else null

# Состояние
var stalkers_in_zone: Array[Node3D] = []
var damage_timer: Timer
var pulse_timer: Timer
var _is_dying: bool = false
var creation_time: float = 0.0


func _ready():
    creation_time = Time.get_ticks_msec() / 1000.0
    max_health = health
    
    add_to_group("anomalies")
    add_to_group("anomalies_" + get_type_name())
    
    _setup_timers()
    _update_size()
    _update_color()
    
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    
    _ready_hook()
    
    Logger.info("Аномалия создана: " + get_type_name() + " сложность: " + str(difficulty_level), "Anomaly")


func _setup_timers():
    damage_timer = Timer.new()
    damage_timer.wait_time = 1.0
    damage_timer.timeout.connect(_apply_damage)
    add_child(damage_timer)
    damage_timer.start()
    
    pulse_timer = Timer.new()
    pulse_timer.wait_time = 0.2
    pulse_timer.timeout.connect(_pulse_effect)
    add_child(pulse_timer)
    pulse_timer.start()


func _ready_hook():
    """Для переопределения в наследниках"""
    pass


func _process(delta):
    _process_hook(delta)


func _process_hook(_delta):
    """Для переопределения в наследниках"""
    pass


func _on_body_entered(body: Node3D):
    if body.has_method("take_damage") and not body in stalkers_in_zone:
        stalkers_in_zone.append(body)
        stalker_entered.emit(body)
        Logger.debug("Сталкер вошел в аномалию: " + str(body), "Anomaly")


func _on_body_exited(body: Node3D):
    if body in stalkers_in_zone:
        stalkers_in_zone.erase(body)
        stalker_exited.emit(body)
        Logger.debug("Сталкер вышел из аномалии: " + str(body), "Anomaly")


func _apply_damage():
    if not is_active:
        return
    
    for stalker in stalkers_in_zone:
        if is_instance_valid(stalker):
            if stalker.has_method("take_damage"):
                stalker.take_damage(damage_per_second, self)
                energy_consumed.emit(damage_per_second)
                Logger.debug("Нанесен урон: " + str(damage_per_second) + " сталкеру: " + str(stalker), "Anomaly")


func _pulse_effect():
    """Визуальный пульс аномалии"""
    if mesh_instance and mesh_instance.material_override:
        var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.3 + 0.7
        mesh_instance.material_override.emission_energy_multiplier = pulse


func _update_size():
    if collision_shape and collision_shape.shape:
        if collision_shape.shape is SphereShape3D:
            collision_shape.shape.radius = radius
    
    if mesh_instance and mesh_instance.mesh:
        if mesh_instance.mesh is SphereMesh:
            mesh_instance.mesh.radius = radius
            mesh_instance.mesh.height = radius * 2
        elif mesh_instance.mesh is CylinderMesh:
            mesh_instance.mesh.top_radius = radius
            mesh_instance.mesh.bottom_radius = radius
            mesh_instance.mesh.height = radius * 2


func _update_color():
    if mesh_instance and mesh_instance.material_override:
        mesh_instance.material_override.albedo_color = color
        mesh_instance.material_override.emission = color
    
    if light:
        light.light_color = color


# ==================== ПУБЛИЧНОЕ API ====================

func take_damage(amount: float, attacker = null):
    if _is_dying:
        return
    
    health -= amount
    damaged.emit(amount, health)
    
    Logger.debug("Аномалия получила урон: " + str(amount) + ", осталось: " + str(health), "Anomaly")
    
    if health <= 0:
        _destroy()


func _destroy():
    if _is_dying:
        return
    _is_dying = true
    
    destroyed.emit(self)
    Logger.info("Аномалия уничтожена: " + get_type_name(), "Anomaly")
    
    # Эффект уничтожения
    if particles:
        particles.emitting = true
        await get_tree().create_timer(particles.lifetime).timeout
    
    queue_free()


func set_difficulty(difficulty: int):
    difficulty_level = difficulty
    health = 100.0 * difficulty
    max_health = health
    damage_per_second *= (1.0 + (difficulty - 1) * 0.5)
    
    Logger.debug("Сложность аномалии изменена на " + str(difficulty), "Anomaly")


func set_radius(new_radius: float):
    radius = new_radius
    _update_size()


func set_active(active: bool):
    is_active = active
    if mesh_instance:
        mesh_instance.visible = active
    Logger.debug("Аномалия " + ("активирована" if active else "деактивирована"), "Anomaly")


func get_type_name() -> String:
    return GameEnums.AnomalyType.keys()[anomaly_type].to_lower()


func get_anomaly_type() -> GameEnums.AnomalyType:
    return anomaly_type


func get_difficulty() -> int:
    return difficulty_level


func get_health_percent() -> float:
    return health / max_health if max_health > 0 else 0.0


func get_stalker_count() -> int:
    return stalkers_in_zone.size()


func get_info() -> Dictionary:
    return {
        "type": get_type_name(),
        "difficulty": difficulty_level,
        "health": health,
        "max_health": max_health,
        "health_percent": get_health_percent(),
        "damage": damage_per_second,
        "radius": radius,
        "active": is_active,
        "stalkers": get_stalker_count(),
        "age": (Time.get_ticks_msec() / 1000.0) - creation_time
    }