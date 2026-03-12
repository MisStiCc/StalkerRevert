# entities/stalkers/veteran_stalker.gd
extends BaseStalker
class_name VeteranStalker

func _ready_hook():
	stalker_type = GameEnums.StalkerType.VETERAN
	behavior_type = GameEnums.StalkerBehavior.BRAVE
	
	# Параметры
	max_health = 150.0
	move_speed = 5.5
	damage = 15.0
	vision_range = 25.0
	
	# Визуал
	if visuals:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.4, 1.0)
		material.metallic = 0.7
		material.roughness = 0.2
		visuals.material_override = material
	
	print("VeteranStalker инициализирован")


func _physics_hook(delta):
	# Ветераны уверенно идут к цели
	if current_state == GameEnums.StalkerState.SEEK_MONOLITH and is_instance_valid(monolith):
		var dist = global_position.distance_to(monolith.global_position)
		if dist < 10.0:
			print("Ветеран приближается к монолиту!")