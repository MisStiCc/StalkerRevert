# entities/mutants/pseudogiant.gd
extends BaseMutant
class_name PseudogiantMutant

@export var ground_stomp_force: float = 30.0
@export var shockwave_radius: float = 10.0
@export var shockwave_damage: float = 40.0
@export var stomp_cooldown: float = 5.0

var can_stomp: bool = true
var stomp_timer: Timer
var is_stomping: bool = false

func _ready():
	health = 400.0
	max_health = 400.0
	speed = 2.5
	damage = 45.0
	armor = 40.0
	biomass_cost = 250.0
	detection_radius = 30.0
	mutant_type = "pseudogiant"
	
	super._ready()
	
	stomp_timer = Timer.new()
	stomp_timer.one_shot = true
	stomp_timer.timeout.connect(_on_stomp_cooldown_ended)
	add_child(stomp_timer)
	
	print("Pseudogiant mutant initialized")


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if is_stomping:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	if can_stomp and target_stalker and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < shockwave_radius * 1.5 and current_state == State.CHASE:
			_ground_stomp()
	
	super._physics_process(delta)


func _chase(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var direction = (target_stalker.global_position - global_position).normalized()
	velocity = direction * speed
	
	if global_position.distance_to(target_stalker.global_position) < 2.5:
		current_state = State.ATTACK


func _ground_stomp():
	print("Pseudogiant: удар по земле!")
	is_stomping = true
	can_stomp = false
	
	await get_tree().create_timer(0.5).timeout
	
	_create_shockwave()
	
	await get_tree().create_timer(0.5).timeout
	is_stomping = false
	
	stomp_timer.wait_time = stomp_cooldown
	stomp_timer.start()


func _create_shockwave():
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < shockwave_radius:
				var damage_mult = 1.0 - (dist / shockwave_radius)
				var final_damage = shockwave_damage * damage_mult
				
				if stalker.has_method("take_damage"):
					stalker.take_damage(final_damage, self)
					attacked_stalker.emit(stalker)
				
				if stalker.has_method("stun"):
					stalker.stun(1.0 * damage_mult)
	
	_create_stomp_visuals()


func _create_stomp_visuals():
	var shockwave = MeshInstance3D.new()
	shockwave.mesh = TorusMesh.new()
	shockwave.mesh.inner_radius = 0.1
	shockwave.mesh.outer_radius = 0.5
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.6, 0.4)
	material.emission = Color(0.6, 0.4, 0.2)
	material.emission_energy = 2.0
	shockwave.material_override = material
	
	shockwave.global_position = global_position
	shockwave.global_position.y = 0.1
	get_tree().current_scene.add_child(shockwave)
	
	var tween = create_tween()
	tween.tween_property(shockwave, "scale", Vector3(shockwave_radius * 2, 1, shockwave_radius * 2), 0.5)
	tween.tween_property(shockwave, "material_override:albedo_color:a", 0.0, 0.5)
	
	await tween.finished
	if is_instance_valid(shockwave):
		shockwave.queue_free()


func _on_stomp_cooldown_ended():
	can_stomp = true


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
		attacked_stalker.emit(target_stalker)
		
		if randf() < 0.3 and target_stalker.has_method("stun"):
			target_stalker.stun(0.5)
		
		attack_timer.start()


func take_damage(dmg: float, source = null):
	super.take_damage(dmg * 0.5, source)