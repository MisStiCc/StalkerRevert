# entities/mutants/pseudodog.gd
extends BaseMutant
class_name PseudodogMutant

@export_enum("Adult", "Grey", "PsyDog") var subspecies: String = "Adult"
@export var howl_cooldown: float = 15.0
@export var pack_attack_bonus: float = 1.5

var can_howl: bool = true
var howl_timer: Timer
var pack_count: int = 0

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
	howl_timer.wait_time = howl_cooldown
	howl_timer.timeout.connect(_on_howl_cooldown_ended)
	add_child(howl_timer)
	
	_setup_label()
	print("Pseudodog mutant initialized: ", subspecies)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	_update_pack_bonus()
	
	if subspecies == "PsyDog" and can_howl and current_state == State.CHASE:
		_try_psy_howl()
	
	super._physics_process(delta)


func _update_pack_bonus():
	pack_count = _count_nearby_pseudodogs()
	if pack_count > 0:
		var original_speed = speed
		speed = original_speed * (1.0 + pack_count * 0.1)
		# Скорость восстановится в следующем кадре через super._physics_process


func _count_nearby_pseudodogs() -> int:
	var count = 0
	var mutants = get_tree().get_nodes_in_group("mutants")
	
	for mutant in mutants:
		if mutant == self or not is_instance_valid(mutant):
			continue
		if mutant is PseudodogMutant and global_position.distance_to(mutant.global_position) < 15.0:
			count += 1
	
	return count


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
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist < 2.0:
		current_state = State.ATTACK
	elif dist < 5.0 and randf() < 0.01:
		_flank_target()


func _flank_target():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	var to_target = (target_stalker.global_position - global_position).normalized()
	var right = Vector3(to_target.z, 0, -to_target.x).normalized()
	
	if randf() > 0.5:
		right = -right
	
	var flank_dir = (to_target + right * 0.5).normalized()
	velocity = flank_dir * speed
	print("Pseudodog фланкирует!")


func _try_psy_howl():
	if not target_stalker or not is_instance_valid(target_stalker) or randf() > 0.05:
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist < detection_radius:
		_psy_howl()


func _psy_howl():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	print("Pseudodog использует пси-вой!")
	can_howl = false
	
	if target_stalker.has_method("stun"):
		target_stalker.stun(2.0)
	
	target_stalker.take_damage(damage * 0.5, self)
	
	howl_timer.start()


func _on_howl_cooldown_ended():
	can_howl = true


func _attack(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 2.0:
		current_state = State.CHASE
		return
	
	var total_damage = damage * (1.0 + pack_count * pack_attack_bonus * 0.2)
	
	if attack_timer.is_stopped():
		target_stalker.take_damage(total_damage, self)
		attacked_stalker.emit(target_stalker)
		attack_timer.start()
		print("Pseudodog атакует! Урон: ", total_damage)


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 2.5, 0)
	label.font_size = 24
	label.outline_size = 2
	label.outline_modulate = Color.BLACK
	label.modulate = Color(0.6, 0.4, 0.2)  # коричневый
	label.text = "🐺 ПСЕВДОСОБАКА"
	add_child(label)