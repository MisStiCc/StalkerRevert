extends BaseArtifact

func _ready_hook():
	artifact_name = "Energy Core"
	artifact_value = 25.0
	energy_reward = 20.0
	color = Color(0.2, 0.8, 1.0)

func _collect_hook(collector: Node):
	print("Energy Core собран! Даёт +", energy_reward, " энергии")
	
	# Восстанавливает здоровье
	if collector.has_method("heal"):
		collector.heal(10)

func _spawn_collect_effect():
	# Эффект собран без частиц (папка effects не существует)
	pass