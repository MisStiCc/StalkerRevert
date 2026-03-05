extends BaseAnomaly
class_name BioBurningFluff

## Жгучий пух - аномальная растительность
## При контакте выбрасывает ядовитые частицы

@export var poison_damage: float = 12.0  # Урон от яда
@export var fluff_radius: float = 4.0  # Радиус 3-5 м (среднее 4)
@export var particle_burst_count: int = 10  # Количество частиц при контакте
@export var particle_damage: float = 5.0  # Урон от частиц

var is_triggered: bool = false
var particle_cooldown: float = 0.0

func _ready():
	anomaly_name = "Жгучий пух"
	damage_per_second = poison_damage
	color = Color(0.5, 0.4, 0.3, 0.8)  # Серо-бурый с искрами
	radius = fluff_radius
	
	super._ready()
	_update_visuals()

func _on_body_entered(body: Node3D):
	"""Когда сталкер входит в зону"""
	if body.has_method("take_damage") and not body in stalkers_in_zone:
		stalkers_in_zone.append(body)
		stalker_entered.emit(body)
		
		# Активируем выброс частиц
		if not is_triggered:
			_trigger_particle_burst(body)

func _apply_damage():
	"""Наносит урон ядом сталкерам"""
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(poison_damage)
				energy_consumed.emit(poison_damage)

func _process(delta):
	"""Обновление эффектов"""
	if not is_active:
		return
	
	# Проверяем кулдаун частиц
	if particle_cooldown > 0:
		particle_cooldown -= delta
	else:
		is_triggered = false

func _update_visuals():
	"""Создаёт визуальный эффект жгучего пуха"""
	# Создаём коллайдер
	var collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = fluff_radius
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Создаём основу пуха - несколько сфер для объёма
	for i in range(5):
		var visual = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = fluff_radius * 0.3 * (1.0 - i * 0.1)
		sphere.height = sphere.radius * 2
		visual.mesh = sphere
		
		# Настраиваем материал для пуха
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.5, 0.4, 0.3, 0.6 - i * 0.1)
		material.emission = Color(0.3, 0.2, 0.1)
		material.emission_energy = 0.5
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		visual.material_override = material
		
		# Случайное смещение для объёма
		visual.position = Vector3(
			randf_range(-fluff_radius * 0.3, fluff_radius * 0.3),
			randf_range(-fluff_radius * 0.2, fluff_radius * 0.2),
			randf_range(-fluff_radius * 0.3, fluff_radius * 0.3)
		)
		
		add_child(visual)
	
	# Добавляем искры
	_create_spark_particles()
	
	# Добавляем слабый свет
	var light = OmniLight3D.new()
	light.light_color = Color(0.6, 0.5, 0.3, 0.5)
	light.light_energy = 0.5
	light.distance = fluff_radius * 2
	light.shadow_enabled = false
	add_child(light)

func _create_spark_particles():
	"""Создаёт частицы искр"""
	var particles = GPUParticles3D.new()
	var material = ParticleProcessMaterial.new()
	
	# Настраиваем материал частиц
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = fluff_radius * 0.5
	material.color = Color(1, 0.8, 0.3, 0.8)  # Искры
	material.direction = Vector3(0, 1, 0)
	material.spread = 1.0
	material.gravity = Vector3(0, -3, 0)
	material.tangential_accel = 1.0
	material.linear_accel = 2.0
	material.scale_min = 0.05
	material.scale_max = 0.1
	material.damping = 1.0
	
	particles.process_material = material
	particles.amount = 30
	particles.lifetime = 2.0
	particles.explosiveness = 0.0
	particles.emitting = true
	particles.one_shot = false
	particles.visible = true
	
	add_child(particles)

func _trigger_particle_burst(triggered_by: Node3D):
	"""Запускает взрыв ядовитых частиц"""
	is_triggered = true
	particle_cooldown = 2.0  # Кулдаун 2 секунды
	
	# Создаём взрыв частиц
	var burst_particles = GPUParticles3D.new()
	var material = ParticleProcessMaterial.new()
	
	# Настраиваем материал для взрыва
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = fluff_radius
	material.color = Color(0.6, 0.9, 0.3, 0.9)  # Ядовитые частицы
	material.direction = Vector3(0, 1, 0)
	material.spread = 1.0
	material.gravity = Vector3(0, -5, 0)
	material.tangential_accel = 2.0
	material.linear_accel = 5.0
	material.scale_min = 0.1
	material.scale_max = 0.2
	material.damping = 2.0
	
	burst_particles.process_material = material
	burst_particles.amount = particle_burst_count
	burst_particles.lifetime = 1.0
	burst_particles.explosiveness = 1.0  # Взрыв
	burst_particles.emitting = true
	burst_particles.one_shot = true
	burst_particles.visible = true
	
	add_child(burst_particles)
	
	# Наносим урон от частиц
	if triggered_by.has_method("take_damage"):
		triggered_by.take_damage(particle_damage)
		energy_consumed.emit(particle_damage)
	
	# Удаляем частицы после завершения
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(burst_particles):
		burst_particles.queue_free()
