extends Control
class_name LabController

## Контроллер лабораторного комплекса
## Управляет интерфейсом ЛК и станциями улучшений

# Основная информация
@onready var run_number_label: Label = $VBox/Header/RunNumber
@onready var biomass_label: Label = $VBox/InfoPanel/BiomassValue
@onready var start_run_button: Button = $VBox/InfoPanel/StartRunButton

# Станции
@onready var anomaly_station: Control = $VBox/Stations/AnomalyStation
@onready var mutant_station: Control = $VBox/Stations/MutantStation
@onready var monolith_station: Control = $VBox/Stations/MonolithStation

# Хранилище
@onready var artifact_storage_button: Button = $VBox/StoragePanel/OpenStorageButton
@onready var artifact_counts_label: Label = $VBox/StoragePanel/ArtifactCounts

# Статистика
@onready var stats_label: Label = $VBox/StatsPanel/StatsLabel

# Нижние кнопки
@onready var menu_button: Button = $VBox/BottomButtons/MenuButton
@onready var settings_button: Button = $VBox/BottomButtons/SettingsButton
@onready var save_button: Button = $VBox/BottomButtons/SaveButton

# Модальные окна
@onready var upgrade_panel: Control = $UpgradePanel
@onready var storage_panel: Control = $StoragePanel
@onready var result_panel: Control = $ResultPanel

# Данные
var lab_data: LabData
var statistics: GameStatistics


func _ready():
	# Находим данные
	lab_data = GameManager.get_lab_data()
	statistics = GameManager.get_statistics()
	
	# Подключаем кнопки
	_setup_connections()
	
	# Обновляем интерфейс
	_refresh_ui()
	
	print("🏭 LabController: инициализирован")


func _setup_connections():
	start_run_button.pressed.connect(_on_start_run_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	save_button.pressed.connect(_on_save_pressed)
	artifact_storage_button.pressed.connect(_on_storage_pressed)
	
	# Станции
	anomaly_station.pressed.connect(_on_anomaly_station_pressed)
	mutant_station.pressed.connect(_on_mutant_station_pressed)
	monolith_station.pressed.connect(_on_monolith_station_pressed)
	
	# Звуки
	_animate_buttons()


func _animate_buttons():
	var buttons = [
		start_run_button, menu_button, settings_button, 
		save_button, artifact_storage_button,
		anomaly_station, mutant_station, monolith_station
	]
	
	for btn in buttons:
		if btn:
			btn.mouse_entered.connect(func(): _play_hover_sound())


func _play_hover_sound():
	if GameManager.sound_manager:
		GameManager.sound_manager.play_sound("ui_hover", 0.3)


func _play_click_sound():
	if GameManager.sound_manager:
		GameManager.sound_manager.play_sound("ui_click", 0.6)


func _refresh_ui():
	# Основная информация
	run_number_label.text = "День %d" % lab_data.run_number
	biomass_label.text = _format_number(lab_data.biomass)
	
	# Станции - обновляем уровни
	_update_station_button(anomaly_station, "АНОМАЛИИ", 
		lab_data.anomaly_damage_level + lab_data.anomaly_radius_level + lab_data.anomaly_duration_level)
	_update_station_button(mutant_station, "МУТАНТЫ",
		lab_data.mutant_health_level + lab_data.mutant_damage_level + lab_data.mutant_speed_level + lab_data.mutant_cost_level)
	_update_station_button(monolith_station, "МОНОЛИТ",
		lab_data.monolith_energy_level + lab_data.monolith_regen_level + lab_data.rare_chance_level)
	
	# Артефакты
	var common = lab_data.get_artifact_count("common")
	var rare = lab_data.get_artifact_count("rare")
	var legendary = lab_data.get_artifact_count("legendary")
	artifact_counts_label.text = "Common: %d   Rare: %d   Legendary: %d" % [common, rare, legendary]
	
	# Статистика
	stats_label.text = "Всего забегов: %d   Побед: %d   Поражений: %d\nСталкеров убито: %d   Артефактов украдено: %d" % [
		statistics.total_runs,
		statistics.wins,
		statistics.losses,
		statistics.stalkers_killed,
		statistics.artifacts_stolen
	]


func _update_station_button(station: Control, name: String, total_levels: int):
	if station and station.has_node("StationName"):
		station.get_node("StationName").text = name
	if station and station.has_node("StationLevel"):
		station.get_node("StationLevel").text = "Ур.%d" % total_levels


func _format_number(value: float) -> String:
	var s = str(int(value))
	var result = ""
	var count = 0
	
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	
	return result


# ==================== ОБРАБОТЧИКИ ====================

func _on_start_run_pressed():
	_play_click_sound()
	await get_tree().create_timer(0.2).timeout
	GameManager.change_scene("run")


func _on_menu_pressed():
	_play_click_sound()
	await get_tree().create_timer(0.2).timeout
	GameManager.change_scene("main_menu")


func _on_settings_pressed():
	_play_click_sound()
	# TODO: открыть экран настроек


func _on_save_pressed():
	_play_click_sound()
	# Сохраняем в текущий слот
	GameManager.save_game(0)


func _on_storage_pressed():
	_play_click_sound()
	_open_storage()


func _on_anomaly_station_pressed():
	_play_click_sound()
	_open_upgrade_station("anomaly")


func _on_mutant_station_pressed():
	_play_click_sound()
	_open_upgrade_station("mutant")


func _on_monolith_station_pressed():
	_play_click_sound()
	_open_upgrade_station("monolith")


# ==================== СТАНЦИИ УЛУЧШЕНИЙ ====================

func _open_upgrade_station(station_type: String):
	upgrade_panel.visible = true
	upgrade_panel.setup(station_type, lab_data, _on_upgrade_purchased)


func _on_upgrade_purchased(upgrade_type: String):
	lab_data = GameManager.get_lab_data()
	_refresh_ui()


# ==================== ХРАНИЛИЩЕ ====================

func _open_storage():
	storage_panel.visible = true
	storage_panel.setup(lab_data, _on_artifact_exchanged)


func _on_artifact_exchanged():
	lab_data = GameManager.get_lab_data()
	_refresh_ui()


# ==================== РЕЗУЛЬТАТЫ ЗАБЕГА ====================

func show_run_result(result: Dictionary):
	result_panel.visible = true
	result_panel.show_result(result)
	
	# Обновляем данные
	lab_data = GameManager.get_lab_data()
	statistics = GameManager.get_statistics()
	_refresh_ui()
