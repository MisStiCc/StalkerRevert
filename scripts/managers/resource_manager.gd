extends Node
class_name ResourceManager

## Manages resources: energy and biomass
## Connected to run_controller

signal energy_changed(current: float, max_energy: float)
signal biomass_changed(current: float, max_biomass: float)
signal critical_biomass_reached

@export var max_energy: float = 1000.0
@export var max_biomass: float = 1000.0
@export var energy_regen_rate: float = 1.0
@export var biomass_growth_rate: float = 0.1
@export var critical_threshold: float = 0.8

var current_energy: float
var current_biomass: float
var accumulated_biomass: float = 0.0


func _ready():
	add_to_group("resource_manager")
	current_energy = max_energy * 0.5
	current_biomass = max_biomass * 0.3


# ENERGY
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


# BIOMASS
func add_biomass(amount: float):
	current_biomass = min(current_biomass + amount, max_biomass)
	accumulated_biomass += amount
	biomass_changed.emit(current_biomass, max_biomass)
	
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


# UTILS
func can_afford(energy_cost: float, biomass_cost: float) -> bool:
	return current_energy >= energy_cost and current_biomass >= biomass_cost


func reset():
	current_energy = max_energy * 0.5
	current_biomass = max_biomass * 0.3
	accumulated_biomass = 0.0
	energy_changed.emit(current_energy, max_energy)
	biomass_changed.emit(current_biomass, max_biomass)
