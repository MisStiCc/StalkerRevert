extends Stalker
class_name NoviceStalker

## Сталкер-новичок - слабый, но дешевый противник


func _ready() -> void:
	"""Инициализация новичка с соответствующими параметрами"""
	# Устанавливаем параметры ДО вызова super._ready()
	stalker_name = "Novice"
	max_health = 50.0  # Мало здоровья
	armor = 0.0  # Нет брони
	damage = 8.0  # Меньше урона
	speed = 4.0  # Скорость (не 80.0!)
	
	# Вызываем базовый _ready (устанавливает health = max_health)
	super._ready()
	
	print("Новичок ", stalker_name, " появился с ", max_health, " HP")


func avoid_anomaly(anomaly: Node3D) -> void:
	"""Новичок слабо реагирует на аномалии"""
	if not is_instance_valid(anomaly):
		return
	
	# Просто немного меняет курс, не особо опасаясь аномалий
	var random_offset = Vector3(
		randf_range(-30, 30),
		0,  # не меняем высоту
		randf_range(-30, 30)
	)
	var new_pos = global_position + random_offset
	move_to(new_pos)
	print("Новичок слабо избегает аномалию ", anomaly.name)


func update(delta: float) -> void:
	"""Обновление поведения новичка"""
	# Новички менее осторожны и могут идти прямо к цели
	# даже если рядом есть аномалии
	super.update(delta)


func get_biomass_value() -> float:
	"""Ценность новичка для биомассы"""
	return 5.0


func _get_biomass_value() -> float:
	"""Переопределяем базовый метод"""
	return get_biomass_value()


func take_damage(amount: float, damage_type: String = "physical") -> void:
	"""Новички могут паниковать при получении урона"""
	super.take_damage(amount, damage_type)
	
	# Новички могут убегать при низком здоровье
	if health < max_health * 0.3:
		# Бежим в случайном направлении
		var flee_direction = Vector3(
			randf_range(-1, 1),
			0,
			randf_range(-1, 1)
		).normalized()
		var flee_pos = global_position + flee_direction * 50
		move_to(flee_pos)
		print("Новичок в панике убегает!")