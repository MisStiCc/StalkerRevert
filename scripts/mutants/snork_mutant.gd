extends "res://scripts/mutants/base_mutant.gd"

func _ready():
	super._ready()
	
	# Установка параметров для снорка
	health = 120.0
	speed = 6.0
	damage = 30.0
	armor = 5.0
	biomass_cost = 60.0
	
	print("Snork mutant initialized")
