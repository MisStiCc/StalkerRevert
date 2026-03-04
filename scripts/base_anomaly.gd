extends Area3D
class_name BaseAnomaly

# Параметры аномалии
@export var damage_per_second: float = 10.0
@export var anomaly_name: String = "Аномалия"
@export var color: Color = Color(1, 0, 0, 1)

# Сигналы
signal stalker_entered(stalker: Node3D)
signal stalker_exited(stalker: Node3D)
signal energy_consumed(amount: float)

var active: bool = true
var stalkers_in_zone: Array[Node3D] = []
var damage_timer: Timer


func _ready():
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
	if not active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(damage_per_second)
				energy_consumed.emit(damage_per_second)


func deactivate():
	active = false


func activate():
	active = true