extends BaseAnomaly
class_name HeatAnomaly

func _ready():
	super._ready()
	anomaly_name = "Жарка"
	damage_per_second = 10.0
	color = Color(1, 0.5, 0)