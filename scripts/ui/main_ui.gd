extends CanvasLayer

var zone_controller: Node

@onready var energy_bar: ProgressBar = $Panel/EnergyBar
@onready var biomass_bar: ProgressBar = $Panel/BiomassBar
@onready var energy_label: Label = $Panel/EnergyLabel
@onready var biomass_label: Label = $Panel/BiomassLabel
@onready var fire_button: Button = $Panel/FireButton
@onready var electric_button: Button = $Panel/ElectricButton
@onready var acid_button: Button = $Panel/AcidButton
@onready var emission_button: Button = $Panel/EmissionButton

func _ready():
    zone_controller = get_node("/root/Main/ZoneController")
    if not zone_controller:
        push_error("ZoneController not found!")
        return
    
    zone_controller.energy_changed.connect(_on_energy_changed)
    zone_controller.biomass_changed.connect(_on_biomass_changed)
    
    fire_button.pressed.connect(_on_fire_button_pressed)
    electric_button.pressed.connect(_on_electric_button_pressed)
    acid_button.pressed.connect(_on_acid_button_pressed)
    emission_button.pressed.connect(_on_emission_button_pressed)
    
    _on_energy_changed(zone_controller.zone_energy)
    _on_biomass_changed(zone_controller.biomass)

func _on_energy_changed(new_energy: float):
    energy_bar.value = new_energy
    energy_bar.max_value = zone_controller.max_energy
    energy_label.text = str(int(new_energy))

func _on_biomass_changed(new_biomass: float):
    biomass_bar.value = new_biomass
    biomass_label.text = str(int(new_biomass))

func _on_fire_button_pressed():
	if zone_controller.spend_energy(50):
		var pos = _get_mouse_map_position()
		if pos:
			zone_controller.spawn_anomaly("heat", pos)
	else:
		print("Недостаточно энергии!")

func _on_electric_button_pressed():
	if zone_controller.spend_energy(60):
		var pos = _get_mouse_map_position()
		if pos:
			zone_controller.spawn_anomaly("electric", pos)

func _on_acid_button_pressed():
	if zone_controller.spend_energy(70):
		var pos = _get_mouse_map_position()
		if pos:
			zone_controller.spawn_anomaly("acid", pos)

func _on_emission_button_pressed():
	if zone_controller.spend_energy(200):
		zone_controller.start_emission(10.0)

func _get_mouse_map_position():
    return get_viewport().get_mouse_position()
