extends BaseAnomaly
class_name ThermalComet

# Параметры аномалии Комета
@export var comet_speed: float = 3.0
@export var comet_path: Path3D
@export var tail_length: float = 5.0
@export var tail_segments: int = 10
@export var is_indoor_only: bool = true
@export var orbit_radius: float = 3.5

# Маршрут движения
var current_path_index: int = 0
var is_moving: bool = true

# Хвост кометы
var tail_segments_array: Array[Node3D] = []

func _ready():
	super._ready()
	anomaly_name = "Комета"
	damage_per_second = 20.0  # Высокий урон
	color = Color(1, 0.3, 0, 0.9)  # Оранжево-красный цвет
	radius = orbit_radius

	# Создаём хвост кометы
	_create_comet_tail()

	# Если нет пути, создаём орбиту
	if not comet_path:
		_create_orbit_path()

	# Проверяем, что аномалия в закрытом пространстве
	if is_indoor_only and not _is_in_closed_space():
		deactivate()
		is_moving = false
		return

	# Настраиваем частицы хвоста
	_setup_tail_particles()

func _create_orbit_path():
	# Создаём виртуальный путь для орбиты
	var path = Path3D.new()
	path.name = "OrbitPath"
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3(0, 0, 0))
	path.curve.add_point(Vector3(orbit_radius, 0, 0))
	path.curve.add_point(Vector3(0, 0, orbit_radius))
	path.curve.add_point(Vector3(-orbit_radius, 0, 0))
	path.curve.add_point(Vector3(0, 0, -orbit_radius))
	path.curve.add_point(Vector3(orbit_radius, 0, 0))

	add_child(path)
	comet_path = path

func _create_comet_tail():
	# Создаём сегменты хвоста
	for i in range(tail_segments):
		var segment = MeshInstance3D.new()
		segment.name = "TailSegment_%d" % i
		segment.visible = false

		var mesh = SphereMesh.new()
		mesh.radius = orbit_radius * 0.3 * (1.0 - float(i) / tail_segments)
		mesh.height = orbit_radius * 0.3 * (1.0 - float(i) / tail_segments)

		var material = StandardMaterial3D.new()
		material.emission_enabled = true
		material.emission = Color(1, 0.3, 0, 0.8)
		material.albedo_color = Color(1, 0.3, 0, 0.8)

		segment.mesh = mesh
		segment.material_override = material

		add_child(segment)
		tail_segments_array.append(segment)

func _setup_tail_particles():
	# Создаём частицы для хвоста
	var particles = GPUParticles3D.new()
	particles.name = "TailParticles"
	particles.process_material = ParticleProcessMaterial.new()
	particles.process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particles.process_material.emission_sphere_radius = orbit_radius * 0.5
	particles.process_material.color = Color(1, 0.3, 0, 0.6)
	particles.process_material.color_initial = Color(1, 0.3, 0, 0.8)
	particles.process_material.color_scale = 1.0
	particles.process_material.gravity = Vector3(0, 0, 0)
	particles.process_material.lifetime = 2.0
	particles.process_material.amount = 300
	particles.process_material.amount_curve = Curve.new()
	particles.process_material.amount_curve.add_point(0, 1.0)
	particles.process_material.amount_curve.add_point(1, 0.0)
	particles.process_material.speed = 1.0
	particles.process_material.scale_min = 1.0
	particles.process_material.scale_max = 3.0
	particles.process_material.scale_curve = Curve.new()
	particles.process_material.scale_curve.add_point(0, 1.0)
	particles.process_material.scale_curve.add_point(1, 0.0)
	particles.process_material.tangential_accel = 0.5
	particles.process_material.radial_accel = 0.5
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_INITIAL_ANGLE, PI)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_SPREAD, 0.5)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_EMISSION_RATE, 150.0)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_LINEAR_VELOCITY, 0.5)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_ANGULAR_VELOCITY, 1.0)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_TANGENTIAL_VELOCITY, 0.5)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_DAMPING, 0.3)
	particles.process_material.set_param(ParticleProcessMaterial.PARAM_SIZE, 1.5)

	particles.amount = 300
	particles.one_shot = false
	particles.lifetime = 2.0
	particles.autorestart = true
	particles.restart_on_restart = true

	add_child(particles)

func _process(delta):
	if not is_active or not is_moving:
		return

	# Движение по маршруту
	if comet_path and comet_path.curve.get_point_count() > 1:
		var target_point = comet_path.curve.get_point_position(current_path_index)
		var direction = (target_point - position).normalized()
		var distance_to_target = position.distance_to(target_point)

		if distance_to_target < 0.5:
			current_path_index = (current_path_index + 1) % comet_path.curve.get_point_count()
		else:
			position += direction * comet_speed * delta

	# Обновление хвоста
	_update_tail()

func _update_tail():
	# Обновляем положение сегментов хвоста
	var direction = Vector3.ZERO
	if comet_path and comet_path.curve.get_point_count() > 1:
		var next_point = comet_path.curve.get_point_position((current_path_index + 1) % comet_path.curve.get_point_count())
		direction = (next_point - position).normalized()

	for i in range(tail_segments_array.size()):
		var segment = tail_segments_array[i]
		var t = float(i) / tail_segments_array.size()
		var offset = direction * tail_length * t * 0.5
		segment.global_position = global_position + offset
		segment.scale = Vector3.ONE * (1.0 - t * 0.5)

func _apply_damage():
	if not is_active or not is_moving:
		return

	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(damage_per_second)
				energy_consumed.emit(damage_per_second)

	# Эффект хвоста
	if tail_segments_array.size() > 0:
		for segment in tail_segments_array:
			segment.visible = true

func deactivate():
	if tail_segments_array.size() > 0:
		for segment in tail_segments_array:
			segment.visible = false
	super.deactivate()

func activate():
	super.activate()
	is_moving = true
	if tail_segments_array.size() > 0:
		for segment in tail_segments_array:
			segment.visible = true
