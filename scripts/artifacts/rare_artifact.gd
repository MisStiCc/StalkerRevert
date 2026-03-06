extends BaseArtifact

func _ready_hook():
	artifact_name = "Rare Artifact"
	artifact_value = 15.0
	energy_reward = 8.0
	color = Color(0.9, 0.6, 0.2)

func _collect_hook(collector: Node):
	print("Rare Artifact собран! Даёт +", energy_reward, " энергии")
	
	# Временный бафф
	if collector.has_method("temporary_speed_boost"):
		collector.temporary_speed_boost(1.5, 5.0)

func _spawn_collect_effect():
	# Золотые частицы
	var particles = preload("res://scenes/effects/gold_particles.tscn").instantiate()
	particles.position = global_position
	get_parent().add_child(particles)