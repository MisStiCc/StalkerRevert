# ui/lab/lab_controller.gd
extends Control
class_name LabController

## Контроллер лабораторного комплекса

signal run_started
signal upgrade_station_opened(station_type: String)
signal storage_opened
signal settings_opened

# Основная информация
@onready var run_number_label: Label = $VBox/Header/RunNumber
@onready var biomass_label: Label = $VBox/InfoPanel/HBox/BiomassValue
@onready var start_run_button: Button = $VBox/InfoPanel/StartRunButton

# Станции
@onready var anomaly_station: Button = $VBox/Stations/AnomalyStation
@onready var mutant_station: Button = $VBox/Stations/MutantStation
@onready var monolith_station: Button = $VBox/Stations/MonolithStation

# Хранилище
@onready var artifact_storage_button: Button = $VBox/StoragePanel/OpenStorageButton
@onready var artifact_counts_label: Label = $VBox/StoragePanel/HBox/ArtifactCounts

# Статистика
@onready var stats_label: Label = $VBox/StatsPanel/StatsLabel

# Нижние кнопки
@onready var menu_button: Button = $VBox/BottomButtons/MenuButton
@onready var settings_button: Button = $VBox/BottomButtons/SettingsButton
@onready var save_button: Button = $VBox/BottomButtons/SaveButton

# Панели
@onready var upgrade_panel: Control = $UpgradePanel
@onready var storage_panel: Control = $StoragePanel
@onready var result_panel: Control = $ResultPanel

# Данные
var lab_data: LabData
var statistics: GameStatistics
var game_manager: Node


func _ready():
	print("lab_controller: _ready started")
	
	# Ищем GameManager один раз при старте
	game_manager = get_tree().get_first_node_in_group("game_manager")
	
	_load_data()
	_setup_connections()
	_refresh_ui()
	
	print("lab_controller: initialized, GameManager найден: ", game_manager != null)


func _load_data():
	print("lab_controller: загрузка данных...")
	
	if game_manager:
		print("GameManager НАЙДЕН!")
		lab_data = game_manager.get_lab_data()
		statistics = game_manager.get_statistics()
	else:
		print("GameManager НЕ НАЙДЕН! Создаем временные данные")
		lab_data = LabData.new()
		statistics = GameStatistics.new()
	
	print("lab_controller: данные загружены")


func _setup_connections():
	start_run_button.pressed.connect(_on_start_run_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	save_button.pressed.connect(_on_save_pressed)
	artifact_storage_button.pressed.connect(_on_storage_pressed)
	
	anomaly_station.pressed.connect(_on_anomaly_station_pressed)
	mutant_station.pressed.connect(_on_mutant_station_pressed)
	monolith_station.pressed.connect(_on_monolith_station_pressed)
	
	_setup_sounds()


func _setup_sounds():
	var buttons = [
		start_run_button, menu_button, settings_button, 
		save_button, artifact_storage_button,
		anomaly_station, mutant_station, monolith_station
	]
	
	for btn in buttons:
		if btn:
			btn.mouse_entered.connect(_play_hover_sound)


func _play_hover_sound():
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_hover", 0.3)


func _play_click_sound():
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.6)


func _refresh_ui():
	if not lab_data:
		print("lab_data отсутствует, создаем новый")
		lab_data = LabData.new()
	
	run_number_label.text = "День %d" % lab_data.run_number
	biomass_label.text = _format_number(lab_data.biomass)
	
	_update_station_button(anomaly_station, "АНОМАЛИИ", lab_data.get_total_anomaly_levels())
	_update_station_button(mutant_station, "МУТАНТЫ", lab_data.get_total_mutant_levels())
	_update_station_button(monolith_station, "МОНОЛИТ", lab_data.get_total_monolith_levels())
	
	var common = lab_data.get_artifact_count("common")
	var rare = lab_data.get_artifact_count("rare")
	var legendary = lab_data.get_artifact_count("legendary")
	artifact_counts_label.text = "Common: %d   Rare: %d   Legendary: %d" % [common, rare, legendary]
	
	if statistics:
		stats_label.text = "Всего забегов: %d   Побед: %d   Поражений: %d\nСталкеров убито: %d   Артефактов украдено: %d" % [
			statistics.total_runs,
			statistics.wins,
			statistics.losses,
			statistics.stalkers_killed,
			statistics.artifacts_stolen
		]


func _update_station_button(station: Button, name: String, total_levels: int):
	var name_label = station.get_node_or_null("StationName")
	if name_label and name_label is Label:
		name_label.text = name
	
	var level_label = station.get_node_or_null("StationLevel")
	if level_label and level_label is Label:
		level_label.text = "Ур.%d" % total_levels


func _format_number(value: float) -> String:
	var s = str(int(value))
	var result = ""
	var count = 0
	
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = " " + result
		result = s[i] + result
		count += 1
	
	return result


# ==================== ОБРАБОТЧИКИ ====================

func _on_start_run_pressed():
	_play_click_sound()
	run_started.emit()
	
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		print("Запуск забега через GameManager")
		await get_tree().create_timer(0.2).timeout
		game_manager.change_scene("run")
	else:
		print("GameManager не найден, не могу начать забег")


func _on_menu_pressed():
	_play_click_sound()
	
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		await get_tree().create_timer(0.2).timeout
		game_manager.change_scene("main_menu")
	else:
		print("GameManager не найден, переходим напрямую")
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_settings_pressed():
	_play_click_sound()
	settings_opened.emit()
	# TODO: открыть настройки


func _on_save_pressed():
	_play_click_sound()
	
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		game_manager.save_game(0)
		_show_message("Игра сохранена", 1.0)
	else:
		print("GameManager не найден, не могу сохранить")


func _on_storage_pressed():
	_play_click_sound()
	storage_opened.emit()
	_open_storage()


func _on_anomaly_station_pressed():
	_play_click_sound()
	upgrade_station_opened.emit("anomaly")
	_open_upgrade_station("anomaly")


func _on_mutant_station_pressed():
	_play_click_sound()
	upgrade_station_opened.emit("mutant")
	_open_upgrade_station("mutant")


func _on_monolith_station_pressed():
	_play_click_sound()
	upgrade_station_opened.emit("monolith")
	_open_upgrade_station("monolith")


# ==================== ПАНЕЛИ ====================

func _open_upgrade_station(station_type: String):
	if upgrade_panel and upgrade_panel.has_method("setup"):
		upgrade_panel.setup(station_type, lab_data, _on_upgrade_purchased)
		upgrade_panel.visible = true
	else:
		print("Upgrade panel not found or invalid")
		_show_message("Панель улучшений не найдена", 1.0)


func _on_upgrade_purchased(upgrade_type: String):
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		lab_data = game_manager.get_lab_data()
	_refresh_ui()
	_show_message("Улучшение приобретено!", 1.0)


func _open_storage():
	if storage_panel and storage_panel.has_method("setup"):
		storage_panel.setup(lab_data, _on_artifact_exchanged)
		storage_panel.visible = true
	else:
		print("Storage panel not found or invalid")
		_show_message("Хранилище не найдено", 1.0)


func _on_artifact_exchanged():
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		lab_data = game_manager.get_lab_data()
	_refresh_ui()
	_show_message("Артефакт обменян", 1.0)


func show_run_result(result: Dictionary):
	if result_panel and result_panel.has_method("show_result"):
		result_panel.show_result(result)
		result_panel.visible = true
	
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		lab_data = game_manager.get_lab_data()
		statistics = game_manager.get_statistics()
	_refresh_ui()


func _show_message(text: String, duration: float = 2.0):
	var msg_label = Label.new()
	msg_label.text = text
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.add_theme_color_override("font_color", Color.WHITE)
	msg_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	msg_label.add_theme_constant_override("shadow_offset_x", 2)
	msg_label.add_theme_constant_override("shadow_offset_y", 2)
	
	add_child(msg_label)
	msg_label.position = Vector2(size.x / 2 - 100, size.y / 2)
	
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(msg_label):
		msg_label.queue_free()
