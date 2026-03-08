extends BaseStalker

## Aggressive - атакует мутантов в первую очередь

func _ready_hook():
	stalker_type = "aggressive"
	behavior = "aggressive"
	
	var label_node = find_child("*Label3D", true, false)
	if label_node and label_node is Label3D:
		label_node.modulate = Color.ORANGE
		label_node.text = "Aggressive"
	
	print("⚔️ AggressiveStalker: инициализирован")


func _evaluate_situation():
	# Сначала ищет, кого убить (мутантов)
	var mutants = get_tree().get_nodes_in_group("mutants")
	var nearest_mutant = null
	var min_dist = vision_range
	
	for m in mutants:
		if is_instance_valid(m):
			var dist = global_position.distance_to(m.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_mutant = m
	
	if nearest_mutant:
		current_state = StalkerState.ATTACK_MUTANT
		target_position = nearest_mutant.global_position
	elif monolith:
		current_state = StalkerState.SEEK_MONOLITH
		target_position = monolith.global_position
