extends BaseStalker
# class_name NoviceStalker  # ← закомментировал

# Параметры новичка-сталкера
@export var novice_health: float = 80.0
@export var novice_speed: float = 4.0
@export var novice_damage: float = 8.0


func _ready():
	# Установка параметров ДО вызова super._ready()
	health = novice_health
	max_health = novice_health
	speed = novice_speed
	damage = novice_damage
	
	super._ready()
	
	# Переопределяем тип сталкера
	stalker_type = "novice"
	
	print("Novice stalker initialized: ", name)


func _handle_idle_state(delta):
	super._handle_idle_state(delta)


func _handle_chase_state(delta):
	var original_speed = speed
	speed = original_speed * 0.8
	super._handle_chase_state(delta)
	speed = original_speed
	
	if target and current_state == StalkerState.CHASE:
		var distance_to_target = global_position.distance_to(target.global_position)
		if distance_to_target < 1.5:
			_change_state(StalkerState.ATTACK)


func _handle_attack_state(delta):
	super._handle_attack_state(delta)
	
	if current_state == StalkerState.ATTACK and target:
		if randf() < 0.4:
			_change_state(StalkerState.FLEE)


func take_damage(amount: float, damage_type: String = "physical"):
	super.take_damage(amount, damage_type)
	
	if health < max_health * 0.5 and current_state != StalkerState.FLEE:
		if randf() < 0.6:
			_change_state(StalkerState.FLEE)


func _on_velocity_computed(safe_velocity):
	super._on_velocity_computed(safe_velocity)