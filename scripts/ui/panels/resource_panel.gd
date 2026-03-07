extends Control
class_name ResourcePanel

## Панель ресурсов (энергия/биомасса)

signal resource_clicked(type: String)

@onready var energy_bar: ProgressBar = $EnergyBar
@onready var biomass_bar: ProgressBar = $BiomassBar
@onready var energy_label: Label = $EnergyLabel
@onready var biomass_label: Label = $BiomassLabel

var max_energy: float = 1000.0
var max_biomass: float = 1000.0
var current_energy: float = 1000.0
var current_biomass: float = 1000.0


func _ready():
	# Клики для отладки
	if energy_bar:
		energy_bar.gui_input.connect(func(event): 
			if event is InputEventMouseButton and event.pressed:
				emit_signal("resource_clicked", "energy")
		)
	if biomass_bar:
		biomass_bar.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				emit_signal("resource_clicked", "biomass")
		)


func update_energy(current: float, max_val: float):
	current_energy = current
	max_energy = max_val
	if energy_bar:
		energy_bar.max_value = max_val
		energy_bar.value = current
	if energy_label:
		energy_label.text = "%d / %d" % [int(current), int(max_val)]


func update_biomass(current: float, max_val: float):
	current_biomass = current
	max_biomass = max_val
	if biomass_bar:
		biomass_bar.max_value = max_val
		biomass_bar.value = current
	if biomass_label:
		biomass_label.text = "%d / %d" % [int(current), int(max_val)]


func set_energy_color(color: Color):
	if energy_bar:
		var style = energy_bar.get_theme_stylebox("fill")
		if style:
			style.bg_color = color


func set_biomass_color(color: Color):
	if biomass_bar:
		var style = biomass_bar.get_theme_stylebox("fill")
		if style:
			style.bg_color = color


func is_energy_critical() -> bool:
	return current_energy / max_energy < 0.2 if max_energy > 0 else false


func is_biomass_critical() -> bool:
	return current_biomass / max_biomass < 0.2 if max_biomass > 0 else false
