# entities/stalkers/master_stalker.gd
extends BaseStalker
class_name MasterStalker

func _ready_hook():
	stalker_type = GameEnums.StalkerType.MASTER
	behavior_type = GameEnums.StalkerBehavior.AGGRESSIVE
	
	# Параметры
	max_health = 250.0
	move_speed = 6.0
	damage = 25.0
	vision_range = 30.0
	
	# Визуал
	if visuals:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.8, 0.2, 0.8)
		material.metallic = 0.8
		material.roughness = 0.1
		material.emission_enabled = true
		material.emission = Color(0.8, 0.2, 0.8)
		visuals.material_override = material
	
	print("MasterStalker инициализирован")


func _physics_hook(delta):
	# Мастера активно ищут цели
	if current_state == GameEnums.StalkerState.PATROL and randf() < 0.05:
		# Активно сканируем местность
		var mutants = get_tree().get_nodes_in_group("mutants")
		for mutant in mutants:
			if is_instance_valid(mutant):
				var dist = global_position.distance_to(mutant.global_position)
				if dist < vision_range * 1.5:
					print("Мастер заметил мутанта издалека!")
					current_target = mutant
					current_state = GameEnums.StalkerState.ATTACK_MUTANT
					break