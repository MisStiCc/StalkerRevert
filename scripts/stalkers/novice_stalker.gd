extends "res://scripts/stalkers/base_stalker.gd"

func _ready():
    stalker_type = "novice"
    health = 50.0
    speed = 100.0
    damage = 10.0
    armor = 0.0
    detection_radius = 150.0
    attack_cooldown = 2.0
    biomass_cost = 30.0

func get_biomass_value() -> int:
    return 5