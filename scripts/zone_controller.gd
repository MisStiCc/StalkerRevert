extends Node
class_name ZoneController

## Контроллер зоны - управляет ресурсами, сложностью и взаимодействиями

# Сигналы
signal energy_changed(current: float, max: float)
signal biomass_changed(current: float, max: float)
signal difficulty_changed(new_difficulty: float)
signal stalker_entered(stalker: Node)
signal stalker_left(stalker: Node)
signal anomaly_destroyed(anomaly_type: String, position: Vector3, difficulty: int)
signal artifact_created(artifact_type: String, position: Vector3)
signal artifact_collected(artifact: Node, stalker: Node)
signal artifact_stolen(artifact: Node, stalker: Node)
signal stalker_died(stalker_type: String, biomass_returned: float)

# Ресурсы
@export var max_energy: float = 1000.0
@export var max_biomass: float = 500.0
@export var energy_regen_rate: float = 1.0
@export var biomass_decay_rate: float = 0.1

# Сложность
@export var base_difficulty: float = 1.0
@export var difficulty_increase_per_stalker: float = 0.05
@export var max_difficulty: float = 3.0
@export var min_difficulty: float = 0.5

# Аномалии - ВСЕ 16 аномалий проекта
@export var anomaly_scenes: Dictionary = {
	"thermal_steam": preload("res://scenes/zone/anomalies/thermal_steam.tscn"),
	"thermal_comet": preload("res://scenes/zone/anomalies/thermal_comet.tscn"),
	"heat_anomaly": preload("res://scenes/zone/anomalies/heat_anomaly.tscn"),
	"gravity_vortex": preload("res://scenes/zone/anomalies/gravity_vortex.tscn"),
	"gravity_lift": preload("res://scenes/zone/anomalies/gravity_lift.tscn"),
	"gravity_whirlwind": preload("res://scenes/zone/anomalies/gravity_whirlwind.tscn"),
	"electric_anomaly": preload("res://scenes/zone/anomalies/electric_anomaly.tscn"),
	"electric_tesla": preload("res://scenes/zone/anomalies/electric_tesla.tscn"),
	"chemical_gas": preload("res://scenes/zone/anomalies/chemical_gas.tscn"),
	"chemical_acid_cloud": preload("res://scenes/zone/anomalies/chemical_acid_cloud.tscn"),
	"chemical_jelly": preload("res://scenes/zone/anomalies/chemical_jelly.tscn"),
	"radiation_hotspot": preload("res://scenes/zone/anomalies/radiation_hotspot.tscn"),
	"bio_burning_fluff": preload("res://scenes/zone/anomalies/bio_burning_fluff.tscn"),
	"time_dilation": preload("res://scenes/zone/anomalies/time_dilation.tscn"),
	"teleport": preload("res://scenes/zone/anomalies/teleport.tscn"),
	"acid_anomaly": preload("res://scenes/zone/anomalies/acid_anomaly.tscn")
}

# Карта соответствия аномалий и артефактов
var anomaly_artifact_map: Dictionary = {
	"thermal_steam": "fireball_artifact",
	"thermal_comet": "fireball_artifact",
	"heat_anomaly": "fireball_artifact",
	"gravity_vortex": "graviton_artifact",
	"gravity_lift": "graviton_artifact",
	"gravity_whirlwind": "void_artifact",
	"electric_anomaly": "spark_artifact",
	"electric_tesla": "battery_artifact",
	"chemical_acid_cloud": "acid_drop_artifact",
	"chemical_gas": "gas_bottle_artifact",
	"chemical_jelly": "slime_artifact",
	"radiation_hotspot": "uranium_artifact",
	"bio_burning_fluff": "heart_artifact",
	"time_dilation": "clock_artifact",
	"teleport": "anchor_artifact",
	"acid_anomaly": "acid_drop_artifact"
}

# Ценности артефактов по редкости
var artifact_values: Dictionary = {
	"common": [5, 6, 7, 8, 9, 10],
	"rare": [15, 18, 20, 22, 25],
	"legendary": [30, 35, 40, 45, 50]
}

# Редкость по сложности аномалии
var difficulty_to_rarity: Dictionary = {
	1: "common",
	2: "rare",
	3: "legendary"
}

# Стоимость мутантов
var mutant_costs: Dictionary = {
	"dog_mutant": 15.0,
	"flesh": 15.0,
	"snork_mutant": 25.0,
	"pseudodog": 25.0,
	"controller_mutant": 40.0,
	"poltergeist": 40.0,
	"bloodsucker": 50.0,
	"chimera": 75.0,
	"pseudogiant": 75.0
}

# Возврат биомассы за убитых сталкеров
var stalker_biomass_returns: Dictionary = {
	"novice": 8.0,
	"veteran": 15.0,
	"master": 30.0
}

# Текущие значения
var current_energy: float
var current_biomass: float
var current_difficulty: float

# Активные сущности
var active_stalkers: Array[Node] = []
var active_anomalies: Array[Node] = []
var active_artifacts: Array[Node] = []
var active_mutants: Array[Node] = []

# Таймеры
var _regen_timer: Timer
var _difficulty_timer: Timer


func _ready():
	current_energy = max_energy * 0.5
	current_biomass = max_biomass * 0.3
	current_difficulty = base_difficulty
	
	add_to_group("zone_controller")
	
	_setup_timers()
	
	print("ZoneController инициализирован с ", anomaly_scenes.size(), " аномалиями")


func _setup_timers():
	_regen_timer = Timer.new()
	_regen_timer.wait_time = 1.0
	_regen_timer.timeout.connect(_on_regen_timer)
	add_child(_regen_timer)
	_regen_timer.start()
	
	_difficulty_timer = Timer.new()
	_difficulty_timer.wait_time = 5.0
	_difficulty_timer.timeout.connect(_update_difficulty)
	add_child(_difficulty_timer)
	_difficulty_timer.start()


# ==================== УПРАВЛЕНИЕ РЕСУРСАМИ ====================

func _on_regen_timer():
	var energy_gain = energy_regen_rate
	current_energy = min(current_energy + energy_gain, max_energy)
	energy_changed.emit(current_energy, max_energy)
	
	var biomass_loss = biomass_decay_rate
	current_biomass = max(current_biomass - biomass_loss, 0)
	biomass_changed.emit(current_biomass, max_biomass)


func add_energy(amount: float):
	current_energy = min(current_energy + amount, max_energy)
	energy_changed.emit(current_energy, max_energy)


func spend_energy(amount: float) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		energy_changed.emit(current_energy, max_energy)
		return true
	return false


func add_biomass(amount: float):
	current_biomass = min(current_biomass + amount, max_biomass)
	biomass_changed.emit(current_biomass, max_biomass)


func spend_biomass(amount: float) -> bool:
	if current_biomass >= amount:
		current_biomass -= amount
		biomass_changed.emit(current_biomass, max_biomass)
		return true
	return false


# ==================== УПРАВЛЕНИЕ СЛОЖНОСТЬЮ ====================

func get_difficulty() -> float:
	return current_difficulty


func set_difficulty(value: float):
	current_difficulty = clamp(value, min_difficulty, max_difficulty)
	difficulty_changed.emit(current_difficulty)


func _update_difficulty():
	var stalker_count = active_stalkers.size()
	var difficulty_mod = 1.0 + (stalker_count * difficulty_increase_per_stalker)
	var new_difficulty = base_difficulty * difficulty_mod
	current_difficulty = clamp(new_difficulty, min_difficulty, max_difficulty)
	difficulty_changed.emit(current_difficulty)


# ==================== УПРАВЛЕНИЕ СТАЛКЕРАМИ ====================

func register_stalker(stalker: Node):
	if stalker not in active_stalkers:
		active_stalkers.append(stalker)
		stalker_entered.emit(stalker)


func unregister_stalker(stalker: Node):
	if stalker in active_stalkers:
		active_stalkers.erase(stalker)
		stalker_left.emit(stalker)


func get_stalker_count() -> int:
	return active_stalkers.size()


# ==================== УПРАВЛЕНИЕ АНОМАЛИЯМИ ====================

func create_anomaly(anomaly_type: String, position: Vector3, difficulty: int = 1) -> Node:
	if not anomaly_scenes.has(anomaly_type):
		push_error("Неизвестный тип аномалии: ", anomaly_type)
		return null
	
	if not spend_energy(_get_anomaly_cost(anomaly_type)):
		print("Недостаточно энергии")
		return null
	
	var scene = anomaly_scenes[anomaly_type]
	var anomaly = scene.instantiate()
	anomaly.position = position
	
	# Устанавливаем сложность
	if anomaly.has_method("set_difficulty"):
		anomaly.set_difficulty(difficulty)
	
	# Подключаем сигнал уничтожения
	if anomaly.has_signal("destroyed"):
		anomaly.destroyed.connect(_on_anomaly_destroyed.bind(anomaly))
	
	get_tree().current_scene.add_child(anomaly)
	active_anomalies.append(anomaly)
	
	print("Аномалия ", anomaly_type, " (ур.", difficulty, ") создана")
	return anomaly


# НОВЫЙ МЕТОД: Обработка уничтожения аномалии
func _on_anomaly_destroyed(anomaly_type: String, position: Vector3, difficulty: int):
	# Удаляем из списка
	if active_anomalies.has(position):
		active_anomalies.erase(position)
	
	# Создаём артефакт
	_spawn_artifact_from_anomaly(anomaly_type, position, difficulty)
	
	anomaly_destroyed.emit(anomaly_type, position, difficulty)
	print("💥 Аномалия ", anomaly_type, " уничтожена! Сложность: ", difficulty)


# НОВЫЙ МЕТОД: Создание артефакта из аномалии
func _spawn_artifact_from_anomaly(anomaly_type: String, position: Vector3, difficulty: int):
	var artifact_type = anomaly_artifact_map.get(anomaly_type, "common_artifact")
	var rarity = difficulty_to_rarity.get(difficulty, "common")
	var values = artifact_values.get(rarity, [10])
	var value = values[randi() % values.size()]
	
	var artifact = create_artifact(artifact_type, position, rarity, value)
	
	if artifact:
		print("📦 Создан ", rarity, " артефакт ", artifact_type, " ценой ", value)


func _get_anomaly_cost(anomaly_type: String) -> float:
	match anomaly_type:
		"heat_anomaly": return 50.0
		"electric_anomaly": return 75.0
		"acid_anomaly": return 100.0
		"gravity_vortex": return 150.0
		"gravity_lift": return 80.0
		"gravity_whirlwind": return 120.0
		"thermal_steam": return 70.0
		"thermal_comet": return 100.0
		"chemical_jelly": return 60.0
		"chemical_gas": return 85.0
		"chemical_acid_cloud": return 110.0
		"radiation_hotspot": return 95.0
		"time_dilation": return 200.0
		"teleport": return 180.0
		"electric_tesla": return 90.0
		"bio_burning_fluff": return 75.0
		_: return 50.0


# ==================== УПРАВЛЕНИЕ АРТЕФАКТАМИ ====================

func create_artifact(artifact_type: String, position: Vector3, rarity: String = "common", value: float = 10.0) -> Node:
	var scene_path = "res://scenes/artifacts/" + artifact_type + ".tscn"
	if not ResourceLoader.exists(scene_path):
		push_error("Сцена артефакта не найдена: ", scene_path)
		return null
	
	var scene = load(scene_path)
	var artifact = scene.instantiate()
	artifact.position = position
	
	# Устанавливаем редкость и ценность
	if artifact.has_method("set_rarity_and_value"):
		artifact.set_rarity_and_value(rarity, value)
	
	# Подключаем сигналы
	if artifact.has_signal("stolen"):
		artifact.stolen.connect(_on_artifact_stolen.bind(artifact))
	if artifact.has_signal("collected"):
		artifact.collected.connect(_on_artifact_collected.bind(artifact))
	
	get_tree().current_scene.add_child(artifact)
	active_artifacts.append(artifact)
	
	artifact_created.emit(artifact_type, position)
	
	return artifact


# НОВЫЙ МЕТОД: Обработка кражи артефакта сталкером
func _on_artifact_stolen(artifact: Node, stalker: Node):
	# Потеря биомассы = ценность артефакта
	var loss = 10.0
	if artifact.has_method("get_value"):
		loss = artifact.get_value()
	
	current_biomass = max(current_biomass - loss, 0)
	biomass_changed.emit(current_biomass, max_biomass)
	
	var stalker_type = "неизвестный"
	if stalker.has_method("get_stalker_type"):
		stalker_type = stalker.get_stalker_type()
		
		# Сталкер несёт артефакт
		if stalker.has_method("_on_artifact_stolen"):
			stalker._on_artifact_stolen(artifact)
	
	print("👿 ", stalker_type, " украл артефакт! Потеряно ", loss, " биомассы")
	artifact_stolen.emit(artifact, stalker)


# НОВЫЙ МЕТОД: Обработка сбора артефакта зоной
func _on_artifact_collected(artifact: Node, stalker: Node):
	if artifact in active_artifacts:
		active_artifacts.erase(artifact)
		artifact_collected.emit(artifact, stalker)


# ==================== УПРАВЛЕНИЕ МУТАНТАМИ ====================

func register_mutant(mutant: Node):
	if mutant not in active_mutants:
		active_mutants.append(mutant)


func unregister_mutant(mutant: Node):
	if mutant in active_mutants:
		active_mutants.erase(mutant)


func spawn_mutant(mutant_type: String, position: Vector3) -> Node:
	var cost = mutant_costs.get(mutant_type, 20.0)
	
	if not spend_biomass(cost):
		print("❌ Недостаточно биомассы для создания мутанта ", mutant_type)
		return null
	
	var scene_path = "res://scenes/zone/mutants/" + mutant_type + ".tscn"
	if not ResourceLoader.exists(scene_path):
		push_error("Сцена мутанта не найдена: ", scene_path)
		return null
	
	var scene = load(scene_path)
	var mutant = scene.instantiate()
	mutant.position = position
	
	get_tree().current_scene.add_child(mutant)
	active_mutants.append(mutant)
	
	print("🦎 Мутант ", mutant_type, " создан за ", cost, " биомассы")
	return mutant


# НОВЫЙ МЕТОД: Обработка смерти сталкера
func on_stalker_died(stalker: Node):
	var stalker_type = "base"
	if stalker.has_method("get_stalker_type"):
		stalker_type = stalker.get_stalker_type()
	
	var return_value = stalker_biomass_returns.get(stalker_type, 10.0)
	add_biomass(return_value)
	
	print("💀 Сталкер (", stalker_type, ") убит! Возвращено ", return_value, " биомассы")
	stalker_died.emit(stalker_type, return_value)


# ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

func get_resource_status() -> Dictionary:
	return {
		"energy": current_energy,
		"max_energy": max_energy,
		"biomass": current_biomass,
		"max_biomass": max_biomass,
		"difficulty": current_difficulty,
		"stalker_count": active_stalkers.size()
	}


# ==================== АЛИАСЫ ДЛЯ СОВМЕСТИМОСТИ ====================

var button_to_anomaly_map: Dictionary = {
	"fire": "heat_anomaly",
	"electric": "electric_anomaly",
	"acid": "acid_anomaly"
}


func spawn_anomaly(anomaly_type: String, position: Vector3) -> Node:
	var actual_type = button_to_anomaly_map.get(anomaly_type, anomaly_type)
	return create_anomaly(actual_type, position)


func get_energy() -> float:
	return current_energy


func get_biomass() -> float:
	return current_biomass


func can_afford(energy_cost: float, biomass_cost: float) -> bool:
	return current_energy >= energy_cost and current_biomass >= biomass_cost
