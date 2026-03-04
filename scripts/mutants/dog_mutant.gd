extends "res://scripts/mutants/base_mutant.gd"

func _ready():
	super._ready()
	
	# Установка параметров для собаки
	health = 50.0
	speed = 8.0
	damage = 10.0
	armor = 0.0
	biomass_cost = 30.0
	
	print("Dog mutant initialized")
