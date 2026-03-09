# entities/mutants/pseudodog.gd
extends BaseMutant
class_name PseudodogMutant

@export_enum("Adult", "Grey", "PsyDog") var subspecies: String = "Adult"
@export var howl_cooldown: float = 15.0
@export var pack_attack_bonus: float = 1.5

var can_howl: bool = true
var howl_timer: Timer

func _ready():
	match subspecies:
		"Adult":
			health = 120.0
			max_health = 120.0
			speed = 7.0
			damage = 25.0
			armor = 10.0
			biomass_cost = 70.0
		"Grey":
			health = 80.0
			max_health = 80.0
			speed = 9.0
			damage = 15.0
			armor = 5.0
			biomass_cost = 50.0
		"PsyDog":
			health = 60.0
			max_health = 60.0
			speed = 8.0
			damage = 20.0
			armor = 0.0
			biomass_cost = 90.0
	
	mutant_type = "pseudodog"
	
	super._ready()
	
	howl_timer = Timer.new()
	howl_timer.one_shot = true
	howl_timer.timeout.connect(_on_howl_cooldown_ended)
	add_child(howl_timer)
	
	print("Pseudodog mutant initialized: ", subspecies)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if subspecies == "PsyDog":
		_psy_attempt()
	
	var nearby_packs = _count_nearby_pseudodogs()
	if nearby_packs > 0:
		speed = speed * (1.0 + nearby_packs * 0.1)
	
	super._physics_process(delta)


func _count_nearby_pseudodogs() -> int:
	var count = 0
	var mutants = get_tree().get_nodes_in_group("mutants")
	
	for mutant in mutants:
		if mutant == self:
			continue
		if mutant is PseudodogMutant and global_position.distance_to(mutant.global_position) < 15.0:
			count += 1
	
	return count


func _psy_attempt():
	if not can_howl or current_state != State.CHASE:
		return
	
	if target_stalker and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < detection_radius and randf() < 0.1:
			_psy_howl()


func _psy_howl():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	can_howl = false
	
	if target_stalker.has_method("stun"):
		target_stalker.stun(2.0)
	
	if target_stalker.has_method("take_damage"):
		target_stalker.take_damage(damage * 0.5, self)
	
	howl_timer.wait_time = howl_cooldown
	howl_timer.start()


func _on_howl_cooldown_ended():
	can_howl = true


func _chase(delta):
	super._chase(delta)
	
	if target_stalker and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < 5.0 and current_state == State.CHASE:
			_flank_target()


func _flank_target():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	var to_target = (target_stalker.global_position - global_position).normalized()
	var right = Vector3(to_target.z, 0, -to_target.x)
	
	if randf() > 0.5:
		right = -right
	
	var flank_pos = target_stalker.global_position + right * 3.0
	var direction = (flank_pos - global_position).normalized()
	velocity = direction * speed


func _attack(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 2.5:
		current_state = State.CHASE
		return
	
	var nearby_packs = _count_nearby_pseudodogs()
	var total_damage = damage * (1.0 + nearby_packs * pack_attack_bonus * 0.2)
	
	if attack_timer.is_stopped():
		target_stalker.take_damage(total_damage, self)
		attacked_stalker.emit(target_stalker)
		attack_timer.start()


func take_damage(dmg: float, source = null):
	super.take_damage(dmg, source)


func die():
	print("Pseudodog: предсмертный вой!")
	super.die()