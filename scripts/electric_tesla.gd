extends BaseAnomaly
class_name ElectricTesla

# Параметры аномалии
@export var path: Path3D
@export var move_speed: float = 2.0
@export var lightning_interval: float = 0.5
@export var lightning_damage: float = 20.0
@export var spark_count: int = 5
@export var spark_distance: float = 3.0
@export var spark_color: Color = Color(0.8, 0.9, 1.0, 0.8)

# Внутренние переменные
var path_follow: PathFollow3D
var lightning_timer: Timer
var sparks: Array[Node3D] = []
var is_moving: bool = true
var current_position: Vector3

# Сигналы
signal lightning_strike(stalker: Node3D)

func _ready():
	super._ready()
	
	# Настройка параметров аномалии
	anomaly_name = "Тесла"
	damage_per_second = 30.0
	radius = 5.0
	color = Color(0.0, 0.8, 1.0, 0.6)
	
	# Создание PathFollow3D для движения по маршруту
	path_follow = PathFollow3D.new()
	add_child(path_follow)
	path_follow.progress = 0.0
	
	# Таймер для генерации молний
	lightning_timer = Timer.new()
	lightning_timer.wait_time = lightning_interval
	lightning_timer.timeout.connect(_generate_lightning)
	add_child(lightning_timer)
	lightning_timer.start()
	
	# Создание визуальных эффектов
	_create_sparks()
	_update_visuals()

func _process(delta):
	if is_active and is_moving and path:
		# Движение по маршруту
		path_follow.progress += move_speed * delta
		current_position = path_follow.global_position
		
		# Обновление визуальных эффектов
		_update_sparks()

func _generate_lightning():
	if not is_active or not path_follow or path_follow.progress_ratio < 0.0 or path_follow.progress_ratio > 1.0:
		return
	
	# Проверка сталкеров в зоне
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			# Генерация молнии
			_create_lightning(stalker.global_position)
			
			# Нанесение урона
			if stalker.has_method("take_damage"):
				stalker.take_damage(lightning_damage)
				energy_consumed.emit(lightning_damage)
			
			# Эффект оглушения
			if stalker.has_method("stun"):
				stalker.stun(1.0)
			
			# Звуковой эффект
			_play_lightning_sound()
			
			lightning_strike.emit(stalker)
			break  # Только одна молния за интервал

func _create_lightning(target_position: Vector3):
	# Создание визуального эффекта молнии через ImmediateMesh
	var lightning_mesh = ImmediateMesh.new()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = lightning_mesh
	
	var material = StandardMaterial3D.new()
	material.emission = Color(0.0, 0.9, 1.0)
	material.emission_energy = 5.0
	mesh_instance.material_override = material
	
	get_tree().current_scene.add_child(mesh_instance)
	
	# Рисуем линию молнии
	lightning_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	lightning_mesh.surface_add_vertex(current_position)
	lightning_mesh.surface_add_vertex(target_position)
	lightning_mesh.surface_end()
	
	# Удаление молнии через короткое время
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()

func _create_sparks():
	# Создание частиц искр
	for i in range(spark_count):
		var spark = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.1
		sphere.height = 0.1
		spark.mesh = sphere
		spark.material_override = StandardMaterial3D.new()
		spark.material_override.emission = spark_color
		spark.material_override.emission_energy = 2.0
		spark.material_override.transmission = spark_color
		spark.material_override.transmission_energy = 0.5
		
		add_child(spark)
		sparks.append(spark)

func _update_sparks():
	# Обновление позиций искр вокруг аномалии
	var time = Time.get_ticks_msec() * 0.001
	for i in range(sparks.size()):
		var spark = sparks[i]
		var angle = time * (2.0 * PI / spark_count) + i * (2.0 * PI / spark_count)
		var radius = radius * (0.5 + 0.5 * sin(time * 3.0 + i))
		var height = sin(time * 2.0 + i) * radius * 0.5
		
		spark.global_position = current_position + Vector3(
			cos(angle) * radius,
			height,
			sin(angle) * radius
		)

func _update_visuals():
	# Обновление визуального представления аномалии
	if path_follow:
		current_position = path_follow.global_position

func _play_lightning_sound():
	# Воспроизведение звука удара током
	# Здесь можно добавить загрузку и воспроизведение аудио
	# Для примера просто лог
	print("⚡ Электрический разряд!")

func deactivate():
	is_moving = false
	super.deactivate()

func activate():
	is_moving = true
	super.activate()

func set_path(new_path: Path3D):
	path = new_path
	if path_follow:
		path_follow.path = new_path
