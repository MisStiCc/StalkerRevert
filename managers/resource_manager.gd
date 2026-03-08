# managers/resource_manager.gd
extends Node
class_name ResourceManager

## Менеджер ресурсов - управляет энергией и биомассой

signal energy_changed(current: float, max_value: float)
signal biomass_changed(current: float, max_value: float)
signal critical_energy_reached(percent: float)
signal critical_biomass_reached(percent: float)

# Параметры
@export var max_energy: float = 1000.0:
    set(value):
        max_energy = value
        current_energy = min(current_energy, max_energy)
        energy_changed.emit(current_energy, max_energy)

@export var max_biomass: float = 1000.0:
    set(value):
        max_biomass = value
        current_biomass = min(current_biomass, max_biomass)
        biomass_changed.emit(current_biomass, max_biomass)

@export var energy_regen_rate: float = 1.0
@export var critical_threshold: float = 0.8

# Текущие значения
var current_energy: float:
    set(value):
        var old_value = current_energy
        current_energy = clamp(value, 0.0, max_energy)
        if current_energy != old_value:
            energy_changed.emit(current_energy, max_energy)
            _check_critical_energy()

var current_biomass: float:
    set(value):
        var old_value = current_biomass
        current_biomass = clamp(value, 0.0, max_biomass)
        if current_biomass != old_value:
            biomass_changed.emit(current_biomass, max_biomass)
            _check_critical_biomass()

# Аккумулированная биомасса за забег
var accumulated_biomass: float = 0.0


func _ready():
    add_to_group("resource_manager")
    current_energy = max_energy * 0.5
    current_biomass = max_biomass * 0.3
    set_process(true)
    Logger.info("ResourceManager инициализирован", "ResourceManager")


func _process(delta):
    # Регенерация энергии
    if current_energy < max_energy:
        current_energy += energy_regen_rate * delta


# ==================== ЭНЕРГИЯ ====================

func add_energy(amount: float):
    current_energy += amount
    Logger.debug("Энергия +" + str(amount) + ", теперь: " + str(current_energy), "ResourceManager")


func spend_energy(amount: float) -> bool:
    if current_energy >= amount:
        current_energy -= amount
        Logger.debug("Энергия -" + str(amount) + ", осталось: " + str(current_energy), "ResourceManager")
        return true
    Logger.warning("Недостаточно энергии: нужно " + str(amount) + ", есть " + str(current_energy), "ResourceManager")
    return false


func get_energy() -> float:
    return current_energy


func get_energy_percent() -> float:
    return current_energy / max_energy if max_energy > 0 else 0.0


func _check_critical_energy():
    if current_energy >= max_energy * critical_threshold:
        critical_energy_reached.emit(get_energy_percent())
        Logger.warning("Критический уровень энергии: " + str(get_energy_percent() * 100) + "%", "ResourceManager")


# ==================== БИОМАССА ====================

func add_biomass(amount: float):
    current_biomass += amount
    accumulated_biomass += amount
    Logger.debug("Биомасса +" + str(amount) + ", теперь: " + str(current_biomass), "ResourceManager")


func spend_biomass(amount: float) -> bool:
    if current_biomass >= amount:
        current_biomass -= amount
        Logger.debug("Биомасса -" + str(amount) + ", осталось: " + str(current_biomass), "ResourceManager")
        return true
    Logger.warning("Недостаточно биомассы: нужно " + str(amount) + ", есть " + str(current_biomass), "ResourceManager")
    return false


func get_biomass() -> float:
    return current_biomass


func get_biomass_percent() -> float:
    return current_biomass / max_biomass if max_biomass > 0 else 0.0


func _check_critical_biomass():
    if current_biomass >= max_biomass * critical_threshold:
        critical_biomass_reached.emit(get_biomass_percent())
        Logger.warning("Критический уровень биомассы: " + str(get_biomass_percent() * 100) + "%", "ResourceManager")


# ==================== УТИЛИТЫ ====================

func can_afford(energy_cost: float, biomass_cost: float) -> bool:
    return current_energy >= energy_cost and current_biomass >= biomass_cost


func reset():
    current_energy = max_energy * 0.5
    current_biomass = max_biomass * 0.3
    accumulated_biomass = 0.0
    Logger.info("Ресурсы сброшены", "ResourceManager")


func get_status() -> Dictionary:
    return {
        "energy": current_energy,
        "max_energy": max_energy,
        "energy_percent": get_energy_percent(),
        "biomass": current_biomass,
        "max_biomass": max_biomass,
        "biomass_percent": get_biomass_percent(),
        "accumulated": accumulated_biomass
    }