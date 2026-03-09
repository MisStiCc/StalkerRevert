# entities/mutants/dog_mutant.gd
extends BaseMutant
class_name DogMutant

@export var pack_bonus: float = 1.2
@export var dodge_chance: float = 0.3

func _ready():
	health = 50.0
	max_health = 50.0
	speed = 8.0
	damage = 8.0
	armor = 0.0
	biomass_cost = 30.0
	mutant_type = "dog"
	
	super._ready()
	
	print("Dog mutant initialized")


func _physics_process(delta):
	var nearby_dogs = _count_nearby_dogs()
	if nearby_dogs > 0:
		var original_speed = speed
		speed = original_speed * (1.0 + (nearby_dogs * 0.1))
		super._physics_process(delta)
		speed = original_speed
	else:
		super._physics_process(delta)


func _count_nearby_dogs() -> int:
	var count = 0
	var mutants = get_tree().get_nodes_in_group("mutants")
	
	for mutant in mutants:
		if mutant == self:
			continue
		if mutant is DogMutant and global_position.distance_to(mutant.global_position) < 10.0:
			count += 1
	
	return count


func take_damage(dmg: float, source = null):
	if randf() < dodge_chance:
		return
	
	super.take_damage(dmg, source)


func _chase(delta):
	super._chase(delta)
	
	if target_stalker and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < 3.0 and current_state == State.CHASE:
			_try_flank()


func _try_flank():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	var to_target = (target_stalker.global_position - global_position).normalized()
	var right = Vector3(to_target.z, 0, -to_target.x)
	
	var flank_position = target_stalker.global_position + right * 2.0
	var direction = (flank_position - global_position).normalized()
	velocity = direction * speed