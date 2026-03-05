extends BaseMutant
class_name ChimeraMutant

## Химера - редкий зверь Зоны, охотится ночью
## Большая сила, быстрота, вторая голова на шее

@export var is_night_only: bool = true  # Охотится только ночью
@export var leap_distance: float = 15.0  # Дистанция прыжка
@export var leap_damage: float = 50.0  # Урон прыжка
@export var secondary_head_damage: float = 10.0  # Урон от второй головы

var can_leap: bool = true
var leap_timer: Timer
var is_leaping: bool = false
var leap_target: Vector3

func _ready():
	# Химера - очень сильный и быстрый мутант
	health = 250.0
	max_health = 250.0
	speed = 10.0  # Очень быстрый
	damage = 30.0
	armor = 25.0  # Хорошая броня
	biomass_cost = 200.0  # Дорогой
	mutant_type = "chimera"
	
	super._ready()
	
	# Таймер прыжка
	leap_timer = Timer.new()
	leap_timer.one_shot = true
	leap_timer.wait_time = 4.0
	leap_timer.timeout.connect(_on_leap_cooldown_ended)
	add_child(leap_timer)
	
	# Если дневное время - отдыхаем
	if is_night_only and not _is_night():
		current_state = State.PATROL
		# Можно сделать "спячку"
	
	print("Chimera mutant initialized")


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	# Если только ночью - проверяем время
	if is_night_only:
		if not _is_night():
			# Днём - отдыхаем, не охотимся
			velocity = Vector3.ZERO
			move_and_slide()
			return
	
	# Обработка прыжка
	if is_leaping:
		_handle_leap(delta)
		return
	
	super._physics_process(delta)


func _is_night() -> bool:
	"""Проверка, ночное ли время (упрощённо)"""
	# В Godot можно получить время суток через environment или время игры
	# Для простоты - случайно или по времени суток
	var hour = Time.get_datetime_dict_from_system()["hour"]
	return hour < 6 or hour >= 20  # Ночь с 20:00 до 6:00


func _patrol(delta):
	# Химера патрулирует территорию, но ночью активно ищет добычу
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	var nearest_stalker = null
	var nearest_dist = INF
	
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < detection_radius * 2 and dist < nearest_dist:
				nearest_dist = dist
				nearest_stalker = stalker
	
	if nearest_stalker:
		target_stalker = nearest_stalker
		current_state = State.CHASE
	
	super._patrol(delta)


func _chase(delta):
	"""Агрессивное преследование"""
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var direction = (target_stalker.global_position - global_position).normalized()
	velocity = direction * speed
	
	# Если достаточно близко и можем прыгнуть - прыгаем
	if can_leap and not is_leaping:
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < leap_distance and dist > 5.0:
			_start_leap()
	
	# Проверка дистанции для атаки
	if global_position.distance_to(target_stalker.global_position) < 2.5:
		current_state = State.ATTACK


func _start_leap():
	"""Начало прыжка"""
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	print("Chimera: прыгаю!")
	is_leaping = true
	can_leap = false
	
	# Цель - позиция сталкера
	leap_target = target_stalker.global_position
	
	leap_timer.start()


func _handle_leap(delta):
	"""Обработка прыжка"""
	var direction = (leap_target - global_position).normalized()
	velocity = direction * speed * 3.0  # В 3 раза быстрее при прыжке
	velocity.y = 8.0  # Высокий прыжок
	
	move_and_slide()
	
	# Проверяем приземление
	if global_position.distance_to(leap_target) < 2.0 or is_on_floor():
		_land()


func _land():
	"""Приземление после прыжка"""
	print("Chimera: приземлился!")
	is_leaping = false
	velocity = Vector3.ZERO
	
	# Наносим урон всем рядом
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < 5.0:
				if stalker.has_method("take_damage"):
					stalker.take_damage(leap_damage)
					attacked_stalker.emit(stalker)
	
	# Возвращаемся к преследованию
	if target_stalker and is_instance_valid(target_stalker):
		current_state = State.CHASE
	else:
		current_state = State.PATROL


func _on_leap_cooldown_ended():
	can_leap = true


func _attack(delta):
	"""Ближняя атака - основная + вторая голова"""
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 3.0:
		current_state = State.CHASE
		return
	
	# Основная атака
	if attack_timer.is_stopped():
		target_stalker.take_damage(damage)
		
		# Вторая голова кусает с небольшой задержкой
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(target_stalker):
			target_stalker.take_damage(secondary_head_damage)
			attacked_stalker.emit(target_stalker)
		
		attack_timer.start()


func die():
	# Химера издаёт предсмертный рёв
	print("Chimera: предсмертный рёв!")
	super.die()
