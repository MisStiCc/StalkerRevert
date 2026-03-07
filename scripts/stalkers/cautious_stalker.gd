extends BaseStalker
class_name CautiousStalker

## Cautious - проверяет безопасность пути

func _ready_hook():
	stalker_type = "cautious"
	behavior = "cautious"
	priority_safety = true
	
	if has_node("Label3D"):
		$Label3D.modulate = Color.CYAN
		$Label3D.text = "Cautious"
	
	print("🛡️ CautiousStalker: инициализирован")


func _evaluate_situation():
	# Проверяет безопасность пути к монолиту
	if monolith and navigation_agent:
		var path = NavigationServer3D.map_get_path(
			get_world_3d().navigation_map,
			global_position,
			monolith.global_position,
			true
		)
		
		if _is_path_safe(path):
			current_state = StalkerState.SEEK_MONOLITH
			target_position = monolith.global_position
		else:
			# Ищет обходной путь
			super._evaluate_situation()
	else:
		super._evaluate_situation()


func _is_path_safe(path: PackedVector3Array) -> bool:
	# Проверяет, нет ли аномалий на пути
	if path.is_empty():
		return false
		
	for point in path:
		for a in danger_zones:
			if is_instance_valid(a) and point.distance_to(a.global_position) < 10.0:
				return false
	return true
