# entities/mutants/flesh.gd
extends BaseMutant
class_name FleshMutant

@export var aggression_threshold: float = 30.0
@export var charge_speed: float = 12.0
@export var charge_damage: float = 35.0
@export var charge_cooldown: float = 5.0

var accumulated_damage: float = 0.0
var can_charge: bool = true
var is_charging: bool = false
var charge_target: Vector3
var charge_timer: Timer

func _ready():
	health = 200.0
	max_health = 200.0
	speed = 4.0
	damage = 15.0
	armor = 20.0
	biomass_cost = 60.0
	mutant_type = "flesh"
	
	super._ready()
	
	current_state = State.PATROL
	
	charge_timer = Timer.new()
	charge_timer.one_shot = true
	charge_timer.timeout.connect(_on_charge_cooldown_ended)
	add_child(charge_timer)
	
	print("Flesh mutant initialized")


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if accumulated_damage > aggression_threshold and current_state == State.PATROL:
		_become_aggressive()
	
	if is_charging:
		_handle_charge(delta)
		return
	
	super._physics_process(delta)


func _patrol(delta):
	if target_stalker and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < 3.0:
			_become_aggressive()
	
	super._patrol(delta)


func _become_aggressive():
	current_state = State.CHASE
	accumulated_damage = 0.0
	
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	var nearest_stalker = null
	var nearest_dist = INF
	
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_stalker = stalker
	
	if nearest_stalker:
		target_stalker = nearest_stalker


func _chase(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		accumulated_damage = 0.0
		return
	
	var direction = (target_stalker.global_position - global_position).normalized()
	velocity = direction * speed
	
	if can_charge and not is_charging:
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < 10.0 and dist > 4.0:
			_start_charge()
	
	if global_position.distance_to(target_stalker.global_position) < 2.0:
		current_state = State.ATTACK


func _start_charge():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	is_charging = true
	can_charge = false
	charge_target = target_stalker.global_position
	
	charge_timer.wait_time = charge_cooldown
	charge_timer.start()


func _handle_charge(delta):
	var direction = (charge_target - global_position).normalized()
	velocity = direction * charge_speed
	velocity.y = 3.0
	
	move_and_slide()
	
	if global_position.distance_to(charge_target) < 2.0 or is_on_wall():
		_end_charge()


func _end_charge():
	is_charging = false
	velocity = Vector3.ZERO
	
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < 4.0:
				if stalker.has_method("take_damage"):
					stalker.take_damage(charge_damage, self)
					attacked_stalker.emit(stalker)
	
	if target_stalker and is_instance_valid(target_stalker):
		current_state = State.CHASE
	else:
		current_state = State.PATROL


func _on_charge_cooldown_ended():
	can_charge = true


func _attack(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 2.5:
		current_state = State.CHASE
		return
	
	if attack_timer.is_stopped():
		target_stalker.take_damage(damage, self)
		attacked_stalker.emit(target_stalker)
		attack_timer.start()


func take_damage(dmg: float, source = null):
	accumulated_damage += dmg
	super.take_damage(dmg, source)