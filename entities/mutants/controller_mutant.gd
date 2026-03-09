# entities/mutants/controller_mutant.gd
extends BaseMutant
class_name ControllerMutant

@export var control_range: float = 15.0
@export var control_duration: float = 5.0
@export var control_cooldown: float = 10.0

var control_timer: Timer
var is_controlling: bool = false


func _ready():
	health = 80.0
	max_health = 80.0
	speed = 4.0
	damage = 0.0
	armor = 10.0
	biomass_cost = 100.0
	mutant_type = "controller"
	
	super._ready()
	
	control_timer = Timer.new()
	control_timer.one_shot = true
	control_timer.timeout.connect(_on_control_ended)
	add_child(control_timer)
	
	print("Controller mutant initialized")


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if is_controlling:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	super._physics_process(delta)


func _chase(delta):
	super._chase(delta)
	
	if target_stalker and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < control_range and not is_controlling and control_timer.is_stopped():
			_try_control_stalker()


func _try_control_stalker():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	if target_stalker.has_method("is_controllable") and not target_stalker.is_controllable():
		return
	
	is_controlling = true
	current_state = State.ATTACK
	
	_apply_control_effect(target_stalker)
	
	control_timer.wait_time = control_duration
	control_timer.start()


func _apply_control_effect(stalker: Node3D):
	if stalker.has_method("set_controlled"):
		stalker.set_controlled(true, self)


func _on_control_ended():
	if not target_stalker or not is_instance_valid(target_stalker):
		is_controlling = false
		current_state = State.PATROL
		return
	
	if target_stalker.has_method("set_controlled"):
		target_stalker.set_controlled(false, self)
	
	is_controlling = false
	current_state = State.CHASE


func take_damage(dmg: float, source = null):
	if is_controlling:
		_on_control_ended()
	
	super.take_damage(dmg, source)


func die():
	if is_controlling:
		_on_control_ended()
	
	super.die()