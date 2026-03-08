extends CanvasLayer
class_name MainUI

var run_controller: Node

# Кнопки базовых аномалий
@onready var fire_button: Button = $FireButton
@onready var electric_button: Button = $ElectricButton
@onready var acid_button: Button = $AcidButton

# Кнопки гравитационных аномалий
@onready var vortex_button: Button = $VortexButton
@onready var lift_button: Button = $LiftButton
@onready var whirlwind_button: Button = $WhirlwindButton

# Кнопки термических аномалий
@onready var steam_button: Button = $SteamButton
@onready var comet_button: Button = $CometButton

# Кнопки химических аномалий
@onready var jelly_button: Button = $JellyButton
@onready var gas_button: Button = $GasButton
@onready var acid_cloud_button: Button = $AcidCloudButton

# Кнопки специальных аномалий
@onready var radiation_button: Button = $RadiationButton
@onready var time_button: Button = $TimeButton
@onready var teleport_button: Button = $TeleportButton
@onready var tesla_button: Button = $TeslaButton
@onready var fluff_button: Button = $FluffButton

# Кнопка выброса
@onready var emission_button: Button = $EmissionButton

# Метка статуса выброса
@onready var emission_label: Label = $EmissionLabel

# Метки ресурсов
@onready var energy_value_label: Label = $EnergyValue
@onready var biomass_value_label: Label = $BiomassValue

# Таймер выброса
var emission_timer: Timer
var emission_active: bool = false
var emission_cooldown: float = 60.0  # 60 секунд перезарядки


func _ready():
	# Поиск RunController
	run_controller = get_tree().get_first_node_in_group("run_controller")
	
	if not run_controller:
		push_error("ZoneController not found!")
		_disable_all_buttons()
		return
	
	# Подключаемся к сигналам
	if run_controller.has_signal("energy_changed"):
		run_controller.energy_changed.connect(_on_energy_changed)
	if run_controller.has_signal("biomass_changed"):
		run_controller.biomass_changed.connect(_on_biomass_changed)
	if run_controller.has_signal("emission_started"):
		run_controller.emission_started.connect(_on_emission_started)
	if run_controller.has_signal("emission_ended"):
		run_controller.emission_ended.connect(_on_emission_ended)
	
	# Подключаем все кнопки
	_connect_all_buttons()
	
	# Создаём таймер для выброса
	emission_timer = Timer.new()
	emission_timer.one_shot = true
	emission_timer.timeout.connect(_on_emission_cooldown_end)
	add_child(emission_timer)
	
	# Обновляем UI с начальными значениями
	if run_controller.has_method("get_resource_status"):
		var status = run_controller.get_resource_status()
		_on_energy_changed(status.get("energy", 0), status.get("max_energy", 1000))
		_on_biomass_changed(status.get("biomass", 0), status.get("max_biomass", 500))


func _connect_all_buttons():
	# Базовые
	fire_button.pressed.connect(_on_fire_button_pressed)
	electric_button.pressed.connect(_on_electric_button_pressed)
	acid_button.pressed.connect(_on_acid_button_pressed)
	
	# Гравитационные
	vortex_button.pressed.connect(_on_vortex_button_pressed)
	lift_button.pressed.connect(_on_lift_button_pressed)
	whirlwind_button.pressed.connect(_on_whirlwind_button_pressed)
	
	# Термические
	steam_button.pressed.connect(_on_steam_button_pressed)
	comet_button.pressed.connect(_on_comet_button_pressed)
	
	# Химические
	jelly_button.pressed.connect(_on_jelly_button_pressed)
	gas_button.pressed.connect(_on_gas_button_pressed)
	acid_cloud_button.pressed.connect(_on_acid_cloud_button_pressed)
	
	# Специальные
	radiation_button.pressed.connect(_on_radiation_button_pressed)
	time_button.pressed.connect(_on_time_button_pressed)
	teleport_button.pressed.connect(_on_teleport_button_pressed)
	tesla_button.pressed.connect(_on_tesla_button_pressed)
	fluff_button.pressed.connect(_on_fluff_button_pressed)
	
	# Выброс
	emission_button.pressed.connect(_on_emission_button_pressed)


func _disable_all_buttons():
	fire_button.disabled = true
	electric_button.disabled = true
	acid_button.disabled = true
	vortex_button.disabled = true
	lift_button.disabled = true
	whirlwind_button.disabled = true
	steam_button.disabled = true
	comet_button.disabled = true
	jelly_button.disabled = true
	gas_button.disabled = true
	acid_cloud_button.disabled = true
	radiation_button.disabled = true
	time_button.disabled = true
	teleport_button.disabled = true
	tesla_button.disabled = true
	fluff_button.disabled = true
	emission_button.disabled = true


func _on_energy_changed(current: float, max_energy: float):
	if energy_value_label:
		energy_value_label.text = "%d / %d" % [int(current), int(max_energy)]
	_update_buttons_state()


func _on_biomass_changed(current: float, max_biomass: float):
	if biomass_value_label:
		biomass_value_label.text = "%d / %d" % [int(current), int(max_biomass)]


func _update_buttons_state():
	if not run_controller or not run_controller.has_method("can_afford"):
		return
	
	# Проверяем все аномалии
	fire_button.disabled = not run_controller.can_afford(50, 0)
	electric_button.disabled = not run_controller.can_afford(75, 0)
	acid_button.disabled = not run_controller.can_afford(100, 0)
	
	vortex_button.disabled = not run_controller.can_afford(150, 0)
	lift_button.disabled = not run_controller.can_afford(80, 0)
	whirlwind_button.disabled = not run_controller.can_afford(120, 0)
	
	steam_button.disabled = not run_controller.can_afford(70, 0)
	comet_button.disabled = not run_controller.can_afford(100, 0)
	
	jelly_button.disabled = not run_controller.can_afford(60, 0)
	gas_button.disabled = not run_controller.can_afford(85, 0)
	acid_cloud_button.disabled = not run_controller.can_afford(110, 0)
	
	radiation_button.disabled = not run_controller.can_afford(95, 0)
	time_button.disabled = not run_controller.can_afford(200, 0)
	teleport_button.disabled = not run_controller.can_afford(180, 0)
	tesla_button.disabled = not run_controller.can_afford(90, 0)
	fluff_button.disabled = not run_controller.can_afford(75, 0)
	
	# Кнопка выброса
	if not emission_active and not emission_timer.time_left > 0:
		emission_button.disabled = not run_controller.can_afford(200, 0)
	else:
		emission_button.disabled = true


# === ОБРАБОТЧИКИ КНОПОК АНОМАЛИЙ ===

func _on_fire_button_pressed():
	_spawn_anomaly("fire")

func _on_electric_button_pressed():
	_spawn_anomaly("electric")

func _on_acid_button_pressed():
	_spawn_anomaly("acid")

func _on_vortex_button_pressed():
	_spawn_anomaly("gravity_vortex")

func _on_lift_button_pressed():
	_spawn_anomaly("gravity_lift")

func _on_whirlwind_button_pressed():
	_spawn_anomaly("gravity_whirlwind")

func _on_steam_button_pressed():
	_spawn_anomaly("thermal_steam")

func _on_comet_button_pressed():
	_spawn_anomaly("thermal_comet")

func _on_jelly_button_pressed():
	_spawn_anomaly("chemical_jelly")

func _on_gas_button_pressed():
	_spawn_anomaly("chemical_gas")

func _on_acid_cloud_button_pressed():
	_spawn_anomaly("chemical_acid_cloud")

func _on_radiation_button_pressed():
	_spawn_anomaly("radiation_hotspot")

func _on_time_button_pressed():
	_spawn_anomaly("time_dilation")

func _on_teleport_button_pressed():
	_spawn_anomaly("teleport")

func _on_tesla_button_pressed():
	_spawn_anomaly("electric_tesla")

func _on_fluff_button_pressed():
	_spawn_anomaly("bio_burning_fluff")


func _spawn_anomaly(type: String):
	if run_controller and run_controller.has_method("spawn_anomaly"):
		var pos = _get_spawn_position()
		var anomaly = run_controller.spawn_anomaly(type, pos)
		if anomaly:
			print("Аномалия ", type, " создана")
		else:
			print("Не удалось создать аномалию ", type)


func _on_emission_button_pressed():
	if run_controller and run_controller.has_method("start_emission"):
		if run_controller.can_afford(200, 0):
			run_controller.spend_energy(200)
			run_controller.start_emission(10.0)
			emission_button.disabled = true
			emission_label.text = "ВЫБРОС! 10с"
			emission_active = true
		else:
			print("Недостаточно энергии для выброса")


func _on_emission_started():
	emission_button.disabled = true
	emission_label.text = "ВЫБРОС! 10с"
	emission_active = true


func _on_emission_ended():
	emission_active = false
	emission_label.text = "Перезарядка 60с"
	emission_timer.start(emission_cooldown)
	
	# Обновим кнопки через 60 секунд
	await get_tree().create_timer(emission_cooldown).timeout
	emission_label.text = ""
	_update_buttons_state()


func _on_emission_cooldown_end():
	emission_label.text = ""
	_update_buttons_state()


func _get_spawn_position() -> Vector3:
	# Спавним перед камерой
	var camera = get_viewport().get_camera_3d()
	if camera:
		return camera.global_position + camera.global_transform.basis.z * -10 + Vector3.UP * 2
	return Vector3.ZERO
