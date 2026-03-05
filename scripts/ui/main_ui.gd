extends CanvasLayer
class_name MainUI

var zone_controller: Node

@onready var energy_label: Label = $EnergyValue
@onready var biomass_label: Label = $BiomassValue
@onready var energy_bar: ProgressBar = $EnergyBar
@onready var biomass_bar: ProgressBar = $BiomassBar
@onready var fire_button: Button = $FireButton
@onready var electric_button: Button = $ElectricButton
@onready var acid_button: Button = $AcidButton
@onready var emission_button: Button = $EmissionButton


func _ready():
	# Поиск ZoneController
	zone_controller = get_tree().get_first_node_in_group("zone_controller")
	
	if not zone_controller:
		push_error("ZoneController not found! UI будет неактивен")
		_disable_buttons()
		return
	
	# Подключаемся к сигналам
	if zone_controller.has_signal("energy_changed"):
		zone_controller.energy_changed.connect(_on_energy_changed)
	if zone_controller.has_signal("biomass_changed"):
		zone_controller.biomass_changed.connect(_on_biomass_changed)
	if zone_controller.has_signal("emission_started"):
		zone_controller.emission_started.connect(_on_emission_started)
	if zone_controller.has_signal("emission_ended"):
		zone_controller.emission_ended.connect(_on_emission_ended)
	
	# Подключаем кнопки
	fire_button.pressed.connect(_on_fire_button_pressed)
	electric_button.pressed.connect(_on_electric_button_pressed)
	acid_button.pressed.connect(_on_acid_button_pressed)
	emission_button.pressed.connect(_on_emission_button_pressed)
	
	# Обновляем UI с начальными значениями
	if zone_controller.has_method("get_energy"):
		_on_energy_changed(zone_controller.get_energy())
	if zone_controller.has_method("get_biomass"):
		_on_biomass_changed(zone_controller.get_biomass())


func _disable_buttons():
	fire_button.disabled = true
	electric_button.disabled = true
	acid_button.disabled = true
	emission_button.disabled = true


func _on_energy_changed(energy: float):
	energy_label.text = str(int(energy))
	energy_bar.max_value = zone_controller.max_energy if zone_controller else 1000
	energy_bar.value = energy
	
	# Обновляем состояние кнопок в зависимости от энергии
	_update_buttons_state()


func _on_biomass_changed(biomass: float):
	biomass_label.text = str(int(biomass))
	biomass_bar.value = biomass


func _on_emission_started():
	emission_button.disabled = true
	emission_button.text = "ВЫБРОС ИДЁТ"


func _on_emission_ended():
	emission_button.disabled = false
	emission_button.text = "ВЫБРОС"
	_update_buttons_state()


func _update_buttons_state():
	if not zone_controller or not zone_controller.has_method("can_afford"):
		return
	
	# Проверяем, хватает ли энергии на каждую аномалию (цены из ZoneController)
	fire_button.disabled = not zone_controller.can_afford(50, 0)
	electric_button.disabled = not zone_controller.can_afford(75, 0)  # исправлено с 60 на 75
	acid_button.disabled = not zone_controller.can_afford(100, 0)    # исправлено с 70 на 100
	
	# Выброс может быть недоступен во время другого выброса
	if emission_button.text != "ВЫБРОС ИДЁТ":
		emission_button.disabled = not zone_controller.can_afford(200, 0)


func _on_fire_button_pressed():
	if zone_controller and zone_controller.has_method("spawn_anomaly"):
		if zone_controller.spawn_anomaly("fire", _get_spawn_position()):
			print("Аномалия Жарка создана")
		else:
			print("Недостаточно энергии для создания аномалии")


func _on_electric_button_pressed():
	if zone_controller and zone_controller.has_method("spawn_anomaly"):
		if zone_controller.spawn_anomaly("electric", _get_spawn_position()):
			print("Аномалия Электра создана")
		else:
			print("Недостаточно энергии для создания аномалии")


func _on_acid_button_pressed():
	if zone_controller and zone_controller.has_method("spawn_anomaly"):
		if zone_controller.spawn_anomaly("acid", _get_spawn_position()):
			print("Аномалия Кислота создана")
		else:
			print("Недостаточно энергии для создания аномалии")


func _on_emission_button_pressed():
	if zone_controller and zone_controller.has_method("start_emission"):
		if zone_controller.can_afford(200, 0):
			zone_controller.start_emission(10.0)
		else:
			print("Недостаточно энергии для выброса")


func _get_spawn_position() -> Vector3:
	# Простая логика: спавним перед камерой
	var camera = get_viewport().get_camera_3d()
	if camera:
		return camera.global_position + camera.global_transform.basis.z * -10 + Vector3.UP * 2
	return Vector3.ZERO