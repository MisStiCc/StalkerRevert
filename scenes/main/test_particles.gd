extends Node3D

func _ready():
	print("=== ТЕСТ ЧАСТИЦ ===")
	
	# Создаём тестовые частицы
	var particles = GPUParticles3D.new()
	particles.amount = 100
	particles.lifetime = 2.0
	particles.one_shot = false
	particles.emitting = true
	particles.position = Vector3(0, 2, 0)
	
	# Материал
	var material = ParticleProcessMaterial.new()
	material.color = Color(1, 0, 0, 1)
	material.scale_min = 0.5
	material.scale_max = 1.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 2.0
	material.spread = 180.0
	
	particles.process_material = material
	add_child(particles)
	
	print("Тестовые частицы созданы")
	print("Видимы? ", particles.visible)
	print("Emitting: ", particles.emitting)
	
	# Проверяем, есть ли они в дереве
	print("Родитель: ", particles.get_parent())
	print("В дереве? ", particles.is_inside_tree())
