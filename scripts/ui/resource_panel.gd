extends PanelContainer

@onready var energy_label = $VBoxContainer/EnergyLabel
@onready var biomass_label = $VBoxContainer/BiomassLabel

func update_resources(energy: int, biomass: int):
	energy_label.text = "Energy: %d" % energy
	biomass_label.text = "Biomass: %d" % biomass
