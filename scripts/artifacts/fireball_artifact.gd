extends BaseArtifact

func _ready_hook():
	artifact_name = "Fireball"
	artifact_value = 15.0
	energy_reward = 10.0
	color = Color(1, 0.3, 0)

func _collect_hook(collector: Node):
	print("Fireball собран! Даёт +", energy_reward, " энергии")
	
	# Поджигает сталкера
	if collector.has_method("apply_burn"):
		collector.apply_burn(3.0)

func _spawn_collect_effect():
	# Создаём огненные частицы
	var particles = preload("res://scenes/effects/fire_particles.tscn").instantiate()
	particles.position = global_position
	get_parent().add_child(particles)

func apply_effect(collector: Node):
	super.apply_effect(collector)
	# Дополнительный урон огнём
	if collector.has_method("take_damage"):
		collector.take_damage(5, "fire")