# anomalies/electric_anomaly.gd
extends BaseAnomaly
class_name ElectricAnomaly

@export var stun_chance: float = 0.3
@export var stun_duration: float = 1.5


func _ready_hook():
    anomaly_type = GameEnums.AnomalyType.ELECTRIC
    anomaly_name = "Electric Anomaly"
    damage_per_second = 15.0
    difficulty_level = 1
    radius = 4.0
    color = Color(0.2, 0.6, 1)
    
    _update_size()
    _update_color()
    
    Logger.debug("ElectricAnomaly инициализирована", "Anomaly")


func _apply_damage():
    if not is_active:
        return
    
    for stalker in stalkers_in_zone:
        if is_instance_valid(stalker):
            if stalker.has_method("take_damage"):
                stalker.take_damage(damage_per_second, self)
                
                # Шанс оглушить
                if randf() < stun_chance and stalker.has_method("stun"):
                    stalker.stun(stun_duration)
                    Logger.debug("Сталкер оглушен", "Anomaly")
                
                energy_consumed.emit(damage_per_second)