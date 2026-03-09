# ui/hud/hud.gd
extends CanvasLayer
class_name HUD

signal anomaly_requested(anomaly_type: String)
signal mutant_requested(mutant_type: String)
signal emission_requested

@onready var energy_value: Label = $Resources/EnergyValue
@onready var biomass_value: Label = $Resources/BiomassValue
@onready var wave_label: Label = $Resources/WaveLabel
@onready var stalker_count_label: Label = $Resources/StalkerCountLabel

@onready var emission_label: Label = $EmissionPanel/EmissionLabel
@onready var emission_timer_label: Label = $EmissionPanel/EmissionTimerLabel
@onready var emission_button: Button = $EmissionPanel/EmissionButton

@onready var anomaly_panel: Panel = $AnomalyPanel
@onready var mutant_panel: Panel = $MutantPanel

# Кнопки аномалий
@onready var fire_button: Button = $AnomalyPanel/FireButton
@onready var electric_button: Button = $AnomalyPanel/ElectricButton
@onready var acid_button: Button = $AnomalyPanel/AcidButton
@onready var vortex_button: Button = $AnomalyPanel/VortexButton
@onready var lift_button: Button = $AnomalyPanel/LiftButton
@onready var whirlwind_button: Button = $AnomalyPanel/WhirlwindButton
@onready var steam_button: Button = $AnomalyPanel/SteamButton
@onready var comet_button: Button = $AnomalyPanel/CometButton
@onready var jelly_button: Button = $AnomalyPanel/JellyButton
@onready var gas_button: Button = $AnomalyPanel/GasButton
@onready var acid_cloud_button: Button = $AnomalyPanel/AcidCloudButton
@onready var radiation_button: Button = $AnomalyPanel/RadiationButton
@onready var time_button: Button = $AnomalyPanel/TimeButton
@onready var teleport_button: Button = $AnomalyPanel/TeleportButton
@onready var tesla_button: Button = $AnomalyPanel/TeslaButton
@onready var fluff_button: Button = $AnomalyPanel/FluffButton

# Кнопки мутантов
@onready var dog_button: Button = $MutantPanel/DogButton
@onready var flesh_button: Button = $MutantPanel/FleshButton
@onready var snork_button: Button = $MutantPanel/SnorkButton
@onready var pseudodog_button: Button = $MutantPanel/PseudodogButton
@onready var controller_button: Button = $MutantPanel/ControllerButton
@onready var poltergeist_button: Button = $MutantPanel/PoltergeistButton
@onready var bloodsucker_button: Button = $MutantPanel/BloodsuckerButton
@onready var chimera_button: Button = $MutantPanel/ChimeraButton
@onready var zombie_button: Button = $MutantPanel/ZombieButton

var zone_controller: Node
var emission_cooldown: float = 60.0
var emission_timer: float = 0.0
var is_emission_active: bool = false


func _ready():
	add_to_group("hud")
	zone_controller = get_tree().get_first_node_in_group("zone_controller")
	
	if zone_controller:
		zone_controller.energy_changed.connect(_on_energy_changed)
		zone_controller.biomass_changed.connect(_on_biomass_changed)
		zone_controller.radiation_pulse_started.connect(_on_emission_started)
		zone_controller.radiation_pulse_ended.connect(_on_emission_ended)
		zone_controller.wave_started.connect(_on_wave_started)
	
	_connect_buttons()
	_setup_sounds()
	
	print("HUD инициализирован")


func _connect_buttons():
	# Аномалии
	fire_button.pressed.connect(_on_fire_pressed)
	electric_button.pressed.connect(_on_electric_pressed)
	acid_button.pressed.connect(_on_acid_pressed)
	vortex_button.pressed.connect(_on_vortex_pressed)
	lift_button.pressed.connect(_on_lift_pressed)
	whirlwind_button.pressed.connect(_on_whirlwind_pressed)
	steam_button.pressed.connect(_on_steam_pressed)
	comet_button.pressed.connect(_on_comet_pressed)
	jelly_button.pressed.connect(_on_jelly_pressed)
	gas_button.pressed.connect(_on_gas_pressed)
	acid_cloud_button.pressed.connect(_on_acid_cloud_pressed)
	radiation_button.pressed.connect(_on_radiation_pressed)
	time_button.pressed.connect(_on_time_pressed)
	teleport_button.pressed.connect(_on_teleport_pressed)
	tesla_button.pressed.connect(_on_tesla_pressed)
	fluff_button.pressed.connect(_on_fluff_pressed)
	
	# Мутанты
	dog_button.pressed.connect(_on_dog_pressed)
	flesh_button.pressed.connect(_on_flesh_pressed)
	snork_button.pressed.connect(_on_snork_pressed)
	pseudodog_button.pressed.connect(_on_pseudodog_pressed)
	controller_button.pressed.connect(_on_controller_pressed)
	poltergeist_button.pressed.connect(_on_poltergeist_pressed)
	bloodsucker_button.pressed.connect(_on_bloodsucker_pressed)
	chimera_button.pressed.connect(_on_chimera_pressed)
	zombie_button.pressed.connect(_on_zombie_pressed)
	
	emission_button.pressed.connect(_on_emission_pressed)


func _setup_sounds():
	var buttons = [
		fire_button, electric_button, acid_button,
		vortex_button, lift_button, whirlwind_button,
		steam_button, comet_button, jelly_button,
		gas_button, acid_cloud_button, radiation_button,
		time_button, teleport_button, tesla_button, fluff_button,
		dog_button, flesh_button, snork_button, pseudodog_button,
		controller_button, poltergeist_button, bloodsucker_button,
		chimera_button, zombie_button, emission_button
	]
	
	for btn in buttons:
		if btn:
			btn.mouse_entered.connect(_play_hover_sound)


func _play_hover_sound():
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_hover", 0.3)


func _play_click_sound():
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.6)


func _process(delta):
	if emission_timer > 0:
		emission_timer -= delta
		emission_timer_label.text = "⌛ %dс" % int(emission_timer)
		emission_timer_label.visible = true
	else:
		emission_timer_label.visible = false
	
	if zone_controller:
		var status = zone_controller.get_status()
		stalker_count_label.text = "👥 Сталкеров: %d" % status.get("stalkers", 0)


func _on_energy_changed(current: float, max_val: float):
	energy_value.text = "%d / %d" % [int(current), int(max_val)]


func _on_biomass_changed(current: float, max_val: float):
	biomass_value.text = "%d / %d" % [int(current), int(max_val)]


func _on_wave_started(wave_number: int, count: int):
	wave_label.text = "🌊 ВОЛНА %d" % wave_number
	wave_label.modulate = Color.YELLOW
	wave_label.visible = true
	
	var tween = create_tween()
	tween.tween_property(wave_label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(func(): wave_label.visible = false)


func _on_emission_started(level: int):
	is_emission_active = true
	emission_button.disabled = true
	emission_label.text = "⚠️ ВЫБРОС! ⚠️"
	emission_label.modulate = Color.RED
	emission_timer = 0
	emission_timer_label.visible = false


func _on_emission_ended():
	is_emission_active = false
	emission_label.text = ""
	emission_timer = emission_cooldown


func _on_emission_pressed():
	_play_click_sound()
	emission_requested.emit()
	
	if zone_controller and zone_controller.has_method("start_radiation_pulse"):
		if zone_controller.spend_energy(200):
			zone_controller.start_radiation_pulse()


# ==================== АНОМАЛИИ ====================

func _on_fire_pressed():
	_play_click_sound()
	anomaly_requested.emit("heat_anomaly")

func _on_electric_pressed():
	_play_click_sound()
	anomaly_requested.emit("electric_anomaly")

func _on_acid_pressed():
	_play_click_sound()
	anomaly_requested.emit("acid_anomaly")

func _on_vortex_pressed():
	_play_click_sound()
	anomaly_requested.emit("gravity_vortex")

func _on_lift_pressed():
	_play_click_sound()
	anomaly_requested.emit("gravity_lift")

func _on_whirlwind_pressed():
	_play_click_sound()
	anomaly_requested.emit("gravity_whirlwind")

func _on_steam_pressed():
	_play_click_sound()
	anomaly_requested.emit("thermal_steam")

func _on_comet_pressed():
	_play_click_sound()
	anomaly_requested.emit("thermal_comet")

func _on_jelly_pressed():
	_play_click_sound()
	anomaly_requested.emit("chemical_jelly")

func _on_gas_pressed():
	_play_click_sound()
	anomaly_requested.emit("chemical_gas")

func _on_acid_cloud_pressed():
	_play_click_sound()
	anomaly_requested.emit("chemical_acid_cloud")

func _on_radiation_pressed():
	_play_click_sound()
	anomaly_requested.emit("radiation_hotspot")

func _on_time_pressed():
	_play_click_sound()
	anomaly_requested.emit("time_dilation")

func _on_teleport_pressed():
	_play_click_sound()
	anomaly_requested.emit("teleport")

func _on_tesla_pressed():
	_play_click_sound()
	anomaly_requested.emit("electric_tesla")

func _on_fluff_pressed():
	_play_click_sound()
	anomaly_requested.emit("bio_burning_fluff")


# ==================== МУТАНТЫ ====================

func _on_dog_pressed():
	_play_click_sound()
	mutant_requested.emit("dog_mutant")

func _on_flesh_pressed():
	_play_click_sound()
	mutant_requested.emit("flesh")

func _on_snork_pressed():
	_play_click_sound()
	mutant_requested.emit("snork_mutant")

func _on_pseudodog_pressed():
	_play_click_sound()
	mutant_requested.emit("pseudodog")

func _on_controller_pressed():
	_play_click_sound()
	mutant_requested.emit("controller_mutant")

func _on_poltergeist_pressed():
	_play_click_sound()
	mutant_requested.emit("poltergeist")

func _on_bloodsucker_pressed():
	_play_click_sound()
	mutant_requested.emit("bloodsucker")

func _on_chimera_pressed():
	_play_click_sound()
	mutant_requested.emit("chimera")

func _on_zombie_pressed():
	_play_click_sound()
	mutant_requested.emit("zombie")


func show_anomaly_panel(visible: bool):
	anomaly_panel.visible = visible


func show_mutant_panel(visible: bool):
	mutant_panel.visible = visible
