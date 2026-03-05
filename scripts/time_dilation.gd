extends BaseAnomaly
class_name TimeDilation

## Машина времени - замедляет время внутри аномалии
## Сталкеры двигаются медленнее

@export var time_slow_factor: float = 0.3  # Коэффициент замедления (0.3 = 30% скорости)
@export var dilation_radius: float = 6.5  # Радиус 5-8 м (среднее 6.5)
@export var visual_intensity: float = 1.0  # Интенсивность визуального эффекта

var affected_stalkers: Dictionary = {}  # Сталкеры под эффектом замедления

func _ready():
	anomaly_name = "Машина времени"
	damage_per_second = 0.0  # Не наносит урон напрямую
	color = Color(0.7, 0.7, 0.8, 0.5)  # Серебристо-серый с мерцанием
	radius = dilation_radius
	
	super._ready()
	_update_visuals()

func _on_body_entered(body: Node3D):
	"""Когда сталкер входит в зону замедления"""
	if body.has_method("take_damage") and not body in stalkers_in_zone:
		stalkers_in_zone.append(body)
		stalker_entered.emit(body)
		
		# Применяем замедление времени
		if body.has_method("set_time_scale"):
			body.set_time_scale(time_slow_factor)
			affected_stalkers[body] = true
		elif body.has_method("slow_down"):
			body.slow_down(time_slow_factor, 999.0)  # Длительное замедление
			affected_stalkers[body] = true

func _on_body_exited(body: Node3D):
	"""Когда сталкер выходит из зоны замедления"""
	if body in stalkers_in_zone:
		stalkers_in_zone.erase(body)
		stalker_exited.emit(body)
		
		# Восстанавливаем нормальное время
		if body.has_method("set_time_scale"):
			body.set_time_scale(1.0)
			affected_stalkers.erase(body)
		elif body.has_method("slow_down"):
			body.slow_down(1.0, 0.0)  # Восстанавливаем скорость
			affected_stalkers.erase(body)

func _apply_damage():
	"""Машина времени не наносит урон"""
	pass

func _process(delta):
	"""Обновление визуальных эффектов мерцания"""
	if not is_active:
		return
	
	# Эффект мерцания
	_update_shimmer_effect(delta)

func _update_visuals():
	"""Создаёт визуальный эффект замедления времени"""
	# Создаём коллайдер
	var collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = dilation_radius
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Создаём несколько слоёв для эффекта мерцания
	for i in range(4):
		var visual = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = dilation_radius * (1.0 - i * 0.15)
		sphere.height = sphere.radius * 2
		visual.mesh = sphere
		
		# Настраиваем материал для мерцающего эффекта
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.7, 0.7, 0.8, 0.3 - i * 0.05)
		material.emission = Color(0.6, 0.6, 0.7, 0.5)
		material.emission_energy = 1.0 - i * 0.2
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.flags_unshaded = true
		visual.material_override = material
		
		add_child(visual)
	
	# Добавляем свет для эффекта мерцания
	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.8
	light.distance = dilation_radius * 2
	light.shadow_enabled = false
	add_child(light)
	
	# Создаём частицы для эффекта временных искажений
	_create_time_particles()

func _create_time_particles():
	"""Создаёт частицы для эффекта временных искажений"""
	var particles = GPUParticles3D.new()
	var material = ParticleProcessMaterial.new()
	
	# Настраиваем материал частиц
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = dilation_radius * 0.8
	material.color = Color(0.8, 0.8, 0.9, 0.4)
	material.direction = Vector3(0, 1, 0)
	material.spread = 0.5
	material.gravity = Vector3(0, 0, 0)  # Частицы "зависают"
	material.tangential_accel = 1.0
	material.linear_accel = 0.0
	material.scale_min = 0.2
	material.scale_max = 0.4
	material.damping = 2.0  # Сильное затухание для эффекта замедления
	
	particles.process_material = material
	particles.amount = 80
	particles.lifetime = 5.0
	particles.explosiveness = 0.1
	particles.emitting = true
	particles.one_shot = false
	particles.visible = true
	
	add_child(particles)

func _update_shimmer_effect(delta: float):
	"""Обновляет эффект мерцания"""
	var time = Time.get_ticks_msec() * 0.001
	
	# Мерцание света
	var light = get_node_or_null("OmniLight3D")
	if light:
		light.light_energy = 0.5 + 0.3 * sin(time * 2.0)
