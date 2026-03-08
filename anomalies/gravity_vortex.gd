# anomalies/gravity_vortex.gd
extends BaseAnomaly
class_name GravityVortex

@export var pull_strength: float = 5.0
@export var rotation_speed: float = 2.0


func _ready_hook():
    anomaly_type = GameEnums.AnomalyType.GRAVITY_VORTEX
    anomaly_name = "Gravity Vortex"
    damage_per_second = 12.0
    difficulty_level = 2
    radius = 8.0
    color = Color(0.3, 0, 0.5)
    
    _update_size()
    _update_color()
    
    Logger.debug("GravityVortex инициализирована", "Anomaly")


func _process_hook(delta):
    if mesh_instance:
        mesh_instance.rotate_y(rotation_speed * delta)
    
    # Притягиваем сталкеров
    for stalker in stalkers_in_zone:
        if is_instance_valid(stalker):
            var direction = (global_position - stalker.global_position).normalized()
            stalker.global_position += direction * pull_strength * delta


func _apply_damage():
    if not is_active:
        return
    
    for stalker in stalkers_in_zone:
        if is_instance_valid(stalker):
            if stalker.has_method("take_damage"):
                # Урон зависит от расстояния (ближе к центру - больше урон)
                var dist = global_position.distance_to(stalker.global_position)
                var damage_mult = 1.0 - (dist / radius)
                var final_damage = damage_per_second * max(0.5, damage_mult)
                
                stalker.take_damage(final_damage, self)
                energy_consumed.emit(final_damage)