extends Node

## Тестовый скрипт для проверки интеграции системы сталкеров
## Проверяет работу всех компонентов: аномалии, артефакты, ZoneController, навигация

func _ready():
	print("=== Тестирование интеграции системы сталкеров ===")
	
	# Ждем немного, чтобы все объекты инициализировались
	await get_tree().create_timer(2.0).timeout
	
	_test_anomaly_interaction()
	_test_artifact_collection()
	_test_zone_controller_integration()
	_test_navigation_system()
	
	print("=== Тестирование завершено ===")

func _test_anomaly_interaction():
	print("\n--- Тест: Взаимодействие с аномалиями ---")
	
	# Находим аномалии и сталкеров
	var anomalies = get_tree().get_nodes_in_group("anomaly")
	var stalkers = get_tree().get_nodes_in_group("stalker")
	
	print("Найдено аномалий: ", anomalies.size())
	print("Найдено сталкеров: ", stalkers.size())
	
	if anomalies.size() > 0 and stalkers.size() > 0:
		var anomaly = anomalies[0]
		var stalker = stalkers[0]
		
		print("Проверяем аномалию: ", anomaly.name)
		print("Проверяем сталкера: ", stalker.name)
		
		# Проверяем, что аномалия может наносить урон
		if anomaly.has_method("_apply_damage"):
			print("✓ Аномалия имеет метод нанесения урона")
		else:
			print("✗ Аномалия не имеет метода нанесения урона")
		
		# Проверяем, что сталкер может получать урон
		if stalker.has_method("take_damage"):
			print("✓ Сталкер может получать урон")
			
			# Тестируем получение урона
			var initial_health = stalker.health
			stalker.take_damage(10.0)
			print("Здоровье до: ", initial_health, " после: ", stalker.health)
			
			if stalker.health < initial_health:
				print("✓ Сталкер правильно получает урон")
			else:
				print("✗ Сталкер не получает урон")
		else:
			print("✗ Сталкер не может получать урон")
	else:
		print("✗ Не найдены аномалии или сталкеры для теста")

func _test_artifact_collection():
	print("\n--- Тест: Сбор артефактов ---")
	
	# Находим артефакты и сталкеров
	var artifacts = get_tree().get_nodes_in_group("artifact")
	var stalkers = get_tree().get_nodes_in_group("stalker")
	
	print("Найдено артефактов: ", artifacts.size())
	print("Найдено сталкеров: ", stalkers.size())
	
	if artifacts.size() > 0 and stalkers.size() > 0:
		var artifact = artifacts[0]
		var stalker = stalkers[0]
		
		print("Проверяем артефакт: ", artifact.name)
		print("Проверяем сталкера: ", stalker.name)
		
		# Проверяем, что артефакт может быть собран
		if artifact.has_method("collect"):
			print("✓ Артефакт имеет метод сбора")
			
			# Проверяем, что сталкер имеет инвентарь
			if stalker.has_method("add_artifact"):
				print("✓ Сталкер имеет инвентарь для артефактов")
				
				# Тестируем сбор артефакта
				var initial_artifacts = stalker.carried_artifacts.size()
				artifact.collect(stalker)
				
				if stalker.carried_artifacts.size() > initial_artifacts:
					print("✓ Артефект успешно добавлен в инвентарь")
				else:
					print("✗ Артефакт не добавлен в инвентарь")
			else:
				print("✗ Сталкер не имеет инвентаря для артефактов")
		else:
			print("✗ Артефакт не имеет метода сбора")
	else:
		print("✗ Не найдены артефакты или сталкеры для теста")

func _test_zone_controller_integration():
	print("\n--- Тест: Интеграция с ZoneController ---")
	
	# Находим ZoneController и сталкеров
	var zone_controllers = get_tree().get_nodes_in_group("zone_controller")
	var stalkers = get_tree().get_nodes_in_group("stalker")
	
	print("Найдено ZoneController: ", zone_controllers.size())
	print("Найдено сталкеров: ", stalkers.size())
	
	if zone_controllers.size() > 0 and stalkers.size() > 0:
		var zone_controller = zone_controllers[0]
		var stalker = stalkers[0]
		
		print("Проверяем ZoneController: ", zone_controller.name)
		print("Проверяем сталкера: ", stalker.name)
		
		# Проверяем, что ZoneController может отслеживать сталкеров
		if zone_controller.has_method("update_stalker_status"):
			print("✓ ZoneController может отслеживать сталкеров")
			
			# Проверяем, что сталкер подключен к ZoneController
			if stalker.zone_controller != null:
				print("✓ Сталкер подключен к ZoneController")
			else:
				print("✗ Сталкер не подключен к ZoneController")
			
			# Проверяем сигналы
			if stalker.has_signal("entered_zone") and stalker.has_signal("exited_zone"):
				print("✓ Сталкер имеет сигналы зон")
			else:
				print("✗ Сталкер не имеет сигналов зон")
		else:
			print("✗ ZoneController не может отслеживать сталкеров")
	else:
		print("✗ Не найдены ZoneController или сталкеры для теста")

func _test_navigation_system():
	print("\n--- Тест: Система навигации ---")
	
	# Находим сталкеров
	var stalkers = get_tree().get_nodes_in_group("stalker")
	
	print("Найдено сталкеров: ", stalkers.size())
	
	if stalkers.size() > 0:
		var stalker = stalkers[0]
		
		print("Проверяем сталкера: ", stalker.name)
		
		# Проверяем, что сталкер имеет навигационный агент
		if stalker.navigation_agent != null:
			print("✓ Сталкер имеет навигационный агент")
			
			# Проверяем настройки навигации
			if stalker.navigation_agent.has_method("set_target_position"):
				print("✓ Навигационный агент может устанавливать цели")
				
				# Проверяем, что сталкер может искать цели
				if stalker.has_method("_find_target"):
					print("✓ Сталкер может искать цели")
					
					# Тестируем поиск цели
					var target = stalker._find_target()
					if target != null:
						print("✓ Сталкер нашел цель: ", target.name)
					else:
						print("✗ Сталкер не нашел цель")
				else:
					print("✗ Сталкер не может искать цели")
			else:
				print("✗ Навигационный агент не может устанавливать цели")
		else:
			print("✗ Сталкер не имеет навигационного агента")
		
		# Проверяем состояния сталкера
		if stalker.has_method("_change_state"):
			print("✓ Сталкер может менять состояния")
			
			# Проверяем доступные состояния
			var states = ["IDLE", "PATROL", "CHASE", "ATTACK", "FLEE", "DEAD"]
			for state in states:
				if str(stalker.StalkerState.keys()).find(state) != -1:
					print("✓ Состояние ", state, " доступно")
				else:
					print("✗ Состояние ", state, " недоступно")
		else:
			print("✗ Сталкер не может менять состояния")
	else:
		print("✗ Не найдены сталкеры для теста")