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
	_apply_static_texts()
	_refresh_ui()
	_setup_campaign_selector()
	_refresh_campaign_ui()
	_build_star_ui()
	_build_farm_ui()
	_build_gacha_ui()
	_build_language_button()
	Loc.changed.connect(_apply_static_texts)
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


func _apply_static_texts():
	"""Все статические надписи лаборатории по текущему языку (Loc.changed пере apply)"""
	var title: Label = get_node_or_null("VBox/Header/Title")
	if title:
		title.text = Loc.t("lab.title")
	var info: Label = get_node_or_null("VBox/InfoPanel/HBox/InfoLabel")
	if info:
		info.text = Loc.t("lab.info_header")
	var biomass_prefix: Label = get_node_or_null("VBox/InfoPanel/HBox/BiomassLabel")
	if biomass_prefix:
		biomass_prefix.text = Loc.t("lab.biomass_prefix")
	start_run_button.text = Loc.t("lab.start_run")
	menu_button.text = Loc.t("lab.menu")
	settings_button.text = Loc.t("lab.settings")
	shop_button.text = Loc.t("lab.shop")
	save_button.text = Loc.t("lab.save")
	artifact_storage_button.text = Loc.t("lab.storage_open")
	var storage_label: Label = get_node_or_null("VBox/StoragePanel/HBox/StorageLabel")
	if storage_label:
		storage_label.text = Loc.t("lab.storage")
	var settings_title: Label = get_node_or_null("SettingsScreen/Panel/SettingsTitle")
	if settings_title:
		settings_title.text = Loc.t("lab.settings")
	var music_label: Label = get_node_or_null("SettingsScreen/Panel/MusicLabel")
	if music_label:
		music_label.text = Loc.t("lab.settings_music")
	var sfx_label: Label = get_node_or_null("SettingsScreen/Panel/SfxLabel")
	if sfx_label:
		sfx_label.text = Loc.t("lab.settings_sfx")
	var settings_back: Button = get_node_or_null("SettingsScreen/Panel/BackButton")
	if settings_back:
		settings_back.text = Loc.t("lab.back")
	var shop_title: Label = get_node_or_null("ShopPanel/Panel/ShopTitle")
	if shop_title:
		shop_title.text = Loc.t("shop.title")
	var mutants_header: Label = get_node_or_null("ShopPanel/Panel/MutantsHeader")
	if mutants_header:
		mutants_header.text = Loc.t("shop.mutants_header")
	var artifacts_header: Label = get_node_or_null("ShopPanel/Panel/ArtifactsHeader")
	if artifacts_header:
		artifacts_header.text = Loc.t("shop.artifacts_header")
	var shop_close: Button = get_node_or_null("ShopPanel/Panel/ShopClose")
	if shop_close:
		shop_close.text = Loc.t("lab.back")
	# Панели звёзд/фермы (строятся кодом) - перезаполнить
	if star_panel and star_panel.visible:
		_rebuild_star_panel()
	if farm_panel and farm_panel.visible:
		_rebuild_farm_panel()
	# Языковая кнопка показывает текущий язык
	if _lang_button:
		_lang_button.text = Loc.t("menu.language")


func _play_click_sound():
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.6)


func _refresh_ui():
	if not lab_data:
		print("lab_data отсутствует, создаем новый")
		lab_data = LabData.new()
	
	run_number_label.text = Loc.t("lab.day", {"n": lab_data.run_number})
	biomass_label.text = _format_number(lab_data.biomass)
	
	_update_station_button(anomaly_station, Loc.t("lab.anomalies"), lab_data.get_total_anomaly_levels())
	_update_station_button(mutant_station, Loc.t("lab.mutants"), lab_data.get_total_mutant_levels())
	_update_station_button(monolith_station, Loc.t("lab.monolith"), lab_data.get_total_monolith_levels())
	
	var common = lab_data.get_artifact_count("common")
	var rare = lab_data.get_artifact_count("rare")
	var legendary = lab_data.get_artifact_count("legendary")
	artifact_counts_label.text = Loc.t("lab.storage_counts", {"c": common, "r": rare, "l": legendary})
	
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
		level_label.text = Loc.t("lab.level_short", {"n": total_levels})


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
	shop_biomass_label.text = Loc.t("shop.biomass", {"n": int(lab_biomass)})
	for entry in GachaData.get_shop_mutants():
		var type: String = entry[0]
		var price: float = entry[2]
		var btn := Button.new()
		if lab_data and not lab_data.unlocked_mutants.has(type):
			btn.disabled = true
			btn.text = entry[1] + "
" + Loc.t("shop.locked", {"n": GachaData.get_unlock_campaign_level(type)})
		else:
			btn.text = _shop_item_text(entry[1], type, true) + "
🧬" + str(int(price))
			btn.pressed.connect(_on_shop_buy.bind("mutant", type, price))
		_add_card_icon(btn, type, true)
		btn.custom_minimum_size = Vector2(160, 34)
		mutant_grid.add_child(btn)
	for entry in GachaData.get_shop_artifacts():
		var type: String = entry[0]
		var price: float = entry[2]
		var btn := Button.new()
		if lab_data and not lab_data.won_artifacts.has(type):
			btn.disabled = true
			btn.text = entry[1] + "
" + Loc.t("shop.locked", {"n": GachaData.get_unlock_campaign_level(type)})
		else:
			btn.text = _shop_item_text(entry[1], type, false) + "
🧬" + str(int(price))
			btn.pressed.connect(_on_shop_buy.bind("artifact", type, price))
		_add_card_icon(btn, type, false)
		btn.custom_minimum_size = Vector2(240, 34)
		artifact_grid.add_child(btn)


func _add_card_icon(btn: Button, type: String, is_mutant: bool):
	"""Карточка-иконка слева от текста кнопки (магазин/дропы/ферма)"""
	var path: String = GachaData.card_icon_path(type, is_mutant)
	if ResourceLoader.exists(path):
		btn.icon = load(path)
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 26)


func _make_icon_rect(type: String, is_mutant: bool, size: int = 24) -> TextureRect:
	var rect := TextureRect.new()
	var path: String = GachaData.card_icon_path(type, is_mutant)
	if ResourceLoader.exists(path):
		rect.texture = load(path)
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


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
		_show_message(Loc.t("shop.not_enough"), 1.5)


# ==================== ЗВЁЗДНОСТЬ ====================

var star_panel: Control
var star_biomass_label: Label
var star_list: VBoxContainer


func _build_star_ui():
	"""Кнопка ★ в магазине + панель прокачки звёзд (строится кодом)"""
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
	title.text = Loc.t("stars.title")
	title.position = Vector2(0, 10)
	title.size = Vector2(560, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	star_biomass_label = Label.new()
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
	farm_panel.visible = false
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
	star_biomass_label.text = Loc.t("stars.biomass_line", {"n": int(lab_data.biomass)})

	var artifacts: Array[String] = []
	for t in lab_data.won_artifacts:
		if not artifacts.has(t):
			artifacts.append(t)

	if artifacts.is_empty():
		var empty := Label.new()
		empty.text = Loc.t("stars.artifacts_only")
		star_list.add_child(empty)
		return

	star_list.add_child(_make_star_section(Loc.t("stars.artifacts_header")))
	for type in artifacts:
		star_list.add_child(_make_star_row("artifact", type))


func _make_star_section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _make_star_row(kind: String, type: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_icon_rect(type, kind == "mutant", 26))
	var stars: int = lab_data.get_mutant_stars(type) if kind == "mutant" else lab_data.get_artifact_stars(type)

	var name_label := Label.new()
	name_label.text = "%s  %s" % [GachaData.display_name(type), LabData.stars_text(stars)]
	name_label.tooltip_text = Loc.t("stars.mult_tip", {"n": "%.1f" % LabData.get_star_stat_mult(stars)})
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	if stars >= LabData.MAX_STARS:
		var max_label := Label.new()
		max_label.text = Loc.t("stars.max")
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
		_show_message(Loc.t("stars.fail_msg"), 1.5)


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

# ==================== ФЕРМА МУТАНТОВ ====================

var farm_panel: Control
var farm_list: VBoxContainer
var farm_title_label: Label
# Режим кормления: [fodder_type] или []
var _feed_fodder: Array = []


func _build_farm_ui():
	"""Кнопка ФЕРМА в нижнем ряду + панель копий и кормления (строится кодом)"""
	var bottom: HBoxContainer = get_node_or_null("VBox/BottomButtons")
	if bottom:
		var farm_btn := Button.new()
		farm_btn.name = "FarmButton"
		farm_btn.text = Loc.t("lab.farm")
		farm_btn.pressed.connect(_on_farm_pressed)
		farm_btn.mouse_entered.connect(_play_hover_sound)
		bottom.add_child(farm_btn)

	farm_panel = Control.new()
	farm_panel.name = "FarmPanel"
	farm_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	farm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	farm_panel.visible = false
	add_child(farm_panel)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.6)
	farm_panel.add_child(shade)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -210.0
	panel.offset_right = 280.0
	panel.offset_bottom = 210.0
	farm_panel.add_child(panel)

	var star_btn := Button.new()
	star_btn.text = Loc.t("shop.stars")
	star_btn.position = Vector2(390, 8)
	star_btn.size = Vector2(150, 30)
	star_btn.pressed.connect(_on_stars_pressed)
	star_btn.mouse_entered.connect(_play_hover_sound)
	panel.add_child(star_btn)

	farm_title_label = Label.new()
	farm_title_label.position = Vector2(0, 10)
	farm_title_label.size = Vector2(560, 25)
	farm_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(farm_title_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 44)
	scroll.size = Vector2(520, 308)
	panel.add_child(scroll)

	farm_list = VBoxContainer.new()
	farm_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	farm_list.add_theme_constant_override("separation", 4)
	scroll.add_child(farm_list)

	var close_btn := Button.new()
	close_btn.text = Loc.t("lab.back")
	close_btn.position = Vector2(200, 362)
	close_btn.size = Vector2(160, 35)
	close_btn.pressed.connect(_on_farm_close_pressed)
	close_btn.mouse_entered.connect(_play_hover_sound)
	panel.add_child(close_btn)


func _on_farm_pressed():
	_play_click_sound()
	shop_panel.visible = false
	star_panel.visible = false
	_feed_fodder.clear()
	farm_panel.visible = true
	_rebuild_farm_panel()


func _on_farm_close_pressed():
	_play_click_sound()
	farm_panel.visible = false


func _rebuild_farm_panel():
	"""Копии на ферме: '+★' (копия того же типа) и 'кормить' (копия другому типу)"""
	for child in farm_list.get_children():
		child.queue_free()
	if not lab_data:
		return
	farm_title_label.text = Loc.t("farm.title")

	# Режим кормления: цель должна получать корм СВОЕЙ звёздности
	if not _feed_fodder.is_empty():
		var fodder_type: String = _feed_fodder[0]
		var points: int = GachaData.get_fodder_value(fodder_type, true)
		var fodder_stars: int = lab_data.get_mutant_stars(fodder_type)
		farm_list.add_child(_make_farm_section(Loc.t("farm.fodder_star_rule", {"fodder": Loc.type_name(fodder_type), "points": points, "stars": fodder_stars})))
		var cancel := Button.new()
		cancel.text = Loc.t("lab.back")
		cancel.pressed.connect(_on_feed_cancel)
		farm_list.add_child(cancel)
		var target_stars: int = fodder_stars
		var found := false
		for type in lab_data.unlocked_mutants:
			if type == fodder_type or lab_data.get_farm_copies(type) <= 0:
				continue
			if lab_data.get_mutant_stars(type) != target_stars:
				continue  # корм той же звёздности, что и цель
			found = true
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.add_child(_make_icon_rect(type, true, 26))
			var stars: int = lab_data.get_mutant_stars(type)
			var name_label := Label.new()
			name_label.text = "%s %s (%s)" % [Loc.type_name(type), LabData.stars_text(stars), Loc.t("farm.progress", {"cur": lab_data.get_star_progress(type), "need": GachaData.get_star_feed_cost(stars)})]
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			var btn := Button.new()
			btn.text = Loc.t("farm.feed_btn")
			btn.pressed.connect(_on_feed_confirm.bind(type))
			row.add_child(btn)
			farm_list.add_child(row)
		if not found:
			var none := Label.new()
			none.text = Loc.t("farm.no_matching_fodder", {"n": target_stars})
			farm_list.add_child(none)
		return

	# Обычный режим: строки с рецептом звезды
	farm_list.add_child(_make_farm_section(Loc.t("farm.recipe")))
	var any_row := false
	for type in lab_data.unlocked_mutants:
		var req: Dictionary = game_manager.get_star_requirements(type)
		if int(req.get("copies_have")) <= 0 and int(req.get("points_have")) <= 0:
			continue
		any_row = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_make_icon_rect(type, true, 26))
		var stars: int = int(req.get("stars"))
		var name_label := Label.new()
		name_label.text = "%s %s - %s, %s" % [
			Loc.type_name(type), LabData.stars_text(stars),
			Loc.t("farm.copies_need", {"have": int(req.get("copies_have")), "need": int(req.get("copies_need"))}),
			Loc.t("farm.points_need", {"have": int(req.get("points_have")), "need": int(req.get("points_need"))})]
		name_label.tooltip_text = Loc.t("farm.value_tip", {"points": GachaData.get_fodder_value(type, true)})
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if bool(req.get("max")):
			var max_label := Label.new()
			max_label.text = Loc.t("stars.max")
			row.add_child(max_label)
		else:
			var up_btn := Button.new()
			up_btn.text = Loc.t("farm.upgrade_btn", {"n": stars + 1})
			up_btn.disabled = not bool(req.get("ready"))
			up_btn.pressed.connect(_on_farm_upgrade.bind(type))
			row.add_child(up_btn)
			if lab_data.get_farm_copies(type) > 0:
				var feed_btn := Button.new()
				feed_btn.text = Loc.t("farm.feed_btn")
				feed_btn.pressed.connect(_on_farm_feed_pressed.bind(type))
				row.add_child(feed_btn)
		farm_list.add_child(row)

	if not any_row:
		var empty := Label.new()
		empty.text = Loc.t("farm.empty")
		farm_list.add_child(empty)


func _make_farm_section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _on_farm_upgrade(type: String):
	_play_click_sound()
	var msg: String = game_manager.try_upgrade_star(type)
	_show_message(msg, 2.0)
	_rebuild_farm_panel()
	_refresh_ui()


func _on_farm_feed_pressed(type: String):
	_play_click_sound()
	_feed_fodder = [type]
	_rebuild_farm_panel()


func _on_feed_cancel():
	_play_click_sound()
	_feed_fodder.clear()
	_rebuild_farm_panel()


func _on_feed_confirm(target_type: String):
	_play_click_sound()
	var msg: String = game_manager.feed_fodder(_feed_fodder[0], target_type)
	_show_message(msg, 2.0)
	_feed_fodder.clear()
	_rebuild_farm_panel()
	_refresh_ui()


# ==================== ЯЗЫК ====================

var _lang_button: Button = null


func _build_language_button():
	"""Кнопка RU/EN в настройках лаборатории"""
	var panel = get_node_or_null("SettingsScreen/Panel")
	if not panel:
		return
	_lang_button = Button.new()
	_lang_button.text = Loc.t("menu.language")
	_lang_button.position = Vector2(30, 262)
	_lang_button.size = Vector2(340, 34)
	_lang_button.pressed.connect(_on_language_pressed)
	_lang_button.mouse_entered.connect(_play_hover_sound)
	panel.add_child(_lang_button)


func _on_language_pressed():
	_play_click_sound()
	Loc.toggle()


# ==================== ГАЧА ====================

var gacha_panel: Control
var gacha_list: VBoxContainer
# Сессионная статистика шансов: [всего, common, uncommon, rare, legendary]
var _mutant_spin_stats: Array = [0, 0, 0, 0, 0]
var _artifact_spin_stats: Array = [0, 0, 0, 0, 0]
# Последние дропы для показа
var _mutant_last_drops: Array = []
var _artifact_last_drops: Array = []


func _build_gacha_ui():
	"""Кнопка ГАЧА в нижнем ряду + панель круток со статистикой шансов"""
	var bottom: HBoxContainer = get_node_or_null("VBox/BottomButtons")
	if bottom:
		var gacha_btn := Button.new()
		gacha_btn.name = "GachaButton"
		gacha_btn.text = "ГАЧА"
		gacha_btn.pressed.connect(_on_gacha_pressed)
		gacha_btn.mouse_entered.connect(_play_hover_sound)
		bottom.add_child(gacha_btn)

	gacha_panel = Control.new()
	gacha_panel.name = "GachaPanel"
	gacha_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	gacha_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	gacha_panel.visible = false
	add_child(gacha_panel)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.6)
	gacha_panel.add_child(shade)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -210.0
	panel.offset_right = 280.0
	panel.offset_bottom = 210.0
	gacha_panel.add_child(panel)

	var title := Label.new()
	title.text = Loc.t("gacha.title")
	title.position = Vector2(0, 10)
	title.size = Vector2(560, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 44)
	scroll.size = Vector2(520, 308)
	panel.add_child(scroll)

	gacha_list = VBoxContainer.new()
	gacha_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gacha_list.add_theme_constant_override("separation", 4)
	scroll.add_child(gacha_list)

	var close_btn := Button.new()
	close_btn.text = Loc.t("lab.back")
	close_btn.position = Vector2(200, 362)
	close_btn.size = Vector2(160, 35)
	close_btn.pressed.connect(_on_gacha_close_pressed)
	close_btn.mouse_entered.connect(_play_hover_sound)
	panel.add_child(close_btn)


func _on_gacha_pressed():
	_play_click_sound()
	shop_panel.visible = false
	farm_panel.visible = false
	star_panel.visible = false
	gacha_panel.visible = true
	_rebuild_gacha_panel()


func _on_gacha_close_pressed():
	_play_click_sound()
	gacha_panel.visible = false


func _gacha_spin_buttons(kind: String) -> Control:
	"""Ряд кнопок круток x1/x10/x100/x1000"""
	var row := HBoxContainer.new()
	for times in [1, 10, 100, 1000]:
		var btn := Button.new()
		btn.text = "x%d" % times
		btn.custom_minimum_size = Vector2(70, 30)
		btn.pressed.connect(_on_gacha_spin.bind(kind, times))
		btn.mouse_entered.connect(_play_hover_sound)
		row.add_child(btn)
	return row


func _on_gacha_spin(kind: String, times: int):
	_play_click_sound()
	var results: Array = []
	if kind == "mutants":
		results = game_manager.spin_mutant_gacha(times)
		for r in results:
			_mutant_spin_stats[0] += 1
			var idx: int = {"common": 1, "uncommon": 2, "rare": 3, "legendary": 4}.get(str(r.get("rarity")), 1)
			_mutant_spin_stats[idx] += 1
			_mutant_last_drops.push_front(r)
			while _mutant_last_drops.size() > 8:
				_mutant_last_drops.pop_back()
	else:
		results = game_manager.spin_artifact_gacha(times)
		for r in results:
			_artifact_spin_stats[0] += 1
			var idx: int = {"common": 1, "uncommon": 2, "rare": 3, "legendary": 4}.get(str(r.get("rarity")), 1)
			_artifact_spin_stats[idx] += 1
			_artifact_last_drops.push_front(r)
			while _artifact_last_drops.size() > 8:
				_artifact_last_drops.pop_back()
	if results.is_empty():
		_show_message(Loc.t("gacha.no_rolls"), 1.5)
	_rebuild_gacha_panel()
	_refresh_ui()


func _make_drop_row(r: Dictionary, is_mutant: bool) -> Control:
	"""Строка дропа гачи: карточка-иконка + имя, окрашенное по редкости"""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_icon_rect(str(r.get("type", "")), is_mutant, 24))
	var label := Label.new()
	label.text = _format_drop(r)
	label.add_theme_color_override("font_color", GachaData.rarity_color(str(r.get("rarity", "common"))))
	return row


func _format_drop(r: Dictionary) -> String:
	var rarity: String = str(r.get("rarity", "common"))
	var line: String = "[%s] %s" % [Loc.t("rarity." + rarity), Loc.type_name(str(r.get("type")))]
	match str(r.get("status", "")):
		"new":
			line += " - " + Loc.t("gacha.new_mark")
		"dup":
			line += " - " + Loc.t("gacha.dup_mark")
		"star":
			line += " - " + Loc.t("gacha.star_mark")
	return line


func _gacha_stats_line(stats: Array, has_uncommon: bool) -> String:
	var total: int = stats[0]
	if total <= 0:
		return ""
	var pct := func(n: int) -> String:
		return "%.1f" % (100.0 * float(n) / float(total))
	if has_uncommon:
		return Loc.t("gacha.stats", {"n": total, "cp": pct.call(stats[1]), "up": pct.call(stats[2]), "rp": pct.call(stats[3]), "lp": pct.call(stats[4])})
	return Loc.t("gacha.stats_short", {"n": total, "cp": pct.call(stats[1]), "rp": pct.call(stats[3]), "lp": pct.call(stats[4])})


func _rebuild_gacha_panel():
	"""Два рукава гачи: крутки, кнопки, статистика шансов, последние дропы"""
	for child in gacha_list.get_children():
		child.queue_free()
	if not lab_data or not game_manager:
		return

	var level_line := Label.new()
	level_line.text = Loc.t("gacha.level_used", {"n": game_manager.get_campaign_level()})
	gacha_list.add_child(level_line)

	# === МУТАНТЫ ===
	gacha_list.add_child(_make_star_section(Loc.t("gacha.mutants_header")))
	var mut_rolls := Label.new()
	mut_rolls.text = Loc.t("gacha.rolls", {"n": lab_data.gacha_rolls_mutants})
	gacha_list.add_child(mut_rolls)
	gacha_list.add_child(_gacha_spin_buttons("mutants"))
	var mut_stats := Label.new()
	mut_stats.text = _gacha_stats_line(_mutant_spin_stats, true)
	if not mut_stats.text.is_empty():
		gacha_list.add_child(mut_stats)
	if not _mutant_last_drops.is_empty():
		gacha_list.add_child(_make_star_section(Loc.t("gacha.last_drops")))
		for r in _mutant_last_drops:
			gacha_list.add_child(_make_drop_row(r, true))

	# === АРТЕФАКТЫ ===
	gacha_list.add_child(_make_star_section(Loc.t("gacha.artifacts_header")))
	var art_rolls := Label.new()
	art_rolls.text = Loc.t("gacha.rolls", {"n": lab_data.gacha_rolls_artifacts})
	gacha_list.add_child(art_rolls)
	gacha_list.add_child(_gacha_spin_buttons("artifacts"))
	var art_stats := Label.new()
	art_stats.text = _gacha_stats_line(_artifact_spin_stats, false)
	if not art_stats.text.is_empty():
		gacha_list.add_child(art_stats)
	if not _artifact_last_drops.is_empty():
		gacha_list.add_child(_make_star_section(Loc.t("gacha.last_drops")))
		for r in _artifact_last_drops:
			gacha_list.add_child(_make_drop_row(r, false))
