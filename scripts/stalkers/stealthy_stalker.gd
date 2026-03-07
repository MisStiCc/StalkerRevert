extends BaseStalker
class_name StealthyStalker

## Stealthy - избегает любых контактов

func _ready_hook():
	stalker_type = "stealthy"
	behavior = "stealthy"
	priority_stealth = true
	
	if has_node("Label3D"):
		$Label3D.modulate = Color.DARK_GRAY
		$Label3D.text = "Stealthy"
	
	print("👻 StealthyStalker: инициализирован")


func _evaluate_situation():
	# Избегает любых контактов
	if danger_zones.size() > 0 or known_mutants.size() > 0:
		current_state = StalkerState.FLEE
		if monolith:
			target_position = (global_position - monolith.global_position).normalized() * 50
	else:
		super._evaluate_situation()
