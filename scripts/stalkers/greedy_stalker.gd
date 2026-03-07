extends BaseStalker
class_name GreedyStalker

## Greedy - приоритет на сбор артефактов

func _ready_hook():
	stalker_type = "greedy"
	behavior = "greedy"
	priority_artifact = true
	
	if has_node("Label3D"):
		$Label3D.modulate = Color.YELLOW
		$Label3D.text = "Greedy"
	
	print("🎯 GreedyStalker: инициализирован")
