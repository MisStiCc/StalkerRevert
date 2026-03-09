# entities/mutants/bloodsucker.gd
extends BaseMutant
class_name BloodsuckerMutant

@export_enum("Underground", "Swamp", "NightKing") var subspecies: String = "Underground"
@export var invisibility_duration: float = 5.0
@export var invisibility_cooldown: float = 10.0
@export var ambush_range: float = 8.0
@export var leap_damage: float = 40.0

var is_invisible: bool = false
var can_go_invisible: bool = true
var invisibility_timer: Timer
var leap_timer: Timer

func _ready():
	match subspecies:
		"Underground":
			health = 80.0
			max_health = 80.0
			speed = 7.0
			damage = 25.0
			armor = 5.0
			biomass_cost = 80.0
		"Swamp":
			health = 100.0
			max_health = 100.0
			speed = 6.0
			damage = 30.0
			armor = 8.0
			biomass_cost = 100.0
		"NightKing":
			health = 150.0
			max_health = 150.0
			speed = 9.0
			damage = 40.0
			armor = 15.0
			biomass_cost = 150.0
	
	mutant_type = "bloodsucker"
	
	super._ready()
	
	invisibility_timer = Timer.new()
	invisibility_timer.one_shot = true
	invisibility_timer.timeout.connect(_on_invisibility_ended)
	add_child(invisibility_timer)
	
	leap_timer = Timer.new()
	leap_timer.one_shot = true
	leap_timer.wait_time = 2.0
	leap_timer.timeout.connect(_on_leap_ended)
	add_child(leap_timer)
	
	print("Bloodsucker mutant initialized: ", subspecies)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if can_go_invisible and not is_invisible and current_state == State.PATROL:
		_try_go_invisible()
	
	_update_invisibility_visuals()
	
	super._physics_process(delta)


func _try_go_invisible():
	if not can_go_invisible:
		return
	
	is_invisible = true
	can_go_invisible = false
	
	invisibility_timer.wait_time = invisibility_duration
	invisibility_timer.start()
	
	print("Bloodsucker: стал невидимым!")


func _on_invisibility_ended():
	is_invisible = false
	
	await get_tree().create_timer(invisibility_cooldown).timeout
	can_go_invisible = true


func _update_invisibility_visuals():
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = not is_invisible


func _chase(delta):
	super._chase(delta)
	
	if is_invisible and target_stalker and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < ambush_range:
			_ambush_attack()


func _ambush_attack():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	print("Bloodsucker: атакую из засады!")
	
	is_invisible = false
	invisibility_timer.stop()
	
	var direction = (target_stalker.global_position - global_position).normalized()
	var leap_target = target_stalker.global_position
	
	velocity = direction * speed * 2.0
	velocity.y = 5.0
	
	if target_stalker.has_method("take_damage"):
		target_stalker.take_damage(leap_damage, self)
		attacked_stalker.emit(target_stalker)
	
	leap_timer.start()


func _on_leap_ended():
	pass


func _attack(delta):
	if target_stalker and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist > 3.0:
			current_state = State.CHASE
		else:
			if attack_timer.is_stopped():
				target_stalker.take_damage(damage, self)
				attacked_stalker.emit(target_stalker)
				attack_timer.start()


func take_damage(dmg: float, source = null):
	if not is_invisible:
		dmg *= 1.5
	
	super.take_damage(dmg, source)
	
	if is_invisible:
		is_invisible = false
		invisibility_timer.stop()


func die():
	if is_invisible:
		is_invisible = false
	
	super.die()