extends BaseAnomaly
class_name Teleport

## Телепорт - перемещает сталкеров в другую точку
## Может быть безопасным или ловушкой

@export_enum("Safe", "Trap") var teleport_type: String = "Safe"
@export var destination: Marker3D  # Точка назначения
@export var teleport_radius: float = 3.5  # Радиус 3-4 м (среднее 3.5)
@export var cooldown_time: float = 5.0  # Время между телепортациями
@export var trap_damage: float = 25.0  # Урон если это ловушка
@export var is_bidirectional: bool = false  # Двусторонний телепорт

var is_on_cooldown: bool = false
var cooldown_timer: float = 0.0
var teleported_stalkers: Array[Node3D] = []

func _ready():
	anomaly_name = "Телепорт"
	damage_per_second = 0.0  # Не наносит урон напрямую
	color = Color(0.4, 0.2, 0.8, 0.7)  # Сине-фиолетовый портал
	radius = teleport_radius
	
	super._ready()
	_update_visuals()

func _on_body_entered(body: Node3D):
	"""Когда сталкер входит в зону телепорта"""
	if body.has_method("take_damage") and not body in stalkers_in_zone:
		stalkers_in_zone.append(body)
		stalker_entered.emit(body)
		
		# Телепортируем сталкера
		if not is_on_cooldown and body not in teleported_stalkers:
			_teleport_stalker(body)

func _on_body_exited(body: Node3D):
	"""Когда сталкер выходит из зоны"""
	if body in stalkers_in_zone:
		stalkers_in_zone.erase(body)
		stalker_exited.emit(body)
		
		# Убираем из списка телепортированных
		if body in teleported_stalkers:
			teleported_stalkers.erase(body)

func _apply_damage():
	"""Телепорт не наносит урон напрямую"""
	pass

func _process(delta):
	"""Обновление эффектов и кулдауна"""
	if not is_active:
		return
	
	# Обновляем кулдаун
	if is_on_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			is_on_cooldown = false
	
	# Анимация портала
	_update_portal_animation(delta)

func _teleport_stalker(stalker: Node3D):
	"""Телепортирует сталкера в точку назначения"""
	if not destination:
		push_warning("Телепорт не имеет точки назначения!")
		return
	
	# Запускаем кулдаун
	is_on_cooldown = true
	cooldown_timer = cooldown_time
	
	# Эффект перед телепортацией
	_create_teleport_effect(stalker.global_position, true)
	
	# Телепортируем сталкера
	var original_position = stalker.global_position
	stalker.global_position = destination.global_position
	
	# Эффект после телепортации
	_create_teleport_effect(destination.global_position, false)
	
	# Если это ловушка - наносим урон
	if teleport_type == "Trap":
		if stalker.has_method("take_damage"):
			stalker.take_damage(trap_damage)
			energy_consumed.emit(trap_damage)
		
		# Эффект повреждения
		_create_damage_effect(stalker.global_position)
	
	# Добавляем в список телепортированных
	teleported_stalkers.append(stalker)
	
	# Если двусторонний - создаём обратный телепорт
	if is_bidirectional:
		_setup_return_teleport(original_position)

func _update_visuals():
	"""Создаёт визуальный эффект телепорта"""
	# Создаём коллайдер
	var collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = teleport_radius
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Создаём воронку портала
	for i in range(4):
		var visual = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = teleport_radius * (0.3 + i * 0.15)
		torus.outer_radius = teleport_radius * (0.4 + i * 0.15)
		visual.mesh = torus
		
		# Настраиваем материал для портала
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.4, 0.2, 0.8, 0.6 - i * 0.1)
		material.emission = Color(0.5, 0.3, 0.9)
		material.emission_energy = 2.0 - i * 0.3
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.flags_unshaded = true
		visual.material_override = material
		
		# Вращение
		visual.rotation.x = PI / 2
		
		add_child(visual)
	
	# Создаём центр портала
	var center = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = teleport_radius * 0.2
	sphere.height = sphere.radius * 2
	center.mesh = sphere
	
	var center_material = StandardMaterial3D.new()
	center_material.albedo_color = Color(0.6, 0.4, 1.0, 0.9)
	center_material.emission = Color(0.5, 0.3, 0.9)
	center_material.emission_energy = 3.0
	center_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	center.material_override = center_material
	
	add_child(center)
	
	# Добавляем свет портала
	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.distance = teleport_radius * 3
	light.shadow_enabled = false
	add_child(light)
	
	# Создаём частицы портала
	_create_portal_particles()

func _create_portal_particles():
	"""Создаёт частицы для эффекта портала"""
	var particles = GPUParticles3D.new()
	var material = ParticleProcessMaterial.new()
	
	# Настраиваем материал частиц
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = teleport_radius * 0.8
	material.color = Color(0.5, 0.3, 0.9, 0.6)
	material.direction = Vector3(0, 1, 0)
	material.spread = 0.5
	material.gravity = Vector3(0, 0, 0)  # Зависают
	material.tangential_accel = 3.0  # Вращение
	material.linear_accel = 0.0
	material.scale_min = 0.1
	material.scale_max = 0.2
	material.damping = 0.0
	
	particles.process_material = material
	particles.amount = 50
	particles.lifetime = 3.0
	particles.explosiveness = 0.0
	particles.emitting = true
	particles.one_shot = false
	particles.visible = true
	
	add_child(particles)

func _create_teleport_effect(position: Vector3, is_departure: bool):
	"""Создаёт эффект телепортации"""
	var particles = GPUParticles3D.new()
	var material = ParticleProcessMaterial.new()
	
	# Настраиваем материал
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 1.0
	material.color = Color(0.6, 0.4, 1.0, 0.8)
	material.direction = Vector3(0, 1, 0) if is_departure else Vector3(0, -1, 0)
	material.spread = 1.0
	material.gravity = Vector3(0, 0, 0)
	material.tangential_accel = 5.0
	material.linear_accel = 10.0 if is_departure else -10.0
	material.scale_min = 0.2
	material.scale_max = 0.3
	material.damping = 0.5
	
	particles.process_material = material
	particles.amount = 30
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.one_shot = true
	particles.visible = true
	particles.global_position = position
	
	get_tree().current_scene.add_child(particles)
	
	# Удаляем после завершения
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func _create_damage_effect(position: Vector3):
	"""Создаёт эффект повреждения от ловушки"""
	var particles = GPUParticles3D.new()
	var material = ParticleProcessMaterial.new()
	
	# Настраиваем материал
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 1.0
	material.color = Color(1, 0.3, 0.3, 0.9)  # Красный
	material.direction = Vector3(0, 1, 0)
	material.spread = 1.0
	material.gravity = Vector3(0, -5, 0)
	material.tangential_accel = 2.0
	material.linear_accel = 5.0
	material.scale_min = 0.1
	material.scale_max = 0.2
	material.damping = 1.0
	
	particles.process_material = material
	particles.amount = 20
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.one_shot = true
	particles.visible = true
	particles.global_position = position
	
	get_tree().current_scene.add_child(particles)
	
	# Удаляем после завершения
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func _update_portal_animation(delta: float):
	"""Обновляет анимацию портала"""
	var time = Time.get_ticks_msec() * 0.001
	
	# Вращение колец портала
	for i in range(4):
		var ring = get_child(i + 2)  # Пропускаем коллайдер и свет
		if ring and ring is MeshInstance3D:
			ring.rotation.z += delta * (2.0 + i * 0.5) * (1 if i % 2 == 0 else -1)
	
	# Пульсация света
	var light = get_node_or_null("OmniLight3D")
	if light:
		light.light_energy = 1.5 + 0.5 * sin(time * 3.0)

func _setup_return_teleport(original_position: Vector3):
	"""Настраивает обратный телепорт для двусторонней связи"""
	# Создаём маркер для обратного телепорта
	var return_marker = Marker3D.new()
	return_marker.global_position = original_position
	return_marker.name = "ReturnMarker"
	
	# Добавляем в сцену
	get_tree().current_scene.add_child(return_marker)
	
	# Здесь можно создать обратный телепорт
	# Для простоты просто сохраняем позицию
