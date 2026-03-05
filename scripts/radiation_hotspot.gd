PS> Remove-Item -Force "scripts/zone_controller.gd"extends BaseAnomaly
class_name RadiationHotspot

## Радиоактивный очаг - повышенная радиация
## Наносит урон с течением времени

@export var radiation_level: float = 75.0  # Уровень радиации в mR/h (>50)
@export var radiation_damage: float = 8.0  # Урон от радиации в секунду
@export var hotspot_radius: float = 10.0  # Радиус 8-12 м (среднее 10)
@export var glow_intensity: float = 1.5  # Интенсивность свечения

var geiger_counter_timer: float = 0.0

func _ready():
	anomaly_name = "Радиоактивный очаг"
	damage_per_second = radiation_damage
	color = Color(0.3, 0.8, 0.3, 0.6)  # Зеленоватое свечение
	radius = hotspot_radius
	
	super._ready()
	_update_visuals()

func _apply_damage():
	"""Наносит радиационный урон сталкерам"""
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			# Наносим урон здоровью
			if stalker.has_method("take_damage"):
				stalker.take_damage(radiation_damage)
				energy_consumed.emit(radiation_damage)
			
			# Наносим урон от радиации (если есть отдельный метод)
			if stalker.has_method("take_radiation_damage"):
				stalker.take_radiation_damage(radiation_level)

func _process(delta):
	"""Обновление эффектов радиации"""
	if not is_active:
		return
	
	# Эффект счётчика Гейгера
	_geiger_counter_effect(delta)
	
	# Пульсация свечения
	_update_glow_effect(delta)

func _update_visuals():
	"""Создаёт визуальный эффект радиоактивного очага"""
	# Создаём коллайдер
	var collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = hotspot_radius
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Создаём ядро радиации - яркий центр
	var core_visual = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = hotspot_radius * 0.3
	sphere.height = sphere.radius * 2
	core_visual.mesh = sphere
	
	# Настраиваем материал для ядра
	var core_material = StandardMaterial3D.new()
	core_material.albedo_color = Color(0.5, 1, 0.5, 0.9)
	core_material.emission = Color(0.3, 0.8, 0.3)
	core_material.emission_energy = 3.0
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_visual.material_override = core_material
	
	add_child(core_visual)
	
	# Создаём внешние слои радиации
	for i in range(3):
		var visual = MeshInstance3D.new()
		var layer_mesh = SphereMesh.new()
		var layer_radius = hotspot_radius * (0.5 + i * 0.25)
		layer_mesh.radius = layer_radius
		layer_mesh.height = layer_radius * 2
		visual.mesh = layer_mesh
		
		# Настраиваем материал для слоя радиации
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.3, 0.8, 0.3, 0.4 - i * 0.1)
		material.emission = Color(0.2, 0.6, 0.2)
		material.emission_energy = 1.0 - i * 0.3
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.flags_unshaded = true
		visual.material_override = material
		
		add_child(visual)
	
	# Добавляем свет для зеленоватого свечения
	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = glow_intensity
	light.distance = hotspot_radius * 2
	light.shadow_enabled = true
	add_child(light)
	
	# Создаём частицы радиации
	_create_radiation_particles()

func _create_radiation_particles():
	"""Создаёт частицы для эффекта радиации"""
	var particles = GPUParticles3D.new()
	var material = ParticleProcessMaterial.new()
	
	# Настраиваем материал частиц
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = hotspot_radius
	material.color = Color(0.4, 0.9, 0.4, 0.3)
	material.direction = Vector3(0, 1, 0)
	material.spread = 0.8
	material.gravity = Vector3(0, 2, 0)  # Поднимаются вверх
	material.tangential_accel = 0.5
	material.linear_accel = 0.0
	material.scale_min = 0.1
	material.scale_max = 0.2
	material.damping = 0.5
	
	particles.process_material = material
	particles.amount = 60
	particles.lifetime = 4.0
	particles.explosiveness = 0.05
	particles.emitting = true
	particles.one_shot = false
	particles.visible = true
	
	add_child(particles)

func _geiger_counter_effect(delta: float):
	"""Эффект счётчика Гейгера - щелчки"""
	geiger_counter_timer += delta
	
	# Чем больше сталкеров в зоне, тем чаще щелчки
	var click_interval = 1.0 / (1.0 + stalkers_in_zone.size() * 0.5)
	
	if geiger_counter_timer >= click_interval:
		geiger_counter_timer = 0.0
		# Здесь можно добавить звук щелчка счётчика Гейгера
		# _play_geiger_sound()

func _update_glow_effect(delta: float):
	"""Обновляет эффект пульсации свечения"""
	var time = Time.get_ticks_msec() * 0.001
	
	# Пульсация света
	var light = get_node_or_null("OmniLight3D")
	if light:
		light.light_energy = glow_intensity + 0.3 * sin(time * 1.5)
