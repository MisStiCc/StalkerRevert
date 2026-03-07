extends BaseStalker
class_name AggressiveStalker

## Aggressive - атакует мутантов в первую очередь

func _ready_hook():
	stalker_type = "aggressive"
	behavior = "aggressive"
	priority_combat = true
	
	if has_node("Label3D"):
		$Label3D.modulate = Color.ORANGE
		$Label3D.text = "Aggressive"
	
	print("⚔️ AggressiveStalker: инициализирован")


func _evaluate_situation():
	# Сначала ищет, кого убить
	var nearest_mutant = _get_nearest_mutant_in_range(vision_range)
	if nearest_mutant:
		current_state = StalkerState.ATTACK_MUTANT
		target_position = nearest_mutant.global_position
	else:
		super._evaluate_situation()
