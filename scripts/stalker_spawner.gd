extends Node3D
class_name StalkerSpawner

signal wave_started(wave_number)
signal wave_ended(wave_number, stalkers_spawned)
signal stalker_spawned(stalker)

@export var spawn_interval: float = 30.0
@export var min_stalkers_per_wave: int = 3
@export var max_stalkers_per_wave: int = 6
@export var spawn_radius: float = 500.0
@export var spawn_height: float = 0.0  # Высота появления (обычно 0 - земля)
@export var stalker_types: Array[PackedScene] = []

var current_wave: int = 0
var is_spawning: bool = false
var active_stalkers: Array[Node] = []

var _wave_timer: Timer
var _zone_controller: Node = null


func _ready():
	# Ищем ZoneController
	_zone_controller = get_tree().get_first_node_in_group("zone_controller")
	
	# Настройка таймера
	_wave_timer = Timer.new()
	_wave_timer.wait_time = spawn_interval
	_wave_timer.timeout.connect(_start_wave)
	_wave_timer.one_shot = false
	add_child(_wave_timer)
	_wave_timer.start()
	
	# Проверка наличия типов сталкеров
	if stalker_types.is_empty():
		push_warning("StalkerSpawner: No stalker types assigned! Добавьте сцены сталкеров в инспекторе.")


func _start_wave():
	if is_spawning:
		return
	
	is_spawning = true
	current_wave += 1
	wave_started.emit(current_wave)
	
	var stalkers_to_spawn = randi_range(min_stalkers_per_wave, max_stalkers_per_wave)
	var spawned_count = 0
	
	for i in range(stalkers_to_spawn):
		_spawn_stalker()
		spawned_count += 1
		await get_tree().create_timer(0.5).timeout
	
	is_spawning = false
	wave_ended.emit(current_wave, spawned_count)


func _spawn_stalker():
	if stalker_types.is_empty():
		push_error("StalkerSpawner: No stalker types assigned!")
		return
	
	# Выбираем случайный тип сталкера
	var stalker_scene = stalker_types[randi() % stalker_types.size()]
	var stalker = stalker_scene.instantiate()
	
	# Генерируем позицию по кругу
	var angle = randf() * 2 * PI
	var pos = Vector3(
		cos(angle) * spawn_radius + randf_range(-50, 50),
		spawn_height + randf_range(-2, 2),  # Небольшая вариация высоты
		sin(angle) * spawn_radius + randf_range(-50, 50)
	)
	stalker.position = pos
	
	# Подключаем сигнал смерти
	if stalker.has_signal("stalker_died"):
		stalker.stalker_died.connect(_on_stalker_died.bind(stalker))
	
	# Добавляем сталкера в сцену (на уровень выше спавнера)
	get_parent().add_child(stalker)
	active_stalkers.append(stalker)
	stalker_spawned.emit(stalker)


func _on_stalker_died(stalker: Node):
	if stalker in active_stalkers:
		active_stalkers.erase(stalker)
	
	# Добавляем биомассу в ZoneController
	if _zone_controller and _zone_controller.has_method("add_biomass"):
		var biomass_value = 10
		
		# Проверяем, есть ли у сталкера метод получения ценности
		if stalker and stalker.has_method("get_biomass_value"):
			biomass_value = stalker.get_biomass_value()
		else:
			# Определяем ценность по имени сталкера
			if stalker and stalker.has_method("get_stalker_name"):
				match stalker.get_stalker_name():
					"Novice":
						biomass_value = 8
					"Veteran":
						biomass_value = 15
					_:
						biomass_value = 10
			elif stalker and stalker.has_method("get_type"):
				match stalker.get_type():
					"novice":
						biomass_value = 8
					"veteran":
						biomass_value = 15
					_:
						biomass_value = 10
		
		_zone_controller.add_biomass(biomass_value)


func set_spawn_interval(new_interval: float):
	spawn_interval = new_interval
	if _wave_timer:
		_wave_timer.wait_time = spawn_interval


func start_spawning():
	if _wave_timer and _wave_timer.is_stopped():
		_wave_timer.start()


func stop_spawning():
	if _wave_timer and not _wave_timer.is_stopped():
		_wave_timer.stop()


func clear_all_stalkers():
	for stalker in active_stalkers:
		if is_instance_valid(stalker):
			stalker.queue_free()
	active_stalkers.clear()


# Получение количества активных сталкеров
func get_active_stalker_count() -> int:
	return active_stalkers.size()


# Получение текущей волны
func get_current_wave() -> int:
	return current_wave


# Принудительный запуск волны (для тестов)
func force_wave():
	if not is_spawning:
		_start_wave()
