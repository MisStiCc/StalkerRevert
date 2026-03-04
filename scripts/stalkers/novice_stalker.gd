extends "res://scripts/stalkers/base_stalker.gd"

class_name NoviceStalker

# Параметры новичка-сталкера
@export var novice_health: float = 80.0
@export var novice_speed: float = 4.0
@export var novice_damage: float = 8.0

func _ready():
	super._ready()
	
	# Установка параметров для новичка
	health = novice_health
	max_health = novice_health
	speed = novice_speed
	damage = novice_damage
	
	# Можно добавить специфичное для новичка поведение
	print("Novice stalker initialized")

func _handle_idle_state(delta):
	# Новички более осторожны в состоянии ожидания
	super._handle_idle_state(delta)
	
	# Новички могут заметить цель с меньшего расстояния
	if target and global_position.distance_to(target.global_position) < 15.0:
		_change_state(StalkerState.CHASE)

func _handle_chase_state(delta):
	# Новички бегут медленнее
	var chase_speed = speed * 0.8
	if target:
		var direction = global_position.direction_to(target.global_position)
		if direction.length() > 0:
			velocity = direction * chase_speed
		else:
			velocity = Vector3.ZERO
		
		# Новички атакуют с меньшего расстояния
		var distance_to_target = global_position.distance_to(target.global_position)
		if distance_to_target < 1.5:
			_change_state(StalkerState.ATTACK)
	else:
		_change_state(StalkerState.IDLE)

func attack_target():
	if target and current_state == StalkerState.ATTACK:
		# Новички наносят меньше урона
		if target.has_method("take_damage"):
			target.take_damage(damage * 0.7)  # 70% от базового урона
		
		# Новички чаще бегут после атаки
		if randf() < 0.4:  # 40% шанс бегства
			_change_state(StalkerState.FLEE)

func take_damage(amount: float):
	super.take_damage(amount)
	
	# Новички более склонны к бегству при получении урона
	if health < max_health * 0.5 and current_state != StalkerState.FLEE:
		if randf() < 0.6:  # 60% шанс начать бегство
			_change_state(StalkerState.FLEE)