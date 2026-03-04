extends Area2D

signal stalker_entered(stalker)
signal stalker_exited(stalker)
signal energy_consumed(amount)

# Параметры аномалии
@export var damage_per_second: float = 10.0
@export var energy_cost_per_second: float = 2.0
@export var anomaly_name: String = "Жарка"
@export var color: Color = Color(1, 0.3, 0)

# Внутренние переменные
var active: bool = true
var stalkers_in_zone: Array = []
var damage_timer: Timer

func _ready():
    if has_node("Sprite2D"):
        $Sprite2D.modulate = color
    
    damage_timer = Timer.new()
    damage_timer.wait_time = 1.0
    damage_timer.timeout.connect(_apply_damage)
    add_child(damage_timer)
    damage_timer.start()
    
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body):
    if body.has_method("take_damage"):
        if not body in stalkers_in_zone:
            stalkers_in_zone.append(body)
            stalker_entered.emit(body)

func _on_body_exited(body):
    if body in stalkers_in_zone:
        stalkers_in_zone.erase(body)
        stalker_exited.emit(body)

func _apply_damage():
    if not active:
        return
    
    for stalker in stalkers_in_zone:
        if is_instance_valid(stalker):
            stalker.take_damage(damage_per_second)
    
    energy_consumed.emit(energy_cost_per_second)

func deactivate():
    active = false

func activate():
    active = true
