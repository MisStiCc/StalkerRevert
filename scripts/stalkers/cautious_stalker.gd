extends BaseStalker

## Cautious - проверяет безопасность пути

func _ready_hook():
	stalker_type = "cautious"
	behavior = "cautious"
	
	var label_node = find_child("*Label3D", true, false)
	if label_node and label_node is Label3D:
		label_node.modulate = Color.CYAN
		label_node.text = "Cautious"
	
	print("🛡️ CautiousStalker: инициализирован")


func _evaluate_situation():
	# Проверяет безопасность пути к монолиту
	if monolith and navigation:
		# Используем компонент навигации
		var nav_agent_node = self.get_node_or_null("NavigationAgent3D")
		
		if nav_agent_node:
			var path = nav_agent_node.get_nav_path()
			
			if _is_path_safe(path):
				current_state = StalkerState.SEEK_MONOLITH
				target_position = monolith.global_position
			else:
				# Ищет обходной путь
				current_state = StalkerState.FLEE
				target_position = _get_safe_direction() * 20
		else:
			current_state = StalkerState.SEEK_MONOLITH
			if monolith:
				target_position = monolith.global_position
	else:
		current_state = StalkerState.SEEK_MONOLITH
		if monolith:
			target_position = monolith.global_position


func _get_safe_direction() -> Vector3:
	# Находит направление без аномалий
	var anomalies = get_tree().get_nodes_in_group("anomalies")
	var best_dir = Vector3.FORWARD
	var best_score = -INF
	
	for angle in range(0, 360, 30):
		var dir = Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle)))
		var score = 0.0
		
		for a in anomalies:
			if is_instance_valid(a):
				var dist = global_position.distance_to(a.global_position)
				if dist < 30.0:
					# Чем дальше от аномалии, тем лучше
					score += dist
		
		if score > best_score:
			best_score = score
			best_dir = dir
	
	return best_dir


func _is_path_safe(path: PackedVector3Array) -> bool:
	# Проверяет, нет ли аномалий на пути
	if path.is_empty():
		return false
		
	var anomalies = get_tree().get_nodes_in_group("anomalies")
		
	for point in path:
		for a in anomalies:
			if is_instance_valid(a) and point.distance_to(a.global_position) < 10.0:
				return false
	return true
