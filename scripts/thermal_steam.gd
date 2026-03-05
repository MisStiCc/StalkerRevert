extends BaseAnomaly
class_name ThermalSteam

# Параметры аномалии Пар
@export var steam_particles: GPUParticles3D
@export var steam_radius: float = 7.0
@export var steam_height: float = 4.0

func _ready():
	super._ready()
	anomaly_name = "Пар"
	damage_per_second = 15.0  # Усиленный урон по сравнению с Жаркой
	color = Color(1, 1, 0.6, 0.8)  # Бело-жёлтый цвет
	radius = steam_radius

	# Настройка частиц пара
	if steam_particles:
		steam_particles.process_material.emission_sphere_radius = steam_radius
		steam_particles.process_material.color = Color(1, 1, 0.8, 0.5)

	# Создаём облако пара
	_create_steam_cloud()

func _create_steam_cloud():
	# Создаём частицы пара
	var particles = GPUParticles3D.new()
	particles.name = "SteamCloud"
	particles.process_material = ParticleProcessMaterial.new()
	particles.process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particles.process_material.emission_sphere_radius = steam_radius
	particles.process_material.color = Color(1, 1, 0.8, 0.5)
	particles.process_material.color_initial = Color(1, 1, 0.8, 0.5)
	particles.process_material.color_scale = 1.0
	particles.process_material.gravity = Vector3(0, -2, 0)
	particles.process_material.lifetime = 3.0
	particles.process_material.amount = 500
	particles.process_material.amount_curve = Curve.new()
	particles.process_material.amount_curve.add_point(0, 1.0)
	particles.process_material.amount_curve.add_point(1, 0.0)
	particles.process_material.speed = 2.0
	particles.process_material.scale_min = 2.0
	particles.process_material.scale_max = 5.0
	particles.process_material.scale_curve = Curve.new()
	particles.process_material.scale_curve.add_point(0, 1.0)
	particles.process_material.scale_curve.add_point(1, 0.0)
	particles.process_material.tangential_accel = 1.0
	particles.process_material.radial_accel = 1.0
	particles.amount = 500
	particles.one_shot = false
	particles.lifetime = 3.0
	particles.autorestart = true
	particles.restart_on_restart = true
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_INITIAL_ANGLE, PI)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_SPREAD, 1.0)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_EMISSION_RATE, 200.0)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_LINEAR_VELOCITY, 1.0)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_ANGULAR_VELOCITY, 2.0)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_TANGENTIAL_VELOCITY, 1.0)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_DAMPING, 0.5)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_SIZE, 2.0)

	add_child(particles)
	steam_particles = particles

func _apply_damage():
	if not is_active:
		return

	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(damage_per_second)
				energy_consumed.emit(damage_per_second)

	# Анимация пара
	if steam_particles:
		steam_particles.restart()

func deactivate():
	if steam_particles:
		steam_particles.emitting = false
		await get_tree().create_timer(1.0).timeout
		steam_particles.queue_free()
	super.deactivate()

func activate():
	super.activate()
	if steam_particles:
		steam_particles.emitting = true
