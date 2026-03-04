extends BaseStalker
# class_name VeteranStalker  # ← закомментировал

# Параметры ветерана-сталкера
@export var veteran_health: float = 120.0
@export var veteran_speed: float = 5.5
@export var veteran_damage: float = 15.0


func _ready():
	health = veteran_health
	max_health = veteran_health
	speed = veteran_speed
	damage = veteran_damage
	
	super._ready()
	
	stalker_type = "veteran"
	
	print("Veteran stalker initialized: ", name)


func _handle_idle_state(delta):
	super._handle_idle_state(delta)


func _handle_chase_state(delta):
	var original_speed = speed
	speed = original_speed * 1.1
	super._handle_chase_state(delta)
	speed = original_speed
	
	if target and current_state == StalkerState.CHASE:
		var distance_to_target = global_position.distance_to(target.global_position)
		if distance_to_target < 2.5:
			_change_state(StalkerState.ATTACK)


func _handle_attack_state(delta):
	super._handle_attack_state(delta)
	
	if current_state == StalkerState.ATTACK and target:
		if randf() < 0.2:
			_change_state(StalkerState.FLEE)


func take_damage(amount: float, damage_type: String = "physical"):
	super.take_damage(amount, damage_type)
	
	if health < max_health * 0.3 and current_state != StalkerState.FLEE:
		if randf() < 0.3:
			_change_state(StalkerState.FLEE)
	
	if health < max_health * 0.5 and current_state == StalkerState.FLEE:
		if randf() < 0.4:
			_change_state(StalkerState.CHASE)


func _on_velocity_computed(safe_velocity):
	super._on_velocity_computed(safe_velocity)