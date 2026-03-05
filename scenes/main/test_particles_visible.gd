extends Node3D

func _ready():
	# Создаём тестовые частицы прямо перед камерой
	var particles = GPUParticles3D.new()
	particles.amount = 100
	particles.lifetime = 5.0
	particles.one_shot = false
	particles.emitting = true
	particles.position = Vector3(0, 0, -5)  # Прямо перед камерой
	
	var material = ParticleProcessMaterial.new()
	material.color = Color(0, 1, 0, 1)  # Ярко-зелёный
	material.scale_min = 2.0
	material.scale_max = 3.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 2.0
	material.spread = 360.0
	
	particles.process_material = material
	add_child(particles)
	
	print("=== ТЕСТОВЫЕ ЧАСТИЦЫ СОЗДАНЫ ПРЯМО ПЕРЕД КАМЕРОЙ ===")
	print("Позиция: ", particles.position)
	print("Цвет: зелёный")
