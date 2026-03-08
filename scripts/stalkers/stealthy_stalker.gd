extends BaseStalker

## Stealthy - избегает любых контактов

func _ready_hook():
	stalker_type = "stealthy"
	behavior = "stealthy"
	
	var label_node = find_child("*Label3D", true, false)
	if label_node and label_node is Label3D:
		label_node.modulate = Color.DARK_GRAY
		label_node.text = "Stealthy"
	
	print("👻 StealthyStalker: инициализирован")


func _evaluate_situation():
	# Избегает любых контактов - аномалий и мутантов
	var anomalies = get_tree().get_nodes_in_group("anomalies")
	var mutants = get_tree().get_nodes_in_group("mutants")
	
	var has_danger = false
	for a in anomalies:
		if is_instance_valid(a) and global_position.distance_to(a.global_position) < 15.0:
			has_danger = true
			break
	
	if not has_danger:
		for m in mutants:
			if is_instance_valid(m) and global_position.distance_to(m.global_position) < 20.0:
				has_danger = true
				break
	
	if has_danger:
		current_state = StalkerState.FLEE
		if monolith:
			# Бежит от монолита
			target_position = (global_position - monolith.global_position).normalized() * 50
		else:
			# Бежит в случайном направлении
			target_position = global_position + Vector3(randf_range(-1,1), 0, randf_range(-1,1)).normalized() * 30
	elif monolith:
		current_state = StalkerState.SEEK_MONOLITH
		target_position = monolith.global_position
