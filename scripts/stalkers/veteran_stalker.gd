extends "res://scripts/stalkers/base_stalker.gd"

func _ready():
    stalker_type = "veteran"
    health = 80.0
    speed = 150.0
    damage = 20.0
    armor = 5.0
    detection_radius = 200.0
    attack_cooldown = 1.5
    biomass_cost = 60.0

func get_biomass_value() -> int:
    return 15