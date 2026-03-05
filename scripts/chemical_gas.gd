extends BaseAnomaly

## Газировка - ядовитое облако
## Наносит урон с течением времени

@export var poison_damage: float = 5.0  # Урон от яда в секунду
@export var cloud_color: Color = Color(0.5, 1, 0.5, 0.3)  # Зеленоватый туман
@export var cloud_radius: float = 9.0  # Радиус 9 метров

func _ready():
	anomaly_name = "Газировка"
	damage_per_second = poison_damage
	color = cloud_color
	radius = cloud_radius
	
	super._ready()
	_update_visuals()

func _apply_damage():
	"""Наносит урон ядом с течением времени"""
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(poison_damage)
				energy_consumed.emit(poison_damage)

func _update_visuals():
	"""Обновление визуального представления - ядовитое облако"""
	_create_gas_cloud_visuals()

func _create_gas_cloud_visuals():
	"""Создаёт визуальный эффект ядовитого облака"""
	# Создаём коллайдер
	var collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = cloud_radius
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Создаём несколько слоёв облака для эффекта тумана
	for i in range(3):
		var visual = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		var layer_radius = cloud_radius * (1.0 - i * 0.2)
		sphere.radius = layer_radius
		sphere.height = layer_radius * 2
		visual.mesh = sphere
		
		# Настраиваем материал для туманного эффекта
		var material = StandardMaterial3D.new()
		material.albedo_color = cloud_color
		material.transparency = 0.4 - i * 0.1  # Чем выше слой, тем прозрачнее
		material.flags_unshaded = true
		visual.material_override = material
		
		# Добавляем эффект пульсации
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual, "scale", Vector3(1.1, 1.1, 1.1), 0.5 + i * 0.2)
		tween.tween_property(visual, "scale", Vector3(1.0, 1.0, 1.0), 0.5 + i * 0.2)
		tween.tween_property(visual, "scale", Vector3(1.05, 1.05, 1.05), 0.25 + i * 0.1)
		tween.tween_property(visual, "scale", Vector3(1.0, 1.0, 1.0), 0.25 + i * 0.1)
		
		# Добавляем медленное вращение
		tween.tween_property(visual, "rotation_y", PI * 0.5, 3.0 + i)
		tween.tween_property(visual, "rotation_y", 0.0, 3.0 + i)
		
		add_child(visual)
	
	# Добавляем несколько частиц для эффекта яда
	_create_particles()
	
	# Добавляем свет для атмосферы
	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 0.8, 0.3, 0.3)
	light.light_energy = 0.5
	light.distance = cloud_radius * 2
	light.visible = true
	add_child(light)

func _create_particles():
	"""Создаёт частицы для эффекта яда"""
	var particles = GPUParticles3D.new()
	var material = ParticleProcessMaterial.new()
	
	# Настраиваем материал частиц
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = cloud_radius
	material.color = cloud_color
	material.direction = Vector3(0, 1, 0)
	material.spread = 1.0
	material.gravity = Vector3(0, -5, 0)
	material.tangential_accel = 0.0
	material.linear_accel = 0.0
	material.scale_min = 0.5
	material.scale_max = 0.5
	
	particles.process_material = material
	particles.amount = 100
	particles.lifetime = 3.0
	particles.explosiveness = 0.1
	particles.emitting = true
	particles.one_shot = false
	particles.visible = true
	
	add_child(particles)
