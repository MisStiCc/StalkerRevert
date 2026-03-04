extends CharacterBody2D

signal died(mutant)
signal attacked_stalker(stalker)
signal spotted_stalker(stalker)

@export var health: float = 100.0
@export var speed: float = 100.0
@export var damage: float = 20.0
@export var armor: float = 0.0
@export var detection_radius: float = 300.0
@export var attack_cooldown: float = 1.5
@export var biomass_cost: float = 50.0
@export var chase_distance: float = 500.0  # дальность преследования

enum State { IDLE, PATROL, CHASE, ATTACK, RETURN, DEAD }
var current_state: State = State.PATROL
var target_stalker = null
var start_position: Vector2  # исходная позиция (для возврата)

@onready var detection_area: Area2D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

func _ready():
    start_position = global_position
    
    # Настройка области обнаружения
    if detection_area:
        detection_area.body_entered.connect(_on_stalker_detected)
        detection_area.body_exited.connect(_on_stalker_lost)
    
    # Таймер атаки
    attack_timer.wait_time = attack_cooldown
    attack_timer.timeout.connect(_try_attack)
    
    # Таймер обновления пути
    var update_timer = Timer.new()
    update_timer.wait_time = 0.5
    update_timer.timeout.connect(_update_pathfinding)
    add_child(update_timer)
    update_timer.start()

func _physics_process(delta):
    if current_state == State.DEAD:
        return
    
    # Обработка состояний
    match current_state:
        State.PATROL:
            _patrol(delta)
        State.CHASE:
            _chase(delta)
        State.ATTACK:
            _attack(delta)
        State.RETURN:
            _return_to_start(delta)

func _on_stalker_detected(body):
    if body.has_method("take_damage") and body.has_method("is_stalker"):
        if current_state != State.ATTACK and target_stalker == null:
            target_stalker = body
            current_state = State.CHASE
            spotted_stalker.emit(body)

func _on_stalker_lost(body):
    if body == target_stalker:
        # Сталкер вышел из зоны видимости, но может быть ещё рядом
        # Проверим расстояние
        var dist = global_position.distance_to(target_stalker.global_position)
        if dist > detection_radius * 1.5:
            target_stalker = null
            current_state = State.RETURN

func _update_pathfinding():
    if current_state == State.CHASE and target_stalker and is_instance_valid(target_stalker):
        navigation_agent.target_position = target_stalker.global_position
    elif current_state == State.RETURN:
        navigation_agent.target_position = start_position

func _chase(delta):
    if not target_stalker or not is_instance_valid(target_stalker):
        current_state = State.RETURN
        return
    
    var dist = global_position.distance_to(target_stalker.global_position)
    
    # Если близко к сталкеру — переходим в атаку
    if dist < 50.0:
        current_state = State.ATTACK
        attack_timer.start()  # сразу начинаем атаку
        return
    
    # Если сталкер ушёл слишком далеко — возвращаемся
    if dist > chase_distance:
        current_state = State.RETURN
        return
    
    # Двигаемся к сталкеру
    if navigation_agent.is_navigation_finished():
        return
    
    var next_pos = navigation_agent.get_next_path_position()
    var direction = (next_pos - global_position).normalized()
    velocity = direction * speed
    move_and_slide()

func _attack(delta):
    if not target_stalker or not is_instance_valid(target_stalker):
        current_state = State.RETURN
        return
    
    var dist = global_position.distance_to(target_stalker.global_position)
    
    # Если сталкер убежал — снова преследуем
    if dist > 70.0:
        current_state = State.CHASE
        return
    
    # Поворачиваемся к сталкеру
    var direction = (target_stalker.global_position - global_position).normalized()
    # Атака происходит по таймеру

func _try_attack():
    if current_state == State.ATTACK and target_stalker and is_instance_valid(target_stalker):
        var dist = global_position.distance_to(target_stalker.global_position)
        if dist < 70.0:
            if target_stalker.has_method("take_damage"):
                target_stalker.take_damage(damage)
                attacked_stalker.emit(target_stalker)

func _return_to_start(delta):
    var dist = global_position.distance_to(start_position)
    
    if dist < 20.0:
        # Вернулись на базу
        current_state = State.PATROL
        return
    
    if navigation_agent.is_navigation_finished():
        return
    
    var next_pos = navigation_agent.get_next_path_position()
    var direction = (next_pos - global_position).normalized()
    velocity = direction * speed
    move_and_slide()

func _patrol(delta):
    # Простое патрулирование вокруг стартовой точки
    # TODO: добавить точки патруля
    pass

func take_damage(dmg: float):
    var actual_damage = max(dmg - armor, 1.0)
    health -= actual_damage
    if health <= 0:
        die()

func die():
    current_state = State.DEAD
    died.emit(self)
    queue_free()

# Метод для ZoneController (стоимость)
func get_biomass_cost() -> int:
    return biomass_cost

# Для совместимости со сталкерскими проверками
func is_stalker():
    return false