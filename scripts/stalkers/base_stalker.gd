extends CharacterBody3D

class_name BaseStalker

# Базовые параметры сталкера
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var speed: float = 5.0
@export var damage: float = 10.0

# Состояния сталкера
enum StalkerState {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	FLEE,
	DEAD
}

var current_state: StalkerState = StalkerState.IDLE
var target: Node3D = null
var navigation_agent: NavigationAgent3D

# Сигналы
signal health_changed(current_health: float, max_health: float)
signal state_changed(new_state: StalkerState)
signal died(stalker: BaseStalker)

func _ready():
	# Инициализация навигации
	navigation_agent = $NavigationAgent3D if has_node("NavigationAgent3D") else NavigationAgent3D.new()
	add_child(navigation_agent)
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	
	# Подписка на сигналы
	health_changed.emit(health, max_health)
	state_changed.emit(current_state)

func _physics_process(delta):
	if current_state == StalkerState.DEAD:
		return
		
	# Обработка состояний
	match current_state:
		StalkerState.IDLE:
			_handle_idle_state(delta)
		StalkerState.PATROL:
			_handle_patrol_state(delta)
		StalkerState.CHASE:
			_handle_chase_state(delta)
		StalkerState.ATTACK:
			_handle_attack_state(delta)
		StalkerState.FLEE:
			_handle_flee_state(delta)

func _handle_idle_state(delta):
	# Логика состояния ожидания
	if target:
		_change_state(StalkerState.CHASE)

func _handle_patrol_state(delta):
	# Логика патрулирования
	pass

func _handle_chase_state(delta):
	if target:
		# Движение к цели
		var direction = global_position.direction_to(target.global_position)
		if direction.length() > 0:
			velocity = direction * speed
		else:
			velocity = Vector3.ZERO
		
		# Проверка расстояния до цели
		var distance_to_target = global_position.distance_to(target.global_position)
		if distance_to_target < 2.0:
			_change_state(StalkerState.ATTACK)
	else:
		_change_state(StalkerState.IDLE)

func _handle_attack_state(delta):
	if target:
		# Нанесение урона цели
		_attack_target()
		
		# Проверка расстояния
		var distance_to_target = global_position.distance_to(target.global_position)
		if distance_to_target > 5.0:
			_change_state(StalkerState.CHASE)
		elif health < max_health * 0.3:
			_change_state(StalkerState.FLEE)
	else:
		_change_state(StalkerState.IDLE)

func _handle_flee_state(delta):
	# Логика бегства от опасности
	pass

func _on_velocity_computed(safe_velocity):
	velocity = safe_velocity
	move_and_slide()

func _change_state(new_state: StalkerState):
	if current_state != new_state:
		current_state = new_state
		state_changed.emit(new_state)

func take_damage(amount: float):
	if current_state == StalkerState.DEAD:
		return
		
	health -= amount
	health_changed.emit(health, max_health)
	
	if health <= 0:
		die()

func die():
	current_state = StalkerState.DEAD
	died.emit(self)
	# Здесь можно добавить логику смерти (анимация, удаление и т.д.)

func attack_target():
	# Метод для атаки цели
	pass

func set_target(new_target: Node3D):
	target = new_target
	if target:
		_change_state(StalkerState.CHASE)
	else:
		_change_state(StalkerState.IDLE)