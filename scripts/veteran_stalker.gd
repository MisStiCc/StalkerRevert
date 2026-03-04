extends Stalker
class_name VeteranStalker

## Сталкер-ветеран - более сильный и осторожный противник


func _ready() -> void:
	"""Инициализация ветерана с соответствующими параметрами"""
	# Устанавливаем параметры ДО вызова super._ready()
	stalker_name = "Veteran"
	max_health = 150.0  # Больше здоровья
	armor = 10.0  # Есть броня
	damage = 20.0  # Больше урона
	speed = 4.5  # Чуть медленнее, но осторожнее (не 100.0!)
	
	# Вызываем базовый _ready (устанавливает health = max_health)
	super._ready()
	
	print("Ветеран ", stalker_name, " готов к бою с ", max_health, " HP")


func avoid_anomaly(anomaly: Node3D) -> void:
	"""Ветеран более осторожно избегает аномалий"""
	if not is_instance_valid(anomaly):
		return
	
	# Ветеран лучше понимает опасность аномалий и активно их избегает
	var safe_pos = _find_safe_position_around_anomaly(anomaly)
	if safe_pos.distance_to(global_position) > 1.0:
		move_to(safe_pos)
		print("Ветеран осторожно избегает аномалию ", anomaly.name)


func _find_safe_position_around_anomaly(anomaly: Node3D) -> Vector3:
	"""Поиск безопасной позиции вокруг аномалии (3D версия)"""
	# Получаем радиус аномалии (пытаемся найти свойство)
	var anomaly_radius = 5.0  # значение по умолчанию
	
	# Проверяем разные возможные имена свойства
	if anomaly.has_method("get_radius"):
		anomaly_radius = anomaly.get_radius()
	elif "radius" in anomaly:
		anomaly_radius = anomaly.radius
	elif "damage_radius" in anomaly:
		anomaly_radius = anomaly.damage_radius
	
	# Направление от аномалии
	var direction_from_anomaly = (global_position - anomaly.global_position).normalized()
	
	# Безопасное расстояние - чуть дальше радиуса
	var safe_distance = anomaly_radius + 5.0
	
	# Возвращаем позицию на безопасном расстоянии в направлении от аномалии
	return anomaly.global_position + direction_from_anomaly * safe_distance


func update(delta: float) -> void:
	"""Обновление поведения ветерана"""
	# Ветеран может координировать действия с другими сталкерами
	# Пока просто вызываем базовый метод
	super.update(delta)


func get_biomass_value() -> float:
	"""Ценность ветерана для биомассы"""
	return 15.0


func _get_biomass_value() -> float:
	"""Переопределяем базовый метод"""
	return get_biomass_value()