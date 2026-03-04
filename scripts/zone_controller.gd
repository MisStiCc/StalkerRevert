extends Node

# Сигналы
signal energy_changed(new_energy)
signal biomass_changed(new_biomass)
signal emission_started
signal emission_ended
signal energy_depleted

# Параметры (можно менять в инспекторе)
@export var max_energy: float = 1000.0
@export var energy_regen_rate: float = 5.0  # в секунду
@export var starting_energy: float = 500.0
@export var starting_biomass: float = 0.0

# Текущие значения
var zone_energy: float
var biomass: float
var is_emission_active: bool = false

# Внутренние переменные
var _regen_timer: Timer

# Инициализация контроллера зоны
func _ready():
    zone_energy = starting_energy
    biomass = starting_biomass
    
    # Создаем и настраиваем таймер регенерации энергии
    _regen_timer = Timer.new()
    _regen_timer.wait_time = 1.0
    _regen_timer.timeout.connect(_on_regen_timer)
    add_child(_regen_timer)
    _regen_timer.start()

func _on_regen_timer():
    # Регенерируем энергию
    var old_energy = zone_energy
    zone_energy = min(zone_energy + energy_regen_rate, max_energy)
    
    # Проверяем, восстановилась ли энергия из нулевого состояния
    if old_energy <= 0 and zone_energy > 0:
        # Энергия восстановилась из истощенного состояния
        pass  # Можно добавить сигнал energy_restored при необходимости
    
    if old_energy != zone_energy:
        energy_changed.emit(zone_energy)

# Добавить биомассу (при смерти сталкера)
# @param amount: количество добавляемой биомассы
func add_biomass(amount: float):
    biomass += amount
    biomass_changed.emit(biomass)

# Потратить энергию (с проверкой доступности)
# @param amount: количество энергии для траты
# @return: true если энергии хватило, false если нет
func spend_energy(amount: float) -> bool:
    if zone_energy >= amount:
        zone_energy -= amount
        energy_changed.emit(zone_energy)
        
        # Проверяем, не истощилась ли энергия
        if zone_energy <= 0:
            energy_depleted.emit()
        
        return true
    return false

# Потратить биомассу (с проверкой доступности)
# @param amount: количество биомассы для траты
# @return: true если биомассы хватило, false если нет
func spend_biomass(amount: float) -> bool:
    if biomass >= amount:
        biomass -= amount
        biomass_changed.emit(biomass)
        return true
    return false

# Проверить, хватает ли ресурсов для действия
# @param energy_cost: требуемая стоимость энергии
# @param biomass_cost: требуемая стоимость биомассы
# @return: true если ресурсов достаточно, false если нет
func is_afford(energy_cost: float, biomass_cost: float) -> bool:
    return zone_energy >= energy_cost and biomass >= biomass_cost

# Запустить выброс (аномальную активность)
# @param duration: длительность выброса в секундах
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

# Обработчик окончания выброса
func _on_emission_end():
    is_emission_active = false
    emission_ended.emit()