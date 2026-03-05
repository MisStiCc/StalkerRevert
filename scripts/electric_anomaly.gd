extends BaseAnomaly
class_name ElectricAnomaly

@export var stun_chance: float = 0.3
@export var stun_duration: float = 1.5

func _ready():
	super._ready()
	anomaly_name = "Электра"
	damage_per_second = 15.0
	color = Color(0.2, 0.6, 1.0)


func _apply_damage():
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(damage_per_second)
				
				# Шанс оглушения
				if randf() < stun_chance and stalker.has_method("stun"):
					stalker.stun(stun_duration)
				
				energy_consumed.emit(damage_per_second)