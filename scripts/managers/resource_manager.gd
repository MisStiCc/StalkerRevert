extends Node
class_name ResourceManager

## Управление ресурсами: энергия и биомасса
## Отвечает только за ресурсы, ничего больше

signal energy_changed(current: float, max_energy: float)
signal biomass_changed(current: float, max_biomass: float)
signal critical_biomass_reached

@export var max_energy: float = 1000.0
@export var max_biomass: float = 1000.0
@export var energy_regen_rate: float = 1.0
@export var biomass_decay_rate: float = 0.1
@export var critical_threshold: float = 0.8

var current_energy: float
var current_biomass: float
var accumulated_biomass: float = 0.0

var _regen_timer: Timer


func _ready():
	current_energy = max_energy * 0.5
	current_biomass = max_biomass * 0.3
	add_to_group("resource_manager")
	_setup_timers()


func _setup_timers():
	_regen_timer = Timer.new()
	_regen_timer.wait_time = 1.0
	_regen_timer.timeout.connect(_on_regen_tick)
	add_child(_regen_timer)
	_regen_timer.start()


func _on_regen_tick():
	# Регенерация энергии
	current_energy = min(current_energy + energy_regen_rate, max_energy)
	energy_changed.emit(current_energy, max_energy)
	
	# Уменьшение биомассы (распад)
	current_biomass = max(current_biomass - biomass_decay_rate, 0)
	biomass_changed.emit(current_biomass, max_biomass)


# ==================== ЭНЕРГИЯ ====================

func add_energy(amount: float):
	current_energy = min(current_energy + amount, max_energy)
	energy_changed.emit(current_energy, max_energy)


func spend_energy(amount: float) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		energy_changed.emit(current_energy, max_energy)
		return true
	return false


func get_energy() -> float:
	return current_energy


func get_energy_percent() -> float:
	return current_energy / max_energy


# ==================== БИОМАССА ====================

func add_biomass(amount: float):
	current_biomass = min(current_biomass + amount, max_biomass)
	accumulated_biomass += amount
	biomass_changed.emit(current_biomass, max_biomass)
	
	# Проверка критического порога
	if current_biomass >= max_biomass * critical_threshold:
		critical_biomass_reached.emit()


func spend_biomass(amount: float) -> bool:
	if current_biomass >= amount:
		current_biomass -= amount
		biomass_changed.emit(current_biomass, max_biomass)
		return true
	return false


func get_biomass() -> float:
	return current_biomass


func get_biomass_percent() -> float:
	return current_biomass / max_biomass


func is_critical() -> bool:
	return current_biomass >= max_biomass * critical_threshold


# ================= НАСТРОЙКА =================

func set_max_energy(value: float):
	max_energy = value
	energy_changed.emit(current_energy, max_energy)


func set_max_biomass(value: float):
	max_biomass = value
	biomass_changed.emit(current_biomass, max_biomass)


func reset():
	current_energy = max_energy * 0.5
	current_biomass = max_biomass * 0.3
	accumulated_biomass = 0.0
	energy_changed.emit(current_energy, max_energy)
	biomass_changed.emit(current_biomass, max_biomass)
