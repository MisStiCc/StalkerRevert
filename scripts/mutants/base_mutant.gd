extends CharacterBody3D

signal died(mutant)
signal attacked_stalker(stalker)
signal spotted_stalker(stalker)

# Общие параметры
@export var health: float = 100.0
@export var speed: float = 5.0
@export var damage: float = 20.0
@export var armor: float = 0.0
@export var detection_radius: float = 20.0
@export var attack_cooldown: float = 1.0
@export var biomass_cost: float = 50.0

# Состояния
enum State { PATROL, CHASE, ATTACK, DEAD }
var current_state: State = State.PATROL
var target_stalker = null
var patrol_points: Array = []
var current_patrol_index: int = 0

# Ноды
@onready var detection_area: Area3D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer

func _ready():
    if detection_area:
        detection_area.body_entered.connect(_on_stalker_detected)
        detection_area.body_exited.connect(_on_stalker_lost)
    
    attack_timer.wait_time = attack_cooldown
    attack_timer.timeout.connect(_try_attack)

func _on_stalker_detected(body):
    if body.has_method("take_damage"):
        target_stalker = body
        current_state = State.CHASE
        spotted_stalker.emit(body)

func _on_stalker_lost(body):
    if body == target_stalker:
        target_stalker = null
        current_state = State.PATROL

func _try_attack():
    if current_state == State.ATTACK and target_stalker and is_instance_valid(target_stalker):
        if target_stalker.has_method("take_damage"):
            target_stalker.take_damage(damage)
            attacked_stalker.emit(target_stalker)

func take_damage(dmg: float):
    var actual_damage = max(dmg - armor, 1.0)
    health -= actual_damage
    if health <= 0:
        die()

func die():
    current_state = State.DEAD
    died.emit(self)
    queue_free()
