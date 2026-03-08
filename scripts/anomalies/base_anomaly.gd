extends Area3D
class_name BaseAnomaly

@export var anomaly_type: String = "base"
@export var damage_per_second: float = 10.0
@export var is_active: bool = true

@export var difficulty_level: int = 1
@export var health: float = 100.0
@export var max_health: float = 100.0

signal stalker_entered(stalker: Node3D)
signal stalker_exited(stalker: Node3D)
signal energy_consumed(amount: float)
signal destroyed(anomaly_type: String, position: Vector3, difficulty: int)
signal damaged(amount: float, current_health: float)

var stalkers_in_zone: Array[Node3D] = []
var damage_timer: Timer
var _is_dying: bool = false


func _ready():
	max_health = health
	add_to_group("anomalies")
	
	damage_timer = Timer.new()
	damage_timer.wait_time = 1.0
	damage_timer.timeout.connect(_apply_damage)
	add_child(damage_timer)
	damage_timer.start()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D):
	if body.has_method("take_damage") and not body in stalkers_in_zone:
		stalkers_in_zone.append(body)
		stalker_entered.emit(body)


func _on_body_exited(body: Node3D):
	if body in stalkers_in_zone:
		stalkers_in_zone.erase(body)
		stalker_exited.emit(body)


func _apply_damage():
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(damage_per_second)
				energy_consumed.emit(damage_per_second)


func take_damage(amount: float, _attacker = null):
	if _is_dying:
		return
	
	health -= amount
	damaged.emit(amount, health)
	
	if health <= 0:
		_destroy()


func _destroy():
	if _is_dying:
		return
	_is_dying = true
	
	destroyed.emit(anomaly_type, global_position, difficulty_level)
	queue_free()


func set_difficulty(difficulty: int):
	difficulty_level = difficulty
	health = 100.0 * difficulty
	max_health = health


func deactivate():
	is_active = false


func activate():
	is_active = true


func get_anomaly_info() -> Dictionary:
	return {
		"type": anomaly_type,
		"difficulty": difficulty_level,
		"health": health,
		"max_health": max_health
	}
