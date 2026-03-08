extends BaseStalker

## Brave - всегда идёт к монолиту, не боится аномалий

func _ready_hook():
	stalker_type = "brave"
	behavior = "brave"
	
	var label_node = find_child("*Label3D", true, false)
	if label_node and label_node is Label3D:
		label_node.modulate = Color.RED
		label_node.text = "Brave"
	
	print("⚔️ BraveStalker: инициализирован")


func _evaluate_situation():
	# Brave всегда предпочитает идти к монолиту
	if monolith:
		current_state = StalkerState.SEEK_MONOLITH
		target_position = monolith.global_position
	else:
		# Вызываем родительский метод
		_evaluate_situation_legacy()


func _evaluate_situation_legacy():
	# Базовая логика из parent
	var anomalies = get_tree().get_nodes_in_group("anomalies")
	var nearest_danger = null
	var min_dist = 10.0
	
	for a in anomalies:
		if is_instance_valid(a):
			var dist = global_position.distance_to(a.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_danger = a
	
	if nearest_danger:
		current_state = StalkerState.SEEK_MONOLITH
		if monolith:
			target_position = monolith.global_position
