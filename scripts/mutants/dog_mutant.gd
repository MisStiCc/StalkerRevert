extends BaseMutant
class_name DogMutant

# Уникальные параметры собаки
@export var pack_bonus: float = 1.2  # бонус в стае
@export var dodge_chance: float = 0.3  # шанс уклониться от атаки


func _ready():
	# Установка параметров ДО вызова super._ready()
	health = 50.0
	max_health = 50.0
	speed = 8.0  # Быстрее обычных мутантов
	damage = 8.0  # Меньше урона
	armor = 0.0  # Нет брони
	biomass_cost = 30.0  # Дешевле
	mutant_type = "dog"
	
	# Вызываем базовый _ready
	super._ready()
	
	print("Dog mutant initialized: ", name)


func _physics_process(delta):
	# Собаки двигаются быстрее в стае
	var nearby_dogs = _count_nearby_dogs()
	if nearby_dogs > 0:
		# Чем больше собак рядом, тем быстрее
		var original_speed = speed
		speed = original_speed * (1.0 + (nearby_dogs * 0.1))
		super._physics_process(delta)
		speed = original_speed
	else:
		super._physics_process(delta)


func _count_nearby_dogs() -> int:
	"""Подсчёт собак поблизости"""
	var count = 0
	var dogs = get_tree().get_nodes_in_group("mutants")
	
	for dog in dogs:
		if dog == self:
			continue
		if dog is DogMutant and global_position.distance_to(dog.global_position) < 10.0:
			count += 1
	
	return count


func take_damage(dmg: float):
	# Собаки могут уклоняться от атак
	if randf() < dodge_chance:
		print("Dog mutant: уклонился от атаки!")
		return
	
	super.take_damage(dmg)


func _chase(delta):
	# Собаки атакуют с более близкого расстояния
	super._chase(delta)
	
	# Могут пытаться окружить цель
	if target_stalker and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < 3.0 and current_state == State.CHASE:
			# Пытаемся зайти сбоку
			_try_flank()


func _try_flank():
	"""Попытка обойти цель сбоку"""
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	# Простая логика: смещаемся в сторону
	var to_target = (target_stalker.global_position - global_position).normalized()
	var right = Vector3(to_target.z, 0, -to_target.x)  # Перпендикулярный вектор
	
	var flank_position = target_stalker.global_position + right * 2.0
	var direction = (flank_position - global_position).normalized()
	velocity = direction * speed