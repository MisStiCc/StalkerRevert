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
@onready var settings_screen: Control = $SettingsScreen
@onready var settings_music_slider: HSlider = $SettingsScreen/Panel/MusicSlider
@onready var settings_sfx_slider: HSlider = $SettingsScreen/Panel/SfxSlider
@onready var settings_back_button: Button = $SettingsScreen/Panel/BackButton
@onready var shop_button: Button = $VBox/BottomButtons/ShopButton
@onready var shop_panel: Control = $ShopPanel
@onready var shop_close_button: Button = $ShopPanel/Panel/ShopClose
@onready var shop_biomass_label: Label = $ShopPanel/Panel/ShopBiomass
@onready var mutant_grid: GridContainer = $ShopPanel/Panel/MutantGrid
@onready var artifact_grid: GridContainer = $ShopPanel/Panel/ArtifactGrid
@onready var save_button: Button = $VBox/BottomButtons/SaveButton

# Панели
@onready var upgrade_panel: Control = $UpgradePanel
@onready var storage_panel: Control = $StoragePanel
@onready var result_panel: Control = $ResultPanel

# Данные
var lab_data: LabData
var statistics: GameStatistics
var game_manager: Node

# Кампания: выбранный уровень и элементы селектора (строятся кодом в Header)
var _campaign_level: int = 1
var _campaign_prev_button: Button
var _campaign_next_button: Button
var _campaign_mode_button: Button
var _campaign_label: Label
# Переключатель режима забега: кампания / выживание
var _run_mode_button: Button


func _ready():
	print("lab_controller: _ready started")
	
	_load_cover_art()
	
	# Ищем GameManager один раз при старте
	game_manager = get_tree().get_first_node_in_group("game_manager")
	
	_load_data()
	_setup_connections()
	_refresh_ui()
	_setup_campaign_selector()
	_refresh_campaign_ui()
	_build_star_ui()
	_show_last_run_result()

	print("lab_controller: initialized, GameManager найден: ", game_manager != null)


func _show_last_run_result():
	"""Панель итогов последнего забега (результат кладёт GameManager.process_run_result)"""
	if not get_tree().root.has_meta("last_run_result"):
		return

	var result: Dictionary = get_tree().root.get_meta("last_run_result")
	get_tree().root.remove_meta("last_run_result")
	show_run_result(result)


func _load_cover_art():
	"""Фоновая обложка лаборатории: res://ui/lab/lab_background.svg (опционально).
	Файла нет - остаётся тёмная подложка Background."""
	var cover: TextureRect = get_node_or_null("CoverArt")
	if not cover:
		return
	const COVER_PATH := "res://ui/lab/lab_background.svg"
	if ResourceLoader.exists(COVER_PATH):
		cover.texture = load(COVER_PATH)
		print("lab_controller: обложка лаборатории загружена")
	else:
		cover.visible = false


func _load_data():
	print("lab_controller: загрузка данных...")
	
	if game_manager:
		print("GameManager НАЙДЕН!")
		lab_data = game_manager.get_lab_data()
		statistics = game_manager.get_statistics()
		# Рубеж кампании для проверки разблокировки расширенных тиров
		lab_data.campaign_level_reached = game_manager.get_campaign_level()
	else:
		print("GameManager НЕ НАЙДЕН! Создаем временные данные")
		lab_data = LabData.new()
		statistics = GameStatistics.new()
	
	print("lab_controller: данные загружены")


func _setup_connections():
	start_run_button.pressed.connect(_on_start_run_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	shop_close_button.pressed.connect(_on_shop_close_pressed)
	_setup_settings_sliders()
	_setup_save_slot_selector()
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
		stats_label.text = "Всего забегов: %d   Побед: %d   Поражений: %d\nСталкеров убито: %d   Артефактов украдено: %d\nРекорд выживания: %d волн" % [
			statistics.total_runs,
			statistics.wins,
			statistics.losses,
			statistics.stalkers_killed,
			statistics.artifacts_stolen,
			statistics.best_survival_wave
		]


func _update_station_button(station: Button, station_name: String, total_levels: int):
	var name_label = station.get_node_or_null("StationName")
	if name_label and name_label is Label:
		name_label.text = station_name
	
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


# ==================== КАМПАНИЯ ====================

func _setup_campaign_selector():
	"""Селектор уровня кампании в шапке лаборатории: ◀ уровень ▶ и режим сложности"""
	var header: HBoxContainer = get_node_or_null("VBox/Header")
	if not header:
		print("lab_controller: Header не найден, селектор кампании не построен")
		return

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)

	_campaign_label = Label.new()
	_campaign_label.add_theme_font_size_override("font_size", 16)

	_run_mode_button = Button.new()
	_run_mode_button.text = "Кампания"
	_campaign_prev_button = Button.new()
	_campaign_prev_button.text = "◀"
	_campaign_next_button = Button.new()
	_campaign_next_button.text = "▶"
	_campaign_mode_button = Button.new()

	row.add_child(_run_mode_button)
	row.add_child(_campaign_prev_button)
	row.add_child(_campaign_label)
	row.add_child(_campaign_next_button)
	row.add_child(_campaign_mode_button)
	header.add_child(row)

	_run_mode_button.pressed.connect(_on_run_mode_pressed)
	_campaign_prev_button.pressed.connect(_on_campaign_prev_pressed)
	_campaign_next_button.pressed.connect(_on_campaign_next_pressed)
	_campaign_mode_button.pressed.connect(_on_campaign_mode_pressed)
	for btn in [_run_mode_button, _campaign_prev_button, _campaign_next_button, _campaign_mode_button]:
		btn.mouse_entered.connect(_play_hover_sound)


func _refresh_campaign_ui():
	if not game_manager or not _campaign_label:
		return

	# Режим забега определяет, что показывает строка
	var is_survival: bool = game_manager.get_selected_run_mode() == "survival"
	_run_mode_button.text = "Выживание" if is_survival else "Кампания"
	# Множитель сложности применяется в обоих режимах
	_campaign_mode_button.text = "Сложность: %s" % CampaignData.get_mode_name(game_manager.get_campaign_mode())

	if is_survival:
		var record: int = 0
		var stats = game_manager.get_statistics()
		if stats:
			record = stats.best_survival_wave
		_campaign_label.text = "ВЫЖИВАНИЕ - волны без предела, награда за каждую (рекорд: %d)" % record
		_campaign_prev_button.disabled = true
		_campaign_next_button.disabled = true
		return

	var frontier: int = game_manager.get_campaign_level()
	_campaign_level = clampi(_campaign_level, 1, frontier)

	var params: Dictionary = CampaignData.get_level_params(_campaign_level, game_manager.get_campaign_mode())
	var text: String
	if params.get("is_boss", false):
		text = "КАРАВАН %d/100: «%s»" % [_campaign_level, params.get("title", "")]
	else:
		text = "Уровень %d/100 - %s" % [_campaign_level, params.get("chapter_title", "")]
	if _campaign_level < frontier:
		text += " (пройден)"
	if game_manager.is_campaign_completed() and _campaign_level >= CampaignData.TOTAL_LEVELS:
		text = "КАМПАНИЯ ПРОЙДЕНА! Финальный уровень: 100/100"
	_campaign_label.text = text

	_campaign_prev_button.disabled = _campaign_level <= 1
	_campaign_next_button.disabled = _campaign_level >= frontier
	_campaign_mode_button.text = "Сложность: %s" % CampaignData.get_mode_name(game_manager.get_campaign_mode())


func _on_run_mode_pressed():
	"""Переключение режима забега: кампания <-> выживание"""
	_play_click_sound()
	if not game_manager:
		return

	var next_mode: String = "survival"
	if game_manager.get_selected_run_mode() == "survival":
		next_mode = "campaign"

	game_manager.set_selected_run_mode(next_mode)
	_refresh_campaign_ui()


func _on_campaign_prev_pressed():
	_play_click_sound()
	_campaign_level = maxi(1, _campaign_level - 1)
	_refresh_campaign_ui()


func _on_campaign_next_pressed():
	_play_click_sound()
	var frontier: int = game_manager.get_campaign_level() if game_manager else 1
	_campaign_level = mini(frontier, _campaign_level + 1)
	_refresh_campaign_ui()


func _on_campaign_mode_pressed():
	"""Цикл режимов сложности: Сталкер -> Ветеран -> Легенда"""
	_play_click_sound()
	if not game_manager:
		return

	var current: String = game_manager.get_campaign_mode()
	var next_mode: String = CampaignData.MODE_EASY
	if current == CampaignData.MODE_EASY:
		next_mode = CampaignData.MODE_NORMAL
	elif current == CampaignData.MODE_NORMAL:
		next_mode = CampaignData.MODE_HARD

	game_manager.set_campaign_mode(next_mode)
	_refresh_campaign_ui()


# ==================== ОБРАБОТЧИКИ ====================

func _on_start_run_pressed():
	_play_click_sound()
	run_started.emit()
	
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		# Выбранный в селекторе уровень кампании уходит в параметры забега
		game_manager.selected_campaign_level = _campaign_level
		print("Запуск забега через GameManager (уровень кампании %d)" % _campaign_level)
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


func _setup_settings_sliders():
	"""Слайдеры громкости лаборатории - те же аудиошины Music/SFX,
	что и в главном меню (значения глобальные)"""
	settings_music_slider.value_changed.connect(
		func(v): _set_bus_volume("Music", v))
	settings_sfx_slider.value_changed.connect(
		func(v): _set_bus_volume("SFX", v))
	var music_idx = AudioServer.get_bus_index("Music")
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if music_idx >= 0:
		settings_music_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(music_idx)))
	if sfx_idx >= 0:
		settings_sfx_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(sfx_idx)))


func _setup_save_slot_selector():
	"""Выбор активного слота сохранения между слайдерами и кнопкой НАЗАД"""
	var panel = get_node_or_null("SettingsScreen/Panel")
	if not panel:
		print("lab_controller: SettingsScreen/Panel не найден, селектор слота не построен")
		return

	var selector := SaveSlotSelector.new()
	selector.position = Vector2(30, 202)
	selector.size = Vector2(340, 28)
	panel.add_child(selector)


func _set_bus_volume(bus_name: String, value: float):
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(max(value, 0.0001)))
		AudioServer.set_bus_mute(idx, value <= 0.001)


func _on_settings_back_pressed():
	_play_click_sound()
	settings_screen.visible = false


# ==================== МАГАЗИН ====================

func _on_shop_pressed():
	_play_click_sound()
	shop_panel.visible = true
	_rebuild_shop()


func _on_shop_close_pressed():
	_play_click_sound()
	shop_panel.visible = false


func _rebuild_shop():
	"""Кнопки магазина из таблиц GachaData: имя + цена, покупка за биомассу лаборатории"""
	for child in mutant_grid.get_children():
		child.queue_free()
	for child in artifact_grid.get_children():
		child.queue_free()
	var lab_biomass: float = lab_data.biomass if lab_data else 0.0
	shop_biomass_label.text = "Биомасса лаборатории: " + str(int(lab_biomass))
	for entry in GachaData.get_shop_mutants():
		var type: String = entry[0]
		var price: float = entry[2]
		var btn := Button.new()
		btn.text = _shop_item_text(entry[1], type, true) + "
🧬" + str(int(price))
		btn.custom_minimum_size = Vector2(160, 34)
		btn.pressed.connect(_on_shop_buy.bind("mutant", type, price))
		mutant_grid.add_child(btn)
	for entry in GachaData.get_shop_artifacts():
		var type: String = entry[0]
		var price: float = entry[2]
		var btn := Button.new()
		btn.text = _shop_item_text(entry[1], type, false) + "
🧬" + str(int(price))
		btn.custom_minimum_size = Vector2(240, 34)
		btn.pressed.connect(_on_shop_buy.bind("artifact", type, price))
		artifact_grid.add_child(btn)


func _shop_item_text(item_name: String, type: String, is_mutant: bool) -> String:
	"""Имя + звёзды, если тип уже в коллекции (в бою получит эти звёзды)"""
	if not lab_data:
		return item_name
	var stars: int = lab_data.get_mutant_stars(type) if is_mutant else lab_data.get_artifact_stars(type)
	var owned: bool = lab_data.unlocked_mutants.has(type) if is_mutant else lab_data.won_artifacts.has(type)
	if owned and stars > 1:
		return item_name + " " + "★".repeat(stars)
	if owned:
		return item_name + " ★"
	return item_name


func _on_shop_buy(kind: String, item_type: String, price: float):
	var bought := false
	if kind == "mutant":
		bought = game_manager.buy_shop_mutant(item_type, price)
	else:
		bought = game_manager.buy_shop_artifact(item_type, price)
	if bought:
		_play_click_sound()
		_rebuild_shop()
	else:
		_show_message("Недостаточно биомассы в лаборатории", 1.5)


# ==================== ЗВЁЗДНОСТЬ ====================

var star_panel: Control
var star_biomass_label: Label
var star_list: VBoxContainer


func _build_star_ui():
	"""Кнопка ★ в магазине + панель прокачки звёзд (строится кодом)"""
	var shop_inner: Panel = shop_panel.get_node_or_null("Panel")
	if shop_inner:
		var open_btn := Button.new()
		open_btn.name = "StarOpenButton"
		open_btn.text = "★ ЗВЁЗДЫ"
		open_btn.position = Vector2(390, 8)
		open_btn.size = Vector2(150, 30)
		open_btn.pressed.connect(_on_stars_pressed)
		open_btn.mouse_entered.connect(_play_hover_sound)
		shop_inner.add_child(open_btn)

	star_panel = Control.new()
	star_panel.name = "StarPanel"
	star_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	star_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	star_panel.visible = false
	add_child(star_panel)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.6)
	star_panel.add_child(shade)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -210.0
	panel.offset_right = 280.0
	panel.offset_bottom = 210.0
	star_panel.add_child(panel)

	var title := Label.new()
	title.text = "ПРОКАЧКА ЗВЁЗД - дубли гачи дают звезду, звёзды дают статы"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position = Vector2(0, 10)
	title.size = Vector2(560, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	star_biomass_label = Label.new()
	star_biomass_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	star_biomass_label.position = Vector2(0, 36)
	star_biomass_label.size = Vector2(560, 20)
	star_biomass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(star_biomass_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 64)
	scroll.size = Vector2(520, 288)
	panel.add_child(scroll)

	star_list = VBoxContainer.new()
	star_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	star_list.add_theme_constant_override("separation", 4)
	scroll.add_child(star_list)

	var close_btn := Button.new()
	close_btn.text = "НАЗАД"
	close_btn.position = Vector2(200, 362)
	close_btn.size = Vector2(160, 35)
	close_btn.pressed.connect(_on_stars_close_pressed)
	close_btn.mouse_entered.connect(_play_hover_sound)
	panel.add_child(close_btn)


func _on_stars_pressed():
	_play_click_sound()
	shop_panel.visible = false
	star_panel.visible = true
	_rebuild_star_panel()


func _on_stars_close_pressed():
	_play_click_sound()
	star_panel.visible = false


func _rebuild_star_panel():
	"""Строка на каждого питомца коллекции: имя, звёзды, цена следующей звезды"""
	for child in star_list.get_children():
		child.queue_free()
	if not lab_data:
		return
	star_biomass_label.text = "Биомасса лаборатории: %d   (цена звезды: 500 → 1000 → 2000 → 4000)" % int(lab_data.biomass)

	var mutants: Array[String] = []
	for t in lab_data.unlocked_mutants:
		if not mutants.has(t):
			mutants.append(t)
	var artifacts: Array[String] = []
	for t in lab_data.won_artifacts:
		if not artifacts.has(t):
			artifacts.append(t)

	if mutants.is_empty() and artifacts.is_empty():
		var empty := Label.new()
		empty.text = "Коллекция пуста.\nВыигрывайте мутантов и артефакты в гаче и за вехи волн:\nдубликат уже имеющегося даёт +1 звезду автоматически."
		star_list.add_child(empty)
		return

	if not mutants.is_empty():
		star_list.add_child(_make_star_section("МУТАНТЫ (+20% HP и урона за звезду)"))
	for type in mutants:
		star_list.add_child(_make_star_row("mutant", type))
	if not artifacts.is_empty():
		star_list.add_child(_make_star_section("АРТЕФАКТЫ (+20% награды за звезду)"))
	for type in artifacts:
		star_list.add_child(_make_star_row("artifact", type))


func _make_star_section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _make_star_row(kind: String, type: String) -> Control:
	var row := HBoxContainer.new()
	var stars: int = lab_data.get_mutant_stars(type) if kind == "mutant" else lab_data.get_artifact_stars(type)

	var name_label := Label.new()
	name_label.text = "%s  %s" % [GachaData.display_name(type), LabData.stars_text(stars)]
	name_label.tooltip_text = "Множитель статов: x%.1f" % LabData.get_star_stat_mult(stars)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	if stars >= LabData.MAX_STARS:
		var max_label := Label.new()
		max_label.text = "МАКС"
		row.add_child(max_label)
	else:
		var cost := lab_data.get_star_upgrade_cost(stars)
		var btn := Button.new()
		btn.text = "🧬 " + str(int(cost))
		btn.pressed.connect(_on_star_upgrade.bind(kind, type))
		btn.mouse_entered.connect(_play_hover_sound)
		row.add_child(btn)
	return row


func _on_star_upgrade(kind: String, type: String):
	_play_click_sound()
	var ok := false
	if kind == "mutant":
		ok = game_manager.upgrade_mutant_star(type)
	else:
		ok = game_manager.upgrade_artifact_star(type)
	if ok:
		lab_data = game_manager.get_lab_data()
		_rebuild_star_panel()
		if shop_panel.visible:
			_rebuild_shop()
		_refresh_ui()
	else:
		_show_message("Недостаточно биомассы или звёзды максимальны", 1.5)


func _on_settings_pressed():
	_play_click_sound()
	settings_opened.emit()
	settings_screen.visible = true


func _on_save_pressed():
	_play_click_sound()

	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")

	if game_manager and game_manager.has_method("save_to_active_slot"):
		game_manager.save_to_active_slot()
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


func _on_upgrade_purchased(_upgrade_type: String):
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
