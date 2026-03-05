extends BaseAnomaly

## Кисель - кислотные испарения
## Высокий урон, разъедает броню

@export var acid_damage: float = 15.0  # Высокий урон кислотой в секунду
@export var armor_damage: float = 3.0  # Урон броне в секунду
@export var acid_color: Color = Color(0.8, 1, 0.2, 0.4)  # Желто-зелёный
@export var acid_radius: float = 6.0  # Радиус 6 метров

func _ready():
	anomaly_name = "Кисель"
	damage_per_second = acid_damage
	color = acid_color
	radius = acid_radius
	
	super._ready()
	_update_visuals()

func _apply_damage():
	"""Наносит урон кислотой и разъедает броню"""
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			# Наносим урон здоровью
			if stalker.has_method("take_damage"):
				stalker.take_damage(acid_damage)
				energy_consumed.emit(acid_damage)
			
			# Наносим урон броне
			if stalker.has_method("take_armor_damage"):
				stalker.take_armor_damage(armor_damage)
				energy_consumed.emit(armor_damage)

func _update_visuals():
	"""Обновление визуального представления - кислотные испарения"""
	_create_acid_cloud_visuals()

func _create_acid_cloud_visuals():
	"""Создаёт визуальный эффект кислотных испарений"""
	# Создаём коллайдер
	var collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = acid_radius
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Создаём ядро кислоты - яркий центр
	var core_visual = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = acid_radius * 0.5
	sphere.height = sphere.radius * 2
	core_visual.mesh = sphere
	
	# Настраиваем материал для ядра
	var core_material = StandardMaterial3D.new()
	core_material.albedo_color = Color(1, 1, 0, 0.8)
	core_material.emission = acid_color
	core_material.emission_energy = 3.0
	core_material.transparency = 0.6
	core_material.flags_unshaded = true
	core_visual.material_override = core_material
	
	# Добавляем эффект пульсации ядра
	var core_tween = create_tween()
	core_tween.set_parallel(true)
	core_tween.tween_property(core_visual, "scale", Vector3(1.2, 1.2, 1.2), 0.3)
	core_tween.tween_property(core_visual, "scale", Vector3(1.0, 1.0, 1.0), 0.3)
	core_tween.tween_property(core_visual, "scale", Vector3(1.15, 1.15, 1.15), 0.15)
	core_tween.tween_property(core_visual, "scale", Vector3(1.0, 1.0, 1.0), 0.15)
	
	add_child(core_visual)
	
	# Создаём внешние слои кислоты
	for i in range(4):
		var visual = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = acid_radius * (0.7 + i * 0.15)
		sphere.height = sphere.radius * 2
		visual.mesh = sphere
		
		# Настраиваем материал для кислотного слоя
		var material = StandardMaterial3D.new()
		material.albedo_color = acid_color
		material.transparency = 0.3 - i * 0.05  # Чем выше слой, тем прозрачнее
		material.flags_unshaded = true
		material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		visual.material_override = material
		
		# Добавляем эффект пульсации и вращения
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual, "scale", Vector3(1.1, 1.1, 1.1), 0.4 + i * 0.2)
		tween.tween_property(visual, "scale", Vector3(1.0, 1.0, 1.0), 0.4 + i * 0.2)
		tween.tween_property(visual, "scale", Vector3(1.05, 1.05, 1.05), 0.2 + i * 0.1)
		tween.tween_property(visual, "scale", Vector3(1.0, 1.0, 1.0), 0.2 + i * 0.1)
		
		# Добавляем быстрое вращение
		tween.tween_property(visual, "rotation_y", PI * 0.8, 2.0 + i)
		tween.tween_property(visual, "rotation_y", 0.0, 2.0 + i)
		
		add_child(visual)
	
	# Создаём частицы кислоты
	_create_acid_particles()
	
	# Добавляем свет для кислотного свечения
	var light = OmniLight3D.new()
	light.light_color = acid_color
	light.light_energy = 1.5
	light.distance = acid_radius * 2
	light.shadow_enabled = true
	add_child(light)

func _create_acid_particles():
	"""Создаёт частицы кислоты с эффектом разъедания"""
	var particles = GPUParticles3D.new()
	var material = ParticleProcessMaterial.new()
	
	# Настраиваем материал частиц
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = acid_radius
	material.color = acid_color
	material.direction = Vector3(0, 1, 0)
	material.spread = 1.5
	material.gravity = Vector3(0, -8, 0)
	material.tangential_accel = 0.0
	material.linear_accel = 0.0
	material.scale_min = 0.3
	material.scale_max = 0.3
	
	particles.process_material = material
	particles.amount = 150
	particles.lifetime = 2.5
	particles.explosiveness = 0.2
	particles.emitting = true
	particles.one_shot = false
	particles.visible = true
	
	add_child(particles)
