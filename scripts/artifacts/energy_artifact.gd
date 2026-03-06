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
	# Электрические частицы
	var particles = preload("res://scenes/effects/spark_particles.tscn").instantiate()
	particles.position = global_position
	get_parent().add_child(particles)