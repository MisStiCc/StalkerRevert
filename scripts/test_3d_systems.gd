extends Node3D

# Тестовый скрипт для проверки работы 3D-систем

func _ready():
	print("=== Тест 3D-систем ===")
	
	# Проверяем наличие ZoneController
	var zone_controller = get_node("/root/Test3DScene/MainScene/ZoneController")
	if zone_controller:
		print("✓ ZoneController найден")
		print("  - Энергия:", zone_controller.energy)
		print("  - Биомасса:", zone_controller.biomass)
	else:
		print("✗ ZoneController не найден")
	
	# Проверяем наличие спавнера сталкеров
	var spawner = get_node("/root/Test3DScene/MainScene/ZoneController/StalkerSpawner")
	if spawner:
		print("✓ StalkerSpawner найден")
		print("  - Типы сталкеров:", spawner.stalker_types.size())
	else:
		print("✗ StalkerSpawner не найден")
	
	# Проверяем наличие UI
	var ui = get_node("/root/Test3DScene/MainScene/MainUI")
	if ui:
		print("✓ MainUI найден")
		print("  - Панель ресурсов:", ui.resource_panel != null)
	else:
		print("✗ MainUI не найден")
	
	# Проверяем создание аномалии
	if zone_controller:
		var anomaly = zone_controller.create_anomaly("heat", Vector3(10, 0, 10))
		if anomaly:
			print("✓ Аномалия создана успешно")
		else:
			print("✗ Не удалось создать аномалию")
	
	# Проверяем создание мутанта
	if zone_controller:
		var mutant = zone_controller.spawn_mutant("dog", Vector3(-10, 0, -10))
		if mutant:
			print("✓ Мутант создан успешно")
		else:
			print("✗ Не удалось создать мутанта")
	
	print("=== Тест завершен ===")

func _process(delta):
	# Можно добавить дополнительную логику тестирования
	pass