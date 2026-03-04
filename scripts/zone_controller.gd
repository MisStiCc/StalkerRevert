extends Node

## Контроллер Зоны - главный элемент управления защитой территории
## Управляет ресурсами, создает аномалии и мутантов, контролирует выбросы

# Переменные
var energy: float = 100.0  # уровень энергии Зоны
var biomass: float = 100.0  # уровень биомассы Зоны
var max_energy: float = 1000.0  # максимальный уровень энергии
var max_biomass: float = 1000.0  # максимальный уровень биомассы
var emission_cooldown: float = 0.0  # время до следующего выброса
var emission_duration: float = 0.0  # длительность выброса
var anomalies: Array = []

func spawn_anomaly(anomaly_type: String, position: Vector2) -> Node:
	var scene_path = "res://scenes/zone/anomalies/anomaly_" + anomaly_type + ".tscn"
	var scene = load(scene_path)
	if scene:
		var anomaly = scene.instantiate()
		anomaly.position = position
		add_child(anomaly)
		anomalies.append(anomaly)
		return anomaly
	return null
var mutants: Array = []  # список текущих мутантов
var artifacts: Array = []  # список текущих артефактов
var stalkers: Array = []  # список текущих сталкеров
var territory_radius: float = 100.0  # радиус территории Зоны

# Сигналы
signal energy_changed(new_energy: float)
signal biomass_changed(new_biomass: float)
signal anomaly_created(anomaly)
signal mutant_spawned(mutant)
signal emission_started
signal emission_ended
signal territory_expanded(new_radius: float)
signal artifact_generated(artifact)
signal stalker_entered_zone(stalker)
signal stalker_left_zone(stalker)
signal stalker_died(stalker)

func _ready():
	"""Инициализация контроллера"""
	print("ZoneController initialized")
	
	# Установка начальных значений
	energy = max_energy / 2
	biomass = max_biomass / 2
	
	# Подписка на сигналы других объектов (если они существуют)
	pass

func _process(delta: float):
	"""Основной цикл обновления"""
	# Обновление ресурсов
	if energy < max_energy:
		add_energy(5.0 * delta)  # медленное восстановление энергии
	if biomass < max_biomass:
		add_biomass(3.0 * delta)  # медленное восстановление биомассы
	
	# Уменьшение времени до следующего выброса
	if emission_cooldown > 0:
		emission_cooldown -= delta
	
	# Обновление длительности выброса
	if emission_duration > 0:
		emission_duration -= delta
		if emission_duration <= 0:
			emit_signal("emission_ended")

func add_energy(amount: float) -> void:
	"""Добавление энергии"""
	var old_energy = energy
	energy = min(energy + amount, max_energy)
	if abs(old_energy - energy) > 0.01:  # если энергия действительно изменилась
		emit_signal("energy_changed", energy)

func spend_energy(amount: float) -> bool:
	"""Расход энергии"""
	if energy >= amount:
		energy -= amount
		emit_signal("energy_changed", energy)
		return true
	else:
		print("Недостаточно энергии для выполнения операции")
		return false

func add_biomass(amount: float) -> void:
	"""Добавление биомассы"""
	var old_biomass = biomass
	biomass = min(biomass + amount, max_biomass)
	if abs(old_biomass - biomass) > 0.01:  # если биомасса действительно изменилась
		emit_signal("biomass_changed", biomass)

func spend_biomass(amount: float) -> bool:
	"""Расход биомассы"""
	if biomass >= amount:
		biomass -= amount
		emit_signal("biomass_changed", biomass)
		return true
	else:
		print("Недостаточно биомассы для выполнения операции")
		return false

func create_anomaly(type: String, position: Vector2):
	"""Создание аномалии - возвращает объект аномалии или null"""
	# Проверяем, достаточно ли энергии для создания аномалии
	var cost = get_anomaly_cost(type)
	if not spend_energy(cost):
		print("Недостаточно энергии для создания аномалии ", type)
		return null
	
	# В реальной реализации здесь будет создание экземпляра аномалии
	# и добавление в список аномалий
	var anomaly = {
		"type": type,
		"position": position,
		"lifetime": 60.0  # условное время жизни
	}
	anomalies.append(anomaly)
	
	print("Аномалия ", type, " создана на позиции ", position)
	emit_signal("anomaly_created", anomaly)
	return anomaly

func spawn_mutant(type: String, position: Vector2):
	"""Призыв мутанта - возвращает объект мутанта или null"""
	# Проверяем, достаточно ли биомассы для призыва мутанта
	var cost = get_mutant_cost(type)
	if not spend_biomass(cost):
		print("Недостаточно биомассы для призыва мутанта ", type)
		return null
	
	# В реальной реализации здесь будет создание экземпляра мутанта
	# и добавление в список мутантов
	var mutant = {
		"type": type,
		"position": position,
		"health": 100
	}
	mutants.append(mutant)
	
	print("Мутант ", type, " призван на позиции ", position)
	emit_signal("mutant_spawned", mutant)
	return mutant

func do_emission() -> void:
	"""Выполнение выброса"""
	if emission_cooldown <= 0:
		# Выброс требует много ресурсов
		var energy_cost = 500.0
		var biomass_cost = 300.0
		
		if energy >= energy_cost and biomass >= biomass_cost:
			spend_energy(energy_cost)
			spend_biomass(biomass_cost)
			
			# Устанавливаем время действия выброса
			emission_duration = 10.0  # 10 секунд выброса
			# Сбрасываем таймер до следующего выброса
			emission_cooldown = 120.0  # 2 минуты до следующего выброса
			
			print("Выброс активирован!")
			emit_signal("emission_started")
			
			# В реальной игре выброс будет наносить урон всем объектам в зоне
			for stalker in stalkers:
				if stalker != null:
					# Урон сталкеру при выбросе
					pass
		else:
			print("Недостаточно ресурсов для выброса")
	else:
		var remaining_time = ceil(emission_cooldown)
		print("Выброс недоступен, осталось времени: ", remaining_time, " секунд")

func expand_territory(radius_increase: float) -> void:
	"""Расширение территории"""
	territory_radius += radius_increase
	emit_signal("territory_expanded", territory_radius)
	print("Территория расширена. Новый радиус: ", territory_radius)

func generate_artifact(position: Vector2):
	"""Генерация артефакта - возвращает объект артефакта"""
	var artifact = {
		"position": position,
		"type": "common",
		"value": 10
	}
	artifacts.append(artifact)
	emit_signal("artifact_generated", artifact)
	print("Артефакт создан на позиции ", position)
	return artifact

func update_stalker_status(stalker) -> void:
	"""Обновление статуса сталкера"""
	# Проверяем, находится ли сталкер в зоне
	var stalker_in_zone = is_stalker_in_zone(stalker)
	
	if stalker_in_zone and not stalkers.has(stalker):
		# Сталкер вошел в зону
		stalkers.append(stalker)
		emit_signal("stalker_entered_zone", stalker)
	elif not stalker_in_zone and stalkers.has(stalker):
		# Сталкер покинул зону
		stalkers.erase(stalker)
		emit_signal("stalker_left_zone", stalker)

func get_resource_efficiency() -> float:
	"""Эффективность использования ресурсов"""
	var total_resources = energy + biomass
	var max_possible = max_energy + max_biomass
	if max_possible > 0:
		return total_resources / max_possible
	else:
		return 0.0

# Вспомогательные функции

func get_anomaly_cost(type: String) -> float:
	"""Получение стоимости создания аномалии"""
	match type:
		"heat": return 50.0
		"electric": return 75.0
		"acid": return 100.0
		"gravitational": return 150.0
		_: return 50.0

func get_mutant_cost(type: String) -> float:
	"""Получение стоимости призыва мутанта"""
	match type:
		"dog": return 50.0
		"snork": return 100.0
		"controller": return 200.0
		_: return 50.0

func is_stalker_in_zone(stalker) -> bool:
	"""Проверка, находится ли сталкер в зоне"""
	# В реальной реализации это будет зависеть от позиции сталкера
	# и размера территории
	if stalker != null and stalker.position != null:
		return stalker.position.distance_to(Vector2.ZERO) <= territory_radius
	else:
		return false