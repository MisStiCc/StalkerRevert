extends "res://scripts/mutants/base_mutant.gd"

func _ready():
    super._ready()
    
    # Установка параметров для контроллера
    health = 80.0
    speed = 4.0
    damage = 0.0
    armor = 10.0
    biomass_cost = 100.0
    
    print("Controller mutant initialized")
