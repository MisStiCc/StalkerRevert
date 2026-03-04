extends BaseAnomaly
class_name AcidAnomaly

@export var armor_damage: float = 2.0  # дополнительный урон по броне

func _ready():
	super._ready()
	anomaly_name = "Кислота"
	damage_per_second = 8.0
	color = Color(0.2, 0.8, 0.2)


func _apply_damage():
	if not active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(damage_per_second)
				
				# Дополнительный урон по броне
				if stalker.has_method("damage_armor"):
					stalker.damage_armor(armor_damage)
				
				energy_consumed.emit(damage_per_second)