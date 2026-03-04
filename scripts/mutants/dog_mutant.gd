extends "res://scripts/mutants/base_mutant.gd"

func _ready():
    super._ready()
    # Особые настройки для собак
    health = 50
    speed = 200
    damage = 10
    armor = 0
    detection_radius = 350
    biomass_cost = 30