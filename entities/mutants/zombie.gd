# entities/mutants/zombie.gd
extends BaseMutant
class_name ZombieMutant

@export var rage_threshold: float = 50.0
@export var grab_damage: float = 15.0
@export var infection_chance: float = 0.2

var accumulated_rage: float = 0.0
var is_raging: bool = false

func _ready():
	health = 180.0
	max_health = 180.0
	speed = 2.0
	damage = 10.0
	armor = 15.0
	biomass_cost = 30.0
	mutant_type = "zombie"
	
	super._ready()
	
	current_state = State.PATROL
	
	print("Zombie mutant initialized")


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if accumulated_rage > rage_threshold and not is_raging:
		_become_raging()
	
	if is_raging:
		speed = 4.0
	else:
		speed = 2.0
	
	super._physics_process(delta)


func _patrol(delta):
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	var nearest_stalker = null
	var nearest_dist = INF
	
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < detection_radius and dist < nearest_dist:
				nearest_dist = dist
				nearest_stalker = stalker
	
	if nearest_stalker:
		target_stalker = nearest_stalker
		current_state = State.CHASE
	
	super._patrol(delta)


func _chase(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var direction = (target_stalker.global_position - global_position).normalized()
	velocity = direction * speed
	
	if global_position.distance_to(target_stalker.global_position) < 1.5:
		current_state = State.ATTACK


func _attack(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 2.0:
		current_state = State.CHASE
		return
	
	if attack_timer.is_stopped():
		target_stalker.take_damage(damage, self)
		attacked_stalker.emit(target_stalker)
		
		if randf() < infection_chance:
			_try_infect(target_stalker)
		
		attack_timer.start()


func _try_infect(stalker: Node3D):
	if stalker.has_method("apply_infection"):
		stalker.apply_infection(10.0)
		print("Zombie: заразил сталкера!")


func _become_raging():
	print("Zombie: вхожу в ярость!")
	is_raging = true
	accumulated_rage = 0.0
	damage = 25.0


func take_damage(dmg: float, source = null):
	accumulated_rage += dmg
	
	if health < max_health:
		health += dmg * 0.1
	
	super.take_damage(dmg, source)