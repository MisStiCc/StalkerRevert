extends "res://scripts/stalkers/base_stalker.gd"

class_name VeteranStalker

# Параметры ветерана-сталкера
@export var veteran_health: float = 120.0
@export var veteran_speed: float = 5.5
@export var veteran_damage: float = 15.0

func _ready():
	super._ready()
	
	# Установка параметров для ветерана
	health = veteran_health
	max_health = veteran_health
	speed = veteran_speed
	damage = veteran_damage
	
	# Можно добавить специфичное для ветерана поведение
	print("Veteran stalker initialized")

func _handle_idle_state(delta):
	# Ветераны более внимательны
	super._handle_idle_state(delta)
	
	# Ветераны могут заметить цель с большего расстояния
	if target and global_position.distance_to(target.global_position) < 25.0:
		_change_state(StalkerState.CHASE)

func _handle_chase_state(delta):
	super._handle_chase_state(delta)
	
	# Ветераны атакуют с большего расстояния
	if target and global_position.distance_to(target.global_position) < 2.5:
		_change_state(StalkerState.ATTACK)

func attack_target():
	if target and current_state == StalkerState.ATTACK:
		# Ветераны наносят больше урона
		if target.has_method("take_damage"):
			target.take_damage(damage * 1.2)  # 120% от базового урона
		
		# Ветерания реже бегут после атаки
		if randf() < 0.2:  # 20% шанс бегства
			_change_state(StalkerState.FLEE)

func take_damage(amount: float):
	super.take_damage(amount)
	
	# Ветераны более стойки к бегству
	if health < max_health * 0.3 and current_state != StalkerState.FLEE:
		if randf() < 0.3:  # 30% шанс начать бегство
			_change_state(StalkerState.FLEE)
	
	# Ветераны могут контратаковать
	if health < max_health * 0.5 and current_state == StalkerState.FLEE:
		if randf() < 0.4:  # 40% шанс контратаки
			_change_state(StalkerState.CHASE)