# components/state_machine_component.gd
extends Node
class_name StateMachineComponent

## Компонент конечного автомата - управляет состояниями сталкера

signal state_changed(old_state: GameEnums.StalkerState, new_state: GameEnums.StalkerState)
signal state_entered(state: GameEnums.StalkerState)
signal state_exited(state: GameEnums.StalkerState)

# Владелец
var stalker: BaseStalker

# Текущее состояние
var current_state: GameEnums.StalkerState = GameEnums.StalkerState.PATROL:
    set(value):
        if current_state != value:
            var old = current_state
            current_state = value
            state_changed.emit(old, value)
            _on_state_entered(value)

# Предыдущее состояние
var previous_state: GameEnums.StalkerState = GameEnums.StalkerState.PATROL

# Зависимости
var behavior_strategy: StalkerBehaviorStrategy
var navigation: NavigationComponent
var memory: MemoryComponent
var carry: CarryComponent
var health: HealthComponent
var monolith: Node

# Таймеры состояний
var state_timers: Dictionary = {}  # state -> time_in_state
var current_state_time: float = 0.0

# Флаги
var can_transition: bool = true
var debug_mode: bool = false


func _ready():
    set_process(true)
    set_physics_process(true)
    print("StateMachineComponent инициализирован", "StateMachine")


func setup(deps: Dictionary):
    behavior_strategy = deps.get("behavior")
    navigation = deps.get("navigation")
    memory = deps.get("memory")
    carry = deps.get("carry")
    health = deps.get("health")
    monolith = deps.get("monolith")
    
    if behavior_strategy:
        print("Поведение установлено: " + str(behavior_strategy), "StateMachine")
    else:
        print("Поведение не установлено", "StateMachine")


func _process(delta):
    if not stalker or not stalker.is_alive:
        return
    
    current_state_time += delta
    
    # Обработка текущего состояния
    match current_state:
        GameEnums.StalkerState.IDLE:
            _process_idle(delta)
        GameEnums.StalkerState.PATROL:
            _process_patrol(delta)
        GameEnums.StalkerState.SEEK_ARTIFACT:
            _process_seek_artifact(delta)
        GameEnums.StalkerState.SEEK_MONOLITH:
            _process_seek_monolith(delta)
        GameEnums.StalkerState.FLEE:
            _process_flee(delta)
        GameEnums.StalkerState.ATTACK_ANOMALY:
            _process_attack_anomaly(delta)
        GameEnums.StalkerState.ATTACK_MUTANT:
            _process_attack_mutant(delta)
        GameEnums.StalkerState.CARRY_ARTIFACT:
            _process_carry_artifact(delta)
    
    # Проверка переходов
    _check_transitions()


func _physics_process(delta):
    if not stalker or not stalker.is_alive:
        return
    
    # Физическая логика для состояний
    match current_state:
        GameEnums.StalkerState.SEEK_ARTIFACT, GameEnums.StalkerState.SEEK_MONOLITH, GameEnums.StalkerState.CARRY_ARTIFACT:
            if navigation and navigation.is_navigating():
                navigation._physics_process(delta)


# ==================== ОБРАБОТЧИКИ СОСТОЯНИЙ ====================

func _process_idle(_delta):
    # Просто стоим, ждем
    if current_state_time > 2.0:
        set_state(GameEnums.StalkerState.PATROL)
        print("IDLE -> PATROL (таймаут)", "StateMachine")


func _process_patrol(_delta):
    if navigation and not navigation.is_navigating():
        # Если не двигаемся, ищем новую точку
        var random_pos = stalker.global_position + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
        navigation.move_to(random_pos)


func _process_seek_artifact(_delta):
    if not navigation or not navigation.is_navigating():
        # Если дошли до цели, но артефакта нет - ищем новый
        if memory and memory.has_artifacts():
            var target = memory.get_nearest_artifact()
            if target:
                navigation.move_to(target.global_position)


func _process_seek_monolith(_delta):
    if not navigation or not navigation.is_navigating():
        if monolith:
            navigation.move_to(monolith.global_position)


func _process_flee(_delta):
    if not navigation or not navigation.is_navigating():
        # Если не двигаемся, проверяем опасность
        if memory and memory.has_threats():
            var threat = memory.get_nearest_threat()
            if threat:
                var flee_dir = (stalker.global_position - threat.global_position).normalized()
                navigation.move_to(stalker.global_position + flee_dir * 30)


func _process_attack_anomaly(_delta):
    if navigation and navigation.is_navigating():
        var target = _get_attack_target()
        if target:
            var dist = stalker.global_position.distance_to(target.global_position)
            if dist < 5.0:
                # Атакуем
                if target.has_method("take_damage"):
                    target.take_damage(health.get_damage() if health else 10.0, stalker)


func _process_attack_mutant(_delta):
    if navigation and navigation.is_navigating():
        var target = _get_attack_target()
        if target:
            var dist = stalker.global_position.distance_to(target.global_position)
            if dist < 3.0:
                # Атакуем
                if target.has_method("take_damage"):
                    target.take_damage(health.get_damage() if health else 15.0, stalker)


func _process_carry_artifact(_delta):
    if carry and carry.has_artifact():
        # Идем к краю карты
        var edge_pos = _get_edge_position()
        if navigation:
            navigation.move_to(edge_pos)
        
        # Проверяем, дошли ли
        if navigation and navigation.get_distance_to_target() < 5.0:
            carry.steal_artifact()
            set_state(GameEnums.StalkerState.SEEK_MONOLITH)


# ==================== ЛОГИКА ПЕРЕХОДОВ ====================

func _check_transitions():
    if not can_transition:
        return
    
    # 1. Проверка на смерть
    if health and not health.is_alive:
        return
    
    # 2. Если несем артефакт
    if carry and carry.has_artifact():
        if current_state != GameEnums.StalkerState.CARRY_ARTIFACT:
            set_state(GameEnums.StalkerState.CARRY_ARTIFACT)
        return
    
    # 3. Проверка опасностей
    if memory:
        var nearest_threat = memory.get_nearest_threat()
        if nearest_threat:
            if behavior_strategy and behavior_strategy.should_flee_from(nearest_threat):
                if current_state != GameEnums.StalkerState.FLEE:
                    set_state(GameEnums.StalkerState.FLEE)
                    if navigation:
                        var flee_dir = (stalker.global_position - nearest_threat.global_position).normalized()
                        navigation.move_to(stalker.global_position + flee_dir * 30)
                return
            elif behavior_strategy and behavior_strategy.should_attack(nearest_threat):
                var target_state = GameEnums.StalkerState.ATTACK_ANOMALY
                if nearest_threat.is_in_group("mutants"):
                    target_state = GameEnums.StalkerState.ATTACK_MUTANT
                
                if current_state != target_state:
                    set_state(target_state)
                    if navigation:
                        navigation.move_to(nearest_threat.global_position)
                return
    
    # 4. Поиск артефактов
    if memory and memory.has_artifacts() and behavior_strategy and behavior_strategy.prefers_artifacts():
        if current_state != GameEnums.StalkerState.SEEK_ARTIFACT:
            set_state(GameEnums.StalkerState.SEEK_ARTIFACT)
            if navigation:
                var target = memory.get_nearest_artifact()
                if target:
                    navigation.move_to(target.global_position)
        return
    
    # 5. Идем к монолиту (по умолчанию)
    if current_state not in [GameEnums.StalkerState.SEEK_MONOLITH, GameEnums.StalkerState.PATROL]:
        set_state(GameEnums.StalkerState.SEEK_MONOLITH)
        if navigation and monolith:
            navigation.move_to(monolith.global_position)


func _on_state_entered(state: GameEnums.StalkerState):
    current_state_time = 0.0
    state_entered.emit(state)
    
    if debug_mode:
        print("Вход в состояние: " + _get_state_name(state), "StateMachine")
    
    match state:
        GameEnums.StalkerState.IDLE:
            if navigation:
                navigation.stop()
        
        GameEnums.StalkerState.PATROL:
            if navigation:
                navigation.set_patrol_points(_generate_patrol_points())
        
        GameEnums.StalkerState.FLEE:
            if navigation:
                navigation.set_speed(stalker.move_speed * 1.3 if stalker else 5.0)


func _on_state_exited(state: GameEnums.StalkerState):
    state_exited.emit(state)
    
    if debug_mode:
        print("Выход из состояния: " + _get_state_name(state), "StateMachine")
    
    match state:
        GameEnums.StalkerState.FLEE:
            if navigation and stalker:
                navigation.set_speed(stalker.move_speed)


# ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

func _get_attack_target() -> Node:
    if current_state == GameEnums.StalkerState.ATTACK_ANOMALY and memory:
        return memory.get_nearest_threat()
    elif current_state == GameEnums.StalkerState.ATTACK_MUTANT and memory:
        return memory.get_nearest_mutant()
    return null


func _get_edge_position() -> Vector3:
    if monolith:
        var dir = (stalker.global_position - monolith.global_position).normalized()
        return monolith.global_position + dir * 200
    return stalker.global_position + Vector3(100, 0, 0)


func _generate_patrol_points(count: int = 3) -> Array[Vector3]:
    var points = []
    var center = stalker.global_position
    
    for i in range(count):
        var angle = (TAU / count) * i + randf_range(-0.5, 0.5)
        var distance = 15.0 + randf_range(-5, 5)
        var pos = center + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
        
        # Корректировка по высоте
        var space = stalker.get_world_3d().direct_space_state
        var query = PhysicsRayQueryParameters3D.new()
        query.from = pos + Vector3(0, 20, 0)
        query.to = pos - Vector3(0, 20, 0)
        query.collision_mask = 1
        
        var result = space.intersect_ray(query)
        if result:
            pos.y = result.position.y + 0.5
        
        points.append(pos)
    
    return points


func _get_state_name(state: GameEnums.StalkerState) -> String:
    return GameEnums.StalkerState.keys()[state]


# ==================== ПУБЛИЧНОЕ API ====================

func set_state(new_state: GameEnums.StalkerState):
    if current_state == new_state:
        return
    
    _on_state_exited(current_state)
    previous_state = current_state
    current_state = new_state


func get_state() -> GameEnums.StalkerState:
    return current_state


func get_state_name() -> String:
    return _get_state_name(current_state)


func get_previous_state() -> GameEnums.StalkerState:
    return previous_state


func get_time_in_state() -> float:
    return current_state_time


func is_in_state(state: GameEnums.StalkerState) -> bool:
    return current_state == state


func is_in_combat() -> bool:
    return current_state in [GameEnums.StalkerState.ATTACK_ANOMALY, GameEnums.StalkerState.ATTACK_MUTANT]


func is_fleeing() -> bool:
    return current_state == GameEnums.StalkerState.FLEE


func is_carrying() -> bool:
    return current_state == GameEnums.StalkerState.CARRY_ARTIFACT


func is_moving_to_target() -> bool:
    return current_state in [
        GameEnums.StalkerState.SEEK_ARTIFACT,
        GameEnums.StalkerState.SEEK_MONOLITH,
        GameEnums.StalkerState.CARRY_ARTIFACT
    ]


func enable_debug(enable: bool):
    debug_mode = enable


func get_status() -> Dictionary:
    return {
        "current_state": _get_state_name(current_state),
        "previous_state": _get_state_name(previous_state),
        "time_in_state": current_state_time,
        "in_combat": is_in_combat(),
        "fleeing": is_fleeing(),
        "carrying": is_carrying()
    }