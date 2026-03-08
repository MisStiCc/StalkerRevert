# anomalies/heat_anomaly.gd
extends BaseAnomaly
class_name HeatAnomaly


func _ready_hook():
    anomaly_type = GameEnums.AnomalyType.HEAT
    anomaly_name = "Heat Anomaly"
    damage_per_second = 10.0
    difficulty_level = 1
    radius = 5.0
    color = Color(1, 0.5, 0)
    
    _update_size()
    _update_color()
    
    Logger.debug("HeatAnomaly инициализирована", "Anomaly")