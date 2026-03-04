extends BaseMutant
class_name ControllerMutant

# Уникальные параметры контроллера
@export var control_range: float = 15.0
@export var control_duration: float = 5.0
@export var control_cooldown: float = 10.0

var control_timer: Timer
var is_controlling: bool = false


func _ready():
	# Установка параметров ДО вызова super._ready()
	health = 80.0
	max_health = 80.0
	speed = 4.0
	damage = 0.0  # Контроллер не наносит прямой урон
	armor = 10.0
	biomass_cost = 100.0
	mutant_type = "controller"
	
	# Вызываем базовый _ready
	super._ready()
	
	# Настройка таймера контроля
	control_timer = Timer.new()
	control_timer.one_shot = true
	control_timer.timeout.connect(_on_control_ended)
	add_child(control_timer)
	
	print("Controller mutant initialized: ", name)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	# Если контролируем, не двигаемся
	if is_controlling:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	# Иначе используем базовую логику
	super._physics_process(delta)


func _chase(delta):
	# Контроллер подходит ближе, чем обычные мутанты
	super._chase(delta)
	
	# Если достаточно близко, пробуем взять под контроль
	if target_stalker and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < control_range and not is_controlling and control_timer.is_stopped():
			_try_control_stalker()


func _try_control_stalker():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	# Проверяем, можно ли контролировать этого сталкера
	if target_stalker.has_method("is_controllable") and not target_stalker.is_controllable():
		print("Controller: сталкер ", target_stalker.name, " не может быть контролирован")
		return
	
	# Временно берём под контроль
	is_controlling = true
	current_state = State.ATTACK  # Используем состояние атаки для "контроля"
	
	print("Controller: беру под контроль сталкера ", target_stalker.name)
	
	# Здесь можно добавить визуальный эффект
	_apply_control_effect(target_stalker)
	
	# Запускаем таймер контроля
	control_timer.wait_time = control_duration
	control_timer.start()


func _apply_control_effect(stalker: Node3D):
	"""Применение эффекта контроля к сталкеру"""
	if stalker.has_method("set_controlled"):
		stalker.set_controlled(true, self)
	
	# Можно изменить цвет или добавить эффект
	# (через модуляцию материала и т.д.)


func _on_control_ended():
	if not target_stalker or not is_instance_valid(target_stalker):
		is_controlling = false
		current_state = State.PATROL
		return
	
	print("Controller: контроль над сталкером ", target_stalker.name, " закончен")
	
	# Снимаем контроль
	if target_stalker.has_method("set_controlled"):
		target_stalker.set_controlled(false, self)
	
	is_controlling = false
	current_state = State.CHASE


func take_damage(dmg: float):
	# Контроллер может прервать контроль при получении урона
	if is_controlling:
		_on_control_ended()
	
	super.take_damage(dmg)


func die():
	if is_controlling:
		_on_control_ended()
	
	super.die()