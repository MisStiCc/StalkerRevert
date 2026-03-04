extends Node
class_name ZoneController

## Контроллер Зоны - главный элемент управления защитой территории
## Управляет ресурсами, создает аномалии и мутантов, контролирует выбросы

# Сигналы
signal energy_changed(energy: float)
signal biomass_changed(biomass: float)
signal anomaly_created(anomaly: Node3D)
signal mutant_spawned(mutant: Node3D)
signal emission_started
signal emission_ended
signal territory_expanded(new_radius: float)
signal artifact_generated(artifact_position: Vector3)
signal stalker_entered_zone(stalker: Node3D)
signal stalker_left_zone(stalker: Node3D)
signal stalker_died(stalker: Node3D)
signal energy_depleted

# Параметры (можно менять в инспекторе)
@export var max_energy: float = 1000.0
@export var energy_regen_rate: float = 5.0  # в секунду
@export var starting_energy: float = 500.0
@export var starting_biomass: float = 0.0

# Текущие значения
var energy: float
var biomass: float
var is_emission_active: bool = false
var anomalies: Array[Node3D] = []
var mutants: Array[Node3D] = []
var artifacts: Array[Node3D] = []  # Изменено с Dictionary на Node3D
var stalkers: Array[Node3D] = []
var territory_radius: float = 100.0

@export var stalker_spawner: Node = null

# Внутренние переменные
var _regen_timer: Timer


func _ready():
	energy = starting_energy
	biomass = starting_biomass
	
	# Добавляем себя в группу для поиска
	add_to_group("zone_controller")
	
	# Создаем и настраиваем таймер регенерации энергии
	_regen_timer = Timer.new()
	_regen_timer.wait_time = 1.0
	_regen_timer.timeout.connect(_on_regen_timer)
	add_child(_regen_timer)
	_regen_timer.start()
	
	# Ищем спавнер, если не назначен
	if not stalker_spawner:
		stalker_spawner = get_node_or_null("../StalkerSpawner")
		if not stalker_spawner:
			stalker_spawner = find_child("StalkerSpawner", true, false)
	
	if stalker_spawner:
		start_stalker_spawning()
	
	# Испускаем начальные сигналы
	energy_changed.emit(energy)
	biomass_changed.emit(biomass)


func _on_regen_timer():
	# Регенерируем энергию
	var old_energy = energy
	energy = min(energy + energy_regen_rate, max_energy)
	
	if old_energy != energy:
		energy_changed.emit(energy)


func add_biomass(amount: float):
	biomass += amount
	biomass_changed.emit(biomass)


func spend_energy(amount: float) -> bool:
	if energy >= amount:
		energy -= amount
		energy_changed.emit(energy)
		if energy <= 0:
			energy_depleted.emit()
		return true
	return false


func spend_biomass(amount: float) -> bool:
	if biomass >= amount:
		biomass -= amount
		biomass_changed.emit(biomass)
		return true
	return false


func can_afford(energy_cost: float, biomass_cost: float) -> bool:
	return energy >= energy_cost and biomass >= biomass_cost


# Для обратной совместимости
func is_afford(energy_cost: float, biomass_cost: float) -> bool:
	return can_afford(energy_cost, biomass_cost)


func spawn_anomaly(anomaly_type: String, position: Vector3) -> Node3D:
	"""Создание аномалии - возвращает объект аномалии или null"""
	var cost = get_anomaly_cost(anomaly_type)
	if not spend_energy(cost):
		print("Недостаточно энергии для создания аномалии ", anomaly_type)
		return null
	
	# Маппинг типов к именам файлов
	var type_map = {
		"fire": "heat",
		"heat": "heat",
		"electric": "electric",
		"acid": "acid"
	}
	
	var file_type = type_map.get(anomaly_type, anomaly_type)
	var scene_path = "res://scenes/zone/anomalies/" + file_type + "_anomaly.tscn"
	
	if not ResourceLoader.exists(scene_path):
		push_error("Сцена аномалии не найдена: ", scene_path)
		return null
	
	var scene = load(scene_path)
	if scene:
		var anomaly = scene.instantiate()
		anomaly.position = position
		get_parent().add_child(anomaly)  # Добавляем на уровень выше (в Main)
		anomalies.append(anomaly)
		
		print("Аномалия ", anomaly_type, " создана на позиции ", position)
		anomaly_created.emit(anomaly)
		return anomaly
	return null


# Для обратной совместимости
func create_anomaly(type: String, position: Vector3) -> Node3D:
	return spawn_anomaly(type, position)


func spawn_mutant(mutant_type: String, position: Vector3) -> Node3D:
	var cost = get_mutant_cost(mutant_type)
	if not spend_biomass(cost):
		print("Недостаточно биомассы для призыва мутанта ", mutant_type)
		return null
	
	var scene_path = "res://scenes/zone/mutants/" + mutant_type + "_mutant.tscn"
	
	if not ResourceLoader.exists(scene_path):
		push_error("Сцена мутанта не найдена: ", scene_path)
		return null
	
	var scene = load(scene_path)
	if scene:
		var mutant = scene.instantiate()
		mutant.position = position
		get_parent().add_child(mutant)
		mutants.append(mutant)
		
		if mutant.has_signal("died"):
			mutant.died.connect(_on_mutant_died.bind(mutant))
		
		print("Мутант ", mutant_type, " призван на позиции ", position)
		mutant_spawned.emit(mutant)
		return mutant
	return null


func _on_mutant_died(mutant: Node3D):
	if mutant in mutants:
		mutants.erase(mutant)


func start_emission(duration: float = 10.0):
	if is_emission_active:
		return
	is_emission_active = true
	emission_started.emit()
	
	# Создаем таймер для автоматического окончания выброса
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_emission_end)
	add_child(timer)
	timer.start()
	
	# Наносим урон всем сталкерам в зоне
	_apply_emission_damage()


func _apply_emission_damage():
	for stalker in stalkers:
		if is_instance_valid(stalker) and stalker.has_method("take_damage"):
			stalker.take_damage(50.0)


func _on_emission_end():
	is_emission_active = false
	emission_ended.emit()


func expand_territory(radius_increase: float):
	territory_radius += radius_increase
	territory_expanded.emit(territory_radius)
	print("Территория расширена. Новый радиус: ", territory_radius)


func generate_artifact(position: Vector3, type: String = "common", value: int = 10) -> Node3D:
	"""Создание артефакта как Node3D, а не Dictionary"""
	var scene_path = "res://scenes/zone/artifacts/" + type + "_artifact.tscn"
	
	if not ResourceLoader.exists(scene_path):
		push_error("Сцена артефакта не найдена: ", scene_path)
		return null
	
	var scene = load(scene_path)
	if scene:
		var artifact = scene.instantiate()
		artifact.position = position
		get_parent().add_child(artifact)
		artifacts.append(artifact)
		artifact_generated.emit(position)
		print("Артефакт ", type, " создан на позиции ", position)
		return artifact
	
	# Fallback на Dictionary для совместимости
	var dict_artifact = {
		"position": position,
		"type": type,
		"value": value
	}
	artifacts.append(dict_artifact)  # Но это вызовет ошибку типов!
	artifact_generated.emit(position)
	print("Артефакт (словарь) создан на позиции ", position)
	return null


func update_stalker_status(stalker: Node3D):
	if not is_instance_valid(stalker):
		return
		
	var stalker_in_zone = is_stalker_in_zone(stalker)
	
	if stalker_in_zone and not stalkers.has(stalker):
		stalkers.append(stalker)
		stalker_entered_zone.emit(stalker)
	elif not stalker_in_zone and stalkers.has(stalker):
		stalkers.erase(stalker)
		stalker_left_zone.emit(stalker)


func get_resource_efficiency() -> float:
	var total_resources = energy + biomass
	var max_possible = max_energy + starting_biomass
	if max_possible > 0:
		return total_resources / max_possible
	return 0.0


func get_energy() -> float:
	return energy


func get_biomass() -> float:
	return biomass


func get_anomaly_cost(type: String) -> float:
	match type:
		"fire", "heat":
			return 50.0
		"electric":
			return 75.0
		"acid":
			return 100.0
		"gravitational":
			return 150.0
		_:
			return 50.0


func get_mutant_cost(type: String) -> float:
	match type:
		"dog":
			return 50.0
		"snork":
			return 100.0
		"controller":
			return 200.0
		_:
			return 50.0


func is_stalker_in_zone(stalker: Node3D) -> bool:
	if not is_instance_valid(stalker):
		return false
	# Проверяем расстояние от центра территории
	return stalker.global_position.distance_to(Vector3.ZERO) <= territory_radius


func start_stalker_spawning():
	if stalker_spawner and stalker_spawner.has_method("start_spawning"):
		stalker_spawner.start_spawning()


func stop_stalker_spawning():
	if stalker_spawner and stalker_spawner.has_method("stop_spawning"):
		stalker_spawner.stop_spawning()


func clear_all_stalkers():
	if stalker_spawner and stalker_spawner.has_method("clear_all_stalkers"):
		stalker_spawner.clear_all_stalkers()