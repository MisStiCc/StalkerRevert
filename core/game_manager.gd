# core/game_manager.gd
extends Node
## Глобальный менеджер игры (автозагрузка)

signal game_loaded(save_data)
signal game_saved(slot)
signal scene_changed(scene_name)

# Текущее состояние
var current_save_data = null
var is_in_lab: bool = true
var is_loading: bool = false
var current_scene_name: String = ""

# Уровень кампании, выбранный в лаборатории для следующего забега.
# 0 = идти на текущий рубеж (campaign_level сейва)
var selected_campaign_level: int = 0

# Константы
const SAVE_DIR = "user://saves/"
const SAVE_FILE_PREFIX = "save_"
const SAVE_FILE_EXT = ".tres"
# Настройки клиента (вне сейвов): активный слот сохранения
const SETTINGS_PATH = "user://settings.cfg"
const AUTOSAVE_SLOT = 0
const MANUAL_SLOTS = 3

# Активный слот: 0 - автосейв, 1..3 - ручные слоты. Выбирается в настройках,
# привязывается при загрузке слота через главное меню
var active_save_slot: int = 0


func _ready():
	add_to_group("game_manager")
	print("GameManager: инициализирован")
	_create_save_directory()
	_load_settings()
	_load_boot_save()
	Signals.game_started.emit()


func _create_save_directory():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
	print("Директория сохранений создана")


# ==================== НАСТРОЙКИ КЛИЕНТА ====================

func _load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		active_save_slot = clampi(int(cfg.get_value("game", "active_save_slot", AUTOSAVE_SLOT)), AUTOSAVE_SLOT, MANUAL_SLOTS)
	print("Активный слот сохранения: " + ("автосейв" if active_save_slot == AUTOSAVE_SLOT else str(active_save_slot)))


func _save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("game", "active_save_slot", active_save_slot)
	var error = cfg.save(SETTINGS_PATH)
	if error != OK:
		print("Не удалось сохранить настройки: код " + str(error))


func get_active_save_slot() -> int:
	return active_save_slot


func set_active_save_slot(slot: int) -> bool:
	if slot < AUTOSAVE_SLOT or slot > MANUAL_SLOTS:
		return false
	active_save_slot = slot
	_save_settings()
	return true


## Сохранить прогресс в активный слот (автосейвы и UI-кнопки)
func save_to_active_slot() -> bool:
	return save_game(active_save_slot)


func _load_boot_save():
	# При старте подхватываем сохранение активного слота: автосейв или ручной
	var path = SAVE_DIR + SAVE_FILE_PREFIX + str(active_save_slot) + SAVE_FILE_EXT
	if FileAccess.file_exists(path):
		var save = load(path)
		if save and save is SaveData:
			current_save_data = save
			_migrate_campaign_progress(save)
			print("Сохранение активного слота загружено: " + str(active_save_slot))
		else:
			print("Файл сохранения активного слота поврежден: " + path)
	else:
		print("Сохранение активного слота не найдено: " + path)


func change_scene(scene_name: String, params: Dictionary = {}):
	print("Смена сцены на: " + scene_name)
	current_scene_name = scene_name
	scene_changed.emit(scene_name)
	
	match scene_name:
		"main_menu":
			is_in_lab = true
			_transition_to_scene("res://scenes/ui/main_menu.tscn")
		"lab":
			is_in_lab = true
			_transition_to_scene("res://scenes/lab/lab.tscn")
		"run":
			is_in_lab = false
			_setup_run_params(params)
			_transition_to_scene("res://scenes/main/main.tscn")
		_:
			print("Неизвестная сцена: " + scene_name)


func _transition_to_scene(scene_path: String):
	is_loading = true
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		print("Ошибка загрузки сцены: " + scene_path + " код: " + str(error))
		Signals.error_occurred.emit(error, "Ошибка загрузки сцены", "GameManager")
	is_loading = false


func _setup_run_params(params: Dictionary):
	var bonuses = {}
	if current_save_data and current_save_data.lab_data:
		bonuses = current_save_data.lab_data.get_bonuses()

	# Кампания: уровень выбран в лаборатории (или текущий рубеж), параметры - из CampaignData
	var campaign_level := get_selected_or_frontier_level()
	var campaign_mode := get_campaign_mode()
	params["campaign_level"] = campaign_level
	params["campaign_mode"] = campaign_mode
	params["campaign_params"] = CampaignData.get_level_params(campaign_level, campaign_mode)
	# Переигрывание пройденного уровня: награда урезана, рубеж не двигается
	params["campaign_replay"] = campaign_level < get_campaign_level()

	# Стартовая биомасса в бою: остаток лаборатории + 300 базы.
	# Остаток СПИСЫВАЕТСЯ из лаборатории (перенос припасов на фронт)
	params["start_biomass"] = 300.0
	if current_save_data and current_save_data.lab_data:
		params["start_biomass"] += current_save_data.lab_data.biomass
		current_save_data.lab_data.biomass = 0.0
		
		if params.has("bonuses"):
			for key in bonuses:
				if params["bonuses"].has(key):
					params["bonuses"][key] *= bonuses[key]
				else:
					params["bonuses"][key] = bonuses[key]
		else:
			params["bonuses"] = bonuses
		
		params["bonuses"]["monolith_energy_bonus"] = current_save_data.lab_data.get_monolith_energy_bonus()
		params["bonuses"]["monolith_regen_mult"] = current_save_data.lab_data.get_monolith_regen_mult()
		params["bonuses"]["rare_chance_bonus"] = current_save_data.lab_data.get_rare_chance_bonus()
	
	get_tree().root.set_meta("run_params", params)
	print("Параметры забега установлены: " + str(params))


func save_game(slot: int) -> bool:
	if not current_save_data:
		current_save_data = SaveData.new()
		print("Создан новый SaveData")
	
	current_save_data.save_time = Time.get_datetime_string_from_system()
	
	var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
	var error = ResourceSaver.save(current_save_data, path)
	
	if error == OK:
		game_saved.emit(slot)
		Signals.game_saved.emit(slot, current_save_data.save_time)
		print("Игра сохранена в слот " + str(slot))
		
		if slot != 0:
			var autopath = SAVE_DIR + SAVE_FILE_PREFIX + "0" + SAVE_FILE_EXT
			ResourceSaver.save(current_save_data, autopath)
			print("Автосохранение обновлено")
		
		return true
	else:
		print("Ошибка сохранения в слот " + str(slot) + " код: " + str(error))
		Signals.error_occurred.emit(error, "Ошибка сохранения", "GameManager")
		return false


func load_game(slot: int) -> bool:
	var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
	
	if not FileAccess.file_exists(path):
		print("Сохранение не найдено: " + path)
		return false
	
	var save = load(path)
	if save and save is SaveData:
		current_save_data = save
		_migrate_campaign_progress(save)
		# Загруженный слот становится активным: весь дальнейший прогресс пишется сюда
		active_save_slot = clampi(slot, AUTOSAVE_SLOT, MANUAL_SLOTS)
		_save_settings()
		game_loaded.emit(save)
		Signals.game_loaded.emit(slot, save)
		print("Игра загружена из слота " + str(slot) + ", слот активирован")
		return true
	
	print("Файл сохранения поврежден: " + path)
	return false


func delete_save(slot: int) -> bool:
	var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
	
	if FileAccess.file_exists(path):
		var error = DirAccess.remove_absolute(path)
		if error == OK:
			Signals.save_deleted.emit(slot)
			print("Сохранение удалено из слота " + str(slot))
			return true
		else:
			print("Ошибка удаления сохранения: " + str(error))
			return false
	
	return false


func get_save_info(slot: int) -> Dictionary:
	var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
	
	if not FileAccess.file_exists(path):
		return {
			"exists": false,
			"slot": slot
		}
	
	var save = load(path)
	if save and save is SaveData:
		return {
			"exists": true,
			"slot": slot,
			"save_time": save.save_time,
			"run_number": save.lab_data.run_number if save.lab_data else 1,
			"biomass": save.lab_data.biomass if save.lab_data else 0.0,
			"wins": save.statistics.wins if save.statistics else 0,
			"losses": save.statistics.losses if save.statistics else 0,
			"total_runs": save.statistics.total_runs if save.statistics else 0,
			"anomaly_upgrades": save.lab_data.get_total_anomaly_levels() if save.lab_data else 0,
			"mutant_upgrades": save.lab_data.get_total_mutant_levels() if save.lab_data else 0,
			"monolith_upgrades": save.lab_data.get_total_monolith_levels() if save.lab_data else 0
		}
	
	return {"exists": false, "slot": slot}


func get_all_saves_info() -> Array[Dictionary]:
	# Ручные слоты 1..3; автосейв (0) в список загрузки не входит -
	# он подхватывается сам при старте, если активен
	var info: Array[Dictionary] = []
	for i in range(1, MANUAL_SLOTS + 1):
		info.append(get_save_info(i))
	return info


func start_new_game():
	print("Начало новой игры")
	current_save_data = SaveData.new()
	current_save_data.lab_data = LabData.new()
	current_save_data.statistics = GameStatistics.new()
	selected_campaign_level = 0

	if save_to_active_slot():
		change_scene("lab")
	else:
		print("Не удалось создать новую игру")


func get_lab_data():
	if not current_save_data:
		current_save_data = SaveData.new()
		current_save_data.lab_data = LabData.new()
		print("Создан новый LabData")
	
	if not current_save_data.lab_data:
		current_save_data.lab_data = LabData.new()
		print("LabData создан в существующем SaveData")
	
	return current_save_data.lab_data


func get_statistics():
	if not current_save_data:
		current_save_data = SaveData.new()
		current_save_data.statistics = GameStatistics.new()
		print("Создан новый GameStatistics")
	
	if not current_save_data.statistics:
		current_save_data.statistics = GameStatistics.new()
		print("GameStatistics создан в существующем SaveData")
	
	return current_save_data.statistics


# ==================== КАМПАНИЯ ====================

## Сейвы до введения кампании: рубеж восстановления - от числа забегов
func _migrate_campaign_progress(save: SaveData):
	if save.campaign_level <= 1 and save.lab_data and save.lab_data.run_number > 1:
		save.campaign_level = clampi(save.lab_data.run_number, 1, CampaignData.TOTAL_LEVELS)
		print("Кампания восстановлена по числу забегов: уровень " + str(save.campaign_level))


func get_campaign_level() -> int:
	if current_save_data:
		return clampi(current_save_data.campaign_level, 1, CampaignData.TOTAL_LEVELS)
	return 1


func get_campaign_mode() -> String:
	if current_save_data and CampaignData.MODE_MULTIPLIERS.has(current_save_data.campaign_mode):
		return current_save_data.campaign_mode
	return CampaignData.MODE_NORMAL


func set_campaign_mode(mode: String):
	if current_save_data and CampaignData.MODE_MULTIPLIERS.has(mode):
		current_save_data.campaign_mode = mode
		save_to_active_slot()


## Уровень для следующего забега: выбранный в лаборатории или текущий рубеж
func get_selected_or_frontier_level() -> int:
	var frontier := get_campaign_level()
	if selected_campaign_level >= 1 and selected_campaign_level <= frontier:
		return selected_campaign_level
	return frontier


func is_campaign_completed() -> bool:
	return current_save_data != null and current_save_data.campaign_completed


## Победа в забеге: сдвигаем рубеж кампании, если пройден frontier-уровень
func _apply_campaign_result(result: Dictionary):
	var success: bool = result.get("success", false)
	var level: int = result.get("campaign_level", 0)
	if not success or level <= 0:
		return

	if current_save_data.campaign_completed:
		return

	if level >= CampaignData.TOTAL_LEVELS:
		current_save_data.campaign_completed = true
		print("КАМПАНИЯ ПРОЙДЕНА! Все 100 колец Зоны за спиной.")
		return

	if level >= current_save_data.campaign_level:
		current_save_data.campaign_level = mini(level + 1, CampaignData.TOTAL_LEVELS)
		print("Кампания: открыт уровень " + str(current_save_data.campaign_level))


func process_run_result(result: Dictionary):
	print("Обработка результатов забега: " + str(result))

	var lab = get_lab_data()
	var stats = get_statistics()

	var reward = result.get("reward", 0.0)
	lab.biomass += reward
	print("Добавлено биомассы: " + str(reward))

	_apply_campaign_result(result)
	
	stats.total_runs += 1
	var success = result.get("success", false)
	if success:
		stats.wins += 1
		print("Победа")
	else:
		stats.losses += 1
		print("Поражение")
	
	if result.has("artifacts_collected"):
		var artifacts = result["artifacts_collected"]
		for artifact in artifacts:
			lab.add_artifact(artifact.get("type", "common"), artifact.get("value", 10))
		print("Добавлено артефактов: " + str(artifacts.size()))
	
	if result.has("statistics"):
		var run_stats = result["statistics"]
		stats.stalkers_killed += run_stats.get("stalkers_killed", 0)
		stats.anomalies_created += run_stats.get("anomalies_created", 0)
		stats.mutants_created += run_stats.get("mutants_created", 0)
		stats.artifacts_stolen += run_stats.get("artifacts_stolen", 0)
		stats.biomass_earned += run_stats.get("biomass_earned", 0)
		stats.biomass_spent += run_stats.get("biomass_spent", 0)
	
	lab.run_number += 1
	print("Номер забега: " + str(lab.run_number))
	
	save_to_active_slot()
	
	Signals.run_ended.emit(lab.run_number - 1, success, reward)


func purchase_upgrade(upgrade_type: String, cost: float) -> bool:
	var lab = get_lab_data()

	# Расширенные тиры открываются прогрессом кампании
	if not lab.is_next_level_unlocked(upgrade_type, get_campaign_level()):
		print("Улучшение %s откроется на уровне кампании %d" % [
			upgrade_type, lab.get_next_unlock_campaign_level(upgrade_type)])
		return false

	if lab.biomass < cost:
		print("Недостаточно биомассы для " + upgrade_type + " (нужно: " + str(cost) + ", есть: " + str(lab.biomass) + ")")
		return false
	
	lab.biomass -= cost
	lab.purchase_upgrade(upgrade_type)
	
	print("Куплено улучшение: " + upgrade_type + " за " + str(cost))
	
	save_to_active_slot()
	
	return true


func exchange_artifact(artifact_type: String, value: int) -> bool:
	var lab = get_lab_data()
	
	if lab.remove_artifact(artifact_type):
		lab.biomass += value
		print("Обменян артефакт " + artifact_type + " на " + str(value) + " биомассы")
		save_to_active_slot()
		return true
	
	print("Не удалось обменять артефакт " + artifact_type)
	return false


func exchange_all_artifacts(rarity: String) -> int:
	var lab = get_lab_data()
	var total = lab.exchange_all_of_rarity(rarity)
	
	if total > 0:
		lab.biomass += total
		print("Обменяны все артефакты редкости " + rarity + " на " + str(total) + " биомассы")
		save_to_active_slot()
	else:
		print("Нет артефактов редкости " + rarity + " для обмена")
	
	return total


func get_current_save_data():
	return current_save_data


func is_game_running() -> bool:
	return not is_in_lab and not is_loading


func get_current_scene() -> String:
	return current_scene_name


func reset_game():
	print("Сброс игры")
	current_save_data = null
	is_in_lab = true
	is_loading = false
	current_scene_name = ""
