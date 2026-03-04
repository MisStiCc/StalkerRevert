extends CanvasLayer

# Ссылки на ZoneController (устанавливаются в _ready)
var zone_controller: Node

# Ссылки на элементы интерфейса
@onready var energy_bar: ProgressBar = $Panel/EnergyBar
@onready var biomass_bar: ProgressBar = $Panel/BiomassBar
@onready var energy_label: Label = $Panel/EnergyLabel
@onready var biomass_label: Label = $Panel/BiomassLabel
@onready var fire_button: Button = $Panel/FireButton
@onready var electric_button: Button = $Panel/ElectricButton
@onready var acid_button: Button = $Panel/AcidButton
@onready var emission_button: Button = $Panel/EmissionButton

func _ready():
    pass # Логика будет добавлена в следующих задачах

func _on_energy_changed(new_energy: float):
    pass

func _on_biomass_changed(new_biomass: float):
    pass

func _on_fire_button_pressed():
    pass

func _on_electric_button_pressed():
    pass

func _on_acid_button_pressed():
    pass

func _on_emission_button_pressed():
    pass

func _get_mouse_map_position():
    return get_viewport().get_mouse_position()
