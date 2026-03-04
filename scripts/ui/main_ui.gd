extends CanvasLayer

var zone_controller: Node

@onready var resource_panel = $ResourcePanel
@onready var energy_bar: ProgressBar = $Panel/EnergyBar
@onready var biomass_bar: ProgressBar = $Panel/BiomassBar
@onready var energy_label: Label = $Panel/EnergyLabel
@onready var biomass_label: Label = $Panel/BiomassLabel
@onready var fire_button: Button = $Panel/FireButton
@onready var electric_button: Button = $Panel/ElectricButton
@onready var acid_button: Button = $Panel/AcidButton
@onready var emission_button: Button = $Panel/EmissionButton

func _ready():
	zone_controller = get_node("/root/MainScene/ZoneController")
	if not zone_controller:
		push_error("ZoneController not found!")
		return
	
	zone_controller.resources_changed.connect(update_resources)
	
	fire_button.pressed.connect(_on_fire_button_pressed)
	electric_button.pressed.connect(_on_electric_button_pressed)
	acid_button.pressed.connect(_on_acid_button_pressed)
	emission_button.pressed.connect(_on_emission_button_pressed)
	
	update_resources(zone_controller.energy, zone_controller.biomass)

func update_resources(energy: float, biomass: float):
	resource_panel.update_resources(energy, biomass)
	energy_bar.value = energy
	energy_bar.max_value = zone_controller.max_energy
	energy_label.text = str(int(energy))
	biomass_bar.value = biomass
	biomass_label.text = str(int(biomass))

func _on_fire_button_pressed():
	if zone_controller.spend_energy(50):
		var pos = _get_mouse_map_position()
		if pos:
			zone_controller.create_anomaly("heat", pos)
	else:
		print("Недостаточно энергии!")

func _on_electric_button_pressed():
	if zone_controller.spend_energy(60):
		var pos = _get_mouse_map_position()
		if pos:
			zone_controller.create_anomaly("electric", pos)

func _on_acid_button_pressed():
	if zone_controller.spend_energy(70):
		var pos = _get_mouse_map_position()
		if pos:
			zone_controller.create_anomaly("acid", pos)

func _on_emission_button_pressed():
	if zone_controller.spend_energy(200):
		zone_controller.start_emission(10.0)

func _get_mouse_map_position():
	var viewport = get_viewport()
	if viewport:
		return viewport.get_camera_2d().get_global_mouse_position()
	else:
		return null
