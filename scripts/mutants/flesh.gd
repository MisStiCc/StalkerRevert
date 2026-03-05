extends BaseMutant
class_name FleshMutant

## Плоть - мутировавшие свиньи
## Наименее агрессивные мутанты, нападают только при угрозе

@export var aggression_threshold: float = 30.0  # Порог агрессии (урон по мутанту)
@export var charge_speed: float = 12.0  # Скорость тарана
@export var charge_damage: float = 35.0  # Урон тарана
@export var charge_cooldown: float = 5.0  # Кулдаун тарана

var accumulated_damage: float = 0.0  # Накопленный урон
var can_charge: bool = true
var is_charging: bool = false
var charge_target: Vector3
var charge_timer: Timer

func _ready():
	# Плоть - среднего размера мутант
	health = 200.0
	max_health = 200.0
	speed = 4.0
	damage = 15.0
	armor = 20.0  # Хорошая броня
	biomass_cost = 60.0
	mutant_type = "flesh"
	
	super._ready()
	
	# По умолчанию пассивны
	current_state = State.PATROL
	
	# Таймер тарана
	charge_timer = Timer.new()
	charge_timer.one_shot = true
	charge_timer.timeout.connect(_on_charge_cooldown_ended)
	add_child(charge_timer)
	
	print("Flesh mutant initialized")


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	# Если накапливается урон - становимся агрессивными
	if accumulated_damage > aggression_threshold and current_state == State.PATROL:
		_become_aggressive()
	
	# Обработка тарана
	if is_charging:
		_handle_charge(delta)
		return
	
	super._physics_process(delta)


func _patrol(delta):
	# Плоть просто бродит, не преследуя сталкеров
	if target_stalker and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		# Если сталкер очень близко - становимся агрессивными
		if dist < 3.0:
			_become_aggressive()
	
	# Обычное патрулирование
	super._patrol(delta)


func _become_aggressive():
	"""Переход в агрессивное состояние"""
	print("Flesh: становлюсь агрессивным!")
	current_state = State.CHASE
	accumulated_damage = 0.0
	
	# Ищем ближайшего сталкера
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	var nearest_stalker = null
	var nearest_dist = INF
	
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_stalker = stalker
	
	if nearest_stalker:
		target_stalker = nearest_stalker


func _chase(delta):
	"""Преследование (только если агрессивны)"""
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		accumulated_damage = 0.0  # Сбрасываем накопленный урон
		return
	
	var direction = (target_stalker.global_position - global_position).normalized()
	velocity = direction * speed
	
	# Если достаточно близко - пробуем таран
	if can_charge and not is_charging:
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < 10.0 and dist > 4.0:
			_start_charge()
	
	# Проверка дистанции для атаки
	if global_position.distance_to(target_stalker.global_position) < 2.0:
		current_state = State.ATTACK


func _start_charge():
	"""Начало тарана"""
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	print("Flesh: начинаю таран!")
	is_charging = true
	can_charge = false
	charge_target = target_stalker.global_position
	
	charge_timer.wait_time = charge_cooldown
	charge_timer.start()


func _handle_charge(delta):
	"""Обработка тарана"""
	var direction = (charge_target - global_position).normalized()
	velocity = direction * charge_speed
	
	# Добавляем вертикальную составляющую для "прыжка"
	velocity.y = 3.0
	
	move_and_slide()
	
	# Проверяем столкновение
	if global_position.distance_to(charge_target) < 2.0 or is_on_wall():
		_end_charge()


func _end_charge():
	"""Конец тарана"""
	is_charging = false
	velocity = Vector3.ZERO
	
	# Наносим урон всем на пути
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < 4.0:
				if stalker.has_method("take_damage"):
					stalker.take_damage(charge_damage)
					attacked_stalker.emit(stalker)
	
	# Возвращаемся к преследованию или патрулю
	if target_stalker and is_instance_valid(target_stalker):
		current_state = State.CHASE
	else:
		current_state = State.PATROL


func _on_charge_cooldown_ended():
	can_charge = true


func _attack(delta):
	"""Ближняя атака"""
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 2.5:
		current_state = State.CHASE
		return
	
	# Атакуем
	if attack_timer.is_stopped():
		target_stalker.take_damage(damage)
		attacked_stalker.emit(target_stalker)
		attack_timer.start()


func take_damage(dmg: float):
	# Накапливаем урон
	accumulated_damage += dmg
	
	# Плоть имеет бонус к защите от ranged атак
	# (в реальной игре можно определить тип атаки)
	super.take_damage(dmg)
