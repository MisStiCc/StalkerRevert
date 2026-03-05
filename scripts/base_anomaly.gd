extends Area3D
class_name BaseAnomaly

# Параметры аномалии
@export var anomaly_name: String = "Аномалия"
@export var damage_per_second: float = 10.0
@export var radius: float = 5.0
@export var color: Color = Color(1, 0, 0, 1)
@export var is_active: bool = true

# Сигналы
signal stalker_entered(stalker: Node3D)
signal stalker_exited(stalker: Node3D)
signal energy_consumed(amount: float)
signal collision_detected(body: Node3D)

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
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(damage_per_second)
				energy_consumed.emit(damage_per_second)

func deactivate():
	is_active = false

func activate():
	is_active = true

# Метод для проверки столкновений
func _check_collision(body: Node3D):
	if is_instance_valid(body) and body.has_method("take_damage"):
		collision_detected.emit(body)

# Метод для обновления визуального представления
func _update_visuals():
	# Визуальное обновление будет реализовано в дочерних классах
	pass

# Метод для нанесения урона
func _apply_damage():
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(damage_per_second)
				energy_consumed.emit(damage_per_second)