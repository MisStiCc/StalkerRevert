# entities/mutants/chimera.gd
extends BaseMutant
class_name ChimeraMutant

@export var is_night_only: bool = false
@export var leap_distance: float = 15.0
@export var leap_damage: float = 50.0
@export var secondary_head_damage: float = 10.0

var can_leap: bool = true
var leap_timer: Timer
var is_leaping: bool = false
var leap_target: Vector3
var leap_time: float = 0.0

func _ready():
	health = 250.0
	max_health = 250.0
	speed = 10.0
	damage = 30.0
	armor = 25.0
	biomass_cost = 200.0
	mutant_type = "chimera"
	
	super._ready()
	
	leap_timer = Timer.new()
	leap_timer.one_shot = true
	leap_timer.wait_time = 4.0
	leap_timer.timeout.connect(_on_leap_cooldown_ended)
	add_child(leap_timer)
	
	_setup_label()
	print("Chimera mutant initialized")


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if is_leaping:
		_handle_leap(delta)
		return
	
	super._physics_process(delta)


func _find_new_target():
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	var nearest = null
	var nearest_dist = INF
	
	for s in stalkers:
		if is_instance_valid(s):
			var dist = global_position.distance_to(s.global_position)
			if dist < detection_radius * 2 and dist < nearest_dist:
				nearest_dist = dist
				nearest = s
	
	if nearest:
		target_stalker = nearest
		current_state = State.CHASE


func _patrol(delta):
	_find_new_target()
	super._patrol(delta)


func _chase(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		_find_new_target()
		if not target_stalker:
			current_state = State.PATROL
			return
	
	var direction = (target_stalker.global_position - global_position).normalized()
	velocity = direction * speed
	
	if can_leap and not is_leaping:
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < leap_distance and dist > 5.0:
			_start_leap()
	
	if global_position.distance_to(target_stalker.global_position) < 2.5:
		current_state = State.ATTACK


func _start_leap():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	print("Chimera: прыгаю!")
	is_leaping = true
	can_leap = false
	leap_target = target_stalker.global_position
	leap_time = 0.0
	
	leap_timer.start()


func _handle_leap(delta):
	leap_time += delta
	
	if is_instance_valid(target_stalker):
		leap_target = target_stalker.global_position
	
	var direction = (leap_target - global_position).normalized()
	velocity = direction * speed * 3.0
	velocity.y = 8.0 - (leap_time * 2.0)
	
	move_and_slide()
	
	if is_on_floor() or global_position.distance_to(leap_target) < 2.0 or leap_time > 1.5:
		_land()


func _land():
	print("Chimera: приземлился!")
	is_leaping = false
	
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < 5.0:
				stalker.take_damage(leap_damage, self)
				attacked_stalker.emit(stalker)
	
	_find_new_target()


func _on_leap_cooldown_ended():
	can_leap = true


func _attack(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 3.0:
		current_state = State.CHASE
		return
	
	if attack_timer.is_stopped():
		target_stalker.take_damage(damage, self)
		
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(target_stalker):
			target_stalker.take_damage(secondary_head_damage, self)
			attacked_stalker.emit(target_stalker)
		
		attack_timer.start()
		print("Chimera атакует!")


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 3.5, 0)  # Выше, потому что химера большая
	label.font_size = 28
	label.outline_size = 2
	label.outline_modulate = Color.BLACK
	label.modulate = Color(0.8, 0.2, 0.8)  # фиолетовый
	label.text = "🦎 ХИМЕРА"
	add_child(label)