extends Control

@onready var resource_panel = $ResourcePanel

func _ready():
	# Connect to ZoneController signals here
	pass

func update_resources(energy: int, biomass: int):
	resource_panel.update_resources(energy, biomass)
