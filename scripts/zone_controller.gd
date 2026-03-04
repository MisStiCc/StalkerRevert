extends Node

## Контроллер Зоны - главный элемент управления защитой территории
## Управляет ресурсами, создает аномалии и мутантов, контролирует выбросы

# Сигналы
signal resources_changed(energy: float, biomass: float)
signal anomaly_created(anomaly)
signal mutant_spawned(mutant)
signal emission_started
signal emission_ended
signal territory_expanded(new_radius: float)
signal artifact_generated(artifact)
signal stalker_entered_zone(stalker)
signal stalker_left_zone(stalker)
signal stalker_died(stalker)
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
var emission_cooldown: float = 0.0
var emission_duration: float = 0.0
var anomalies: Array = []
var mutants: Array = []
var artifacts: Array = []
var stalkers: Array = []
var territory_radius: float = 100.0
@export var emission_damage: float = 50.0

@export var stalker_spawner: Node
@onready var main_ui = get_node("/root/MainScene/MainUI")

# Внутренние переменные
var _regen_timer: Timer

# Инициализация контроллера зоны
func _ready():
	if main_ui:
		self.resources_changed.connect(main_ui.update_resources)
	else:
		print("Ошибка: main_ui не найден или не инициализирован в ZoneController.")
	energy = starting_energy
	biomass = starting_biomass
	
	# Создаем и настраиваем таймер регенерации энергии
	_regen_timer = Timer.new()
	_regen_timer.wait_time = 1.0
	_regen_timer.timeout.connect(_on_regen_timer)
	add_child(_regen_timer)
	_regen_timer.start()

	if not stalker_spawner:
		stalker_spawner = find_child("StalkerSpawner")
	
	if stalker_spawner:
		start_stalker_spawning()

func _process(delta: float):
	# Уменьшение времени до следующего выброса
	if emission_cooldown > 0:
		emission_cooldown -= delta
	
	# Обновление длительности выброса
	if emission_duration > 0:
		emission_duration -= delta
		if emission_duration <= 0:
			_on_emission_end()
		else:
			# Наносим урон сталкерам во время выброса
			for stalker in stalkers:
				if stalker != null and is_instance_valid(stalker):
					stalker.take_damage(emission_damage * delta)

func _on_regen_timer():
	# Регенерируем энергию
	var old_energy = energy
	energy = min(energy + energy_regen_rate, max_energy)
	
	if old_energy != energy:
		emit_signal("resources_changed", energy, biomass)

func add_biomass(amount: float):
	biomass += amount
	emit_signal("resources_changed", energy, biomass)

func spend_energy(amount: float) -> bool:
	if energy >= amount:
		energy -= amount
		emit_signal("resources_changed", energy, biomass)
		if energy <= 0:
			energy_depleted.emit()
		return true
	return false

func spend_biomass(amount: float) -> bool:
	if biomass >= amount:
		biomass -= amount
		emit_signal("resources_changed", energy, biomass)
		return true
	return false

func is_afford(energy_cost: float, biomass_cost: float) -> bool:
	return energy >= energy_cost and biomass >= biomass_cost

func create_anomaly(type: String, position: Vector2) -> Node:
	"""Создание аномалии - возвращает объект аномалии или null"""
	var cost = get_anomaly_cost(type)
	if not spend_energy(cost):
		print("Недостаточно энергии для создания аномалии ", type)
		return null

	var scene_path = "res://scenes/zone/anomalies/" + type + "_anomaly.tscn"
	var scene = load(scene_path)
	if scene:
		var anomaly = scene.instantiate()
		anomaly.position = position
		add_child(anomaly)
		anomalies.append(anomaly)
		
		print("Аномалия ", type, " создана на позиции ", position)
		emit_signal("anomaly_created", anomaly)
		return anomaly
	return null

func spawn_mutant(mutant_type: String, position: Vector2) -> Node:
	var cost = get_mutant_cost(mutant_type)
	if not spend_biomass(cost):
		print("Недостаточно биомассы для призыва мутанта ", mutant_type)
		return null

	var scene_path = "res://scenes/zone/mutants/" + mutant_type + "_mutant.tscn"
	var scene = load(scene_path)
	if scene:
		var mutant = scene.instantiate()
		mutant.position = position
		add_child(mutant)
		mutants.append(mutant)
		
		mutant.died.connect(_on_mutant_died)
		
		print("Мутант ", mutant_type, " призван на позиции ", position)
		emit_signal("mutant_spawned", mutant)
		return mutant
	return null

func _on_mutant_died(mutant):
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

func _on_emission_end():
    is_emission_active = false
    emission_ended.emit()

func expand_territory(radius_increase: float):
	territory_radius += radius_increase
	emit_signal("territory_expanded", territory_radius)
	print("Территория расширена. Новый радиус: ", territory_radius)

func generate_artifact(position: Vector2):
	var scene_path = "res://scenes/artifacts/base_artifact.tscn"
	var scene = load(scene_path)
	if scene:
		var artifact = scene.instantiate()
		artifact.global_position = position
		add_child(artifact)
		artifacts.append(artifact)
		
		emit_signal("artifact_generated", artifact)
		print("Артефакт создан на позиции ", position)
		return artifact
	else:
		print("Ошибка: Не удалось загрузить сцену артефакта по пути: ", scene_path)
		return null

func update_stalker_status(stalker):
	var stalker_in_zone = is_stalker_in_zone(stalker)
	
	if stalker_in_zone and not stalkers.has(stalker):
		stalkers.append(stalker)
		emit_signal("stalker_entered_zone", stalker)
	elif not stalker_in_zone and stalkers.has(stalker):
		stalkers.erase(stalker)
		emit_signal("stalker_left_zone", stalker)

func get_resource_efficiency() -> float:
	var total_resources = energy + biomass
	var max_possible = max_energy + starting_biomass
	if max_possible > 0:
		return total_resources / max_possible
	else:
		return 0.0

func get_anomaly_cost(type: String) -> float:
	match type:
		"heat": return 50.0
		"electric": return 75.0
		"acid": return 100.0
		"gravitational": return 150.0
		_: return 50.0

func get_mutant_cost(type: String) -> float:
	match type:
		"dog": return 50.0
		"snork": return 100.0
		"controller": return 200.0
		_: return 50.0

func is_stalker_in_zone(stalker) -> bool:
	if stalker != null and stalker.position != null:
		return stalker.position.distance_to(Vector2.ZERO) <= territory_radius
	else:
		return false

func start_stalker_spawning():
	if stalker_spawner and stalker_spawner.has_method("start_spawning"):
		stalker_spawner.start_spawning()

func stop_stalker_spawning():
	if stalker_spawner and stalker_spawner.has_method("stop_spawning"):
		stalker_spawner.stop_spawning()

func clear_all_stalkers():
	if stalker_spawner and stalker_spawner.has_method("clear_all_stalkers"):
		stalker_spawner.clear_all_stalkers()
