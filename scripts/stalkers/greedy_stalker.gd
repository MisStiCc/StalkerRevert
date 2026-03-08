extends BaseStalker

## Greedy - приоритет на сбор артефактов

func _ready_hook():
	stalker_type = "greedy"
	behavior = "greedy"
	
	var label_node = find_child("*Label3D", true, false)
	if label_node and label_node is Label3D:
		label_node.modulate = Color.YELLOW
		label_node.text = "Greedy"
	
	print("🎯 GreedyStalker: инициализирован")
