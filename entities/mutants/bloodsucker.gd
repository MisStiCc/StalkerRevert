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
var mesh_instance: MeshInstance3D

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
	
	mesh_instance = $MeshInstance3D
	
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
	
	_setup_label()
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
	
	print("Bloodsucker стал невидимым!")


func _on_invisibility_ended():
	is_invisible = false
	print("Bloodsucker стал видимым")
	
	await get_tree().create_timer(invisibility_cooldown).timeout
	can_go_invisible = true


func _update_invisibility_visuals():
	if not mesh_instance:
		return
	
	var alpha = 0.2 if is_invisible else 1.0
	if mesh_instance.material_override:
		mesh_instance.material_override.albedo_color.a = alpha


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
	
	if is_invisible and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < ambush_range:
			_ambush_attack()
	
	if global_position.distance_to(target_stalker.global_position) < 2.0:
		current_state = State.ATTACK


func _ambush_attack():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	print("Bloodsucker атакует из засады!")
	is_invisible = false
	invisibility_timer.stop()
	
	var direction = (target_stalker.global_position - global_position).normalized()
	velocity = direction * speed * 2.0
	velocity.y = 2.0
	
	target_stalker.take_damage(leap_damage, self)
	attacked_stalker.emit(target_stalker)
	
	leap_timer.start()


func _on_leap_ended():
	pass


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
		attack_timer.start()
		print("Bloodsucker атакует!")


func take_damage(dmg: float, source = null):
	if not is_invisible:
		dmg *= 1.5
	
	if is_invisible:
		is_invisible = false
		invisibility_timer.stop()
		print("Bloodsucker стал видимым из-за урона")
	
	super.take_damage(dmg, source)


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 2.5, 0)
	label.font_size = 24
	label.outline_size = 2
	label.outline_modulate = Color.BLACK
	label.modulate = Color(1.0, 0.2, 0.2)  # красный
	label.text = "🩸 КРОВОСОС"
	add_child(label)