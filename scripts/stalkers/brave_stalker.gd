extends BaseStalker
class_name BraveStalker

## Brave - всегда идёт к монолиту, не боится аномалий

func _ready_hook():
	stalker_type = "brave"
	behavior = "brave"
	priority_monolith = true
	
	if has_node("Label3D"):
		$Label3D.modulate = Color.RED
		$Label3D.text = "Brave"
	
	print("⚔️ BraveStalker: инициализирован")


func _evaluate_situation():
	# Brave всегда предпочитает идти к монолиту
	if monolith:
		current_state = StalkerState.SEEK_MONOLITH
		target_position = monolith.global_position
	else:
		super._evaluate_situation()
