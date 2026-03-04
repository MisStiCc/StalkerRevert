extends "res://scripts/mutants/base_mutant.gd"

func _ready():
    super._ready()
    health = 120
    speed = 150
    damage = 30
    armor = 5
    detection_radius = 400
    biomass_cost = 60
    chase_distance = 600  # дальше преследуют