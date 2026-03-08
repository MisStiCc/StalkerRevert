extends BaseArtifact

func _ready_hook():
	artifact_name = "Common Artifact"
	artifact_value = 5.0
	energy_reward = 2.0
	color = Color(0.7, 0.7, 0.7)

func _collect_hook(collector: Node):
	print("Common Artifact собран! Даёт +", energy_reward, " энергии")