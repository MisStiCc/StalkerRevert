extends Node
# GameManager - автoload (доступен через GameManager в любом месте)

## Глобальный менеджер игры
## Управляет переходами, сохранениями и глобальным состоянием

signal game_loaded(save_data: SaveData)
signal game_saved(slot: int)
signal scene_changed(scene_name: String)

# Текущее состояние
var current_save_data: SaveData = null
var is_in_lab: bool = true
var is_loading: bool = false

# Пути
const SAVE_DIR = "user://saves/"
const SAVE_FILE_PREFIX = "save_"
const SAVE_FILE_EXT = ".tres"

# Текущая сцена
var current_scene_name: String = ""


func _ready():
	add_to_group("game_manager")
	
	# Создаём директорию для сохранений
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	
	# Загружаем автосохранение если существует
	_load_autosave_if_exists()
	
	print("🎮 GameManager: инициализирован")


func _load_autosave_if_exists():
	var autosave_path = SAVE_DIR + SAVE_FILE_PREFIX + "0" + SAVE_FILE_EXT
	if FileAccess.file_exists(autosave_path):
		var save = load(autosave_path)
		if save and save is SaveData:
			current_save_data = save
			print("📂 Автосохранение загружено")


# ==================== УПРАВЛЕНИЕ СЦЕНАМИ ====================

func change_scene(scene_name: String, params: Dictionary = {}):
	current_scene_name = scene_name
	scene_changed.emit(scene_name)
	
	match scene_name:
		"main_menu":
			is_in_lab = true
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		"lab":
			is_in_lab = true
			get_tree().change_scene_to_file("res://scenes/lab/lab.tscn")
		"run":
			is_in_lab = false
			# Передаём параметры в забег
			_setup_run(params)
			get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _setup_run(params: Dictionary):
	# Настраиваем забег с бонусами из LabData
	if current_save_data and current_save_data.lab_data:
		var bonuses = current_save_data.lab_data.get_bonuses()
		
		# Применяем к параметрам
		if params.has("bonuses"):
			for key in bonuses:
				if params["bonuses"].has(key):
					params["bonuses"][key] *= bonuses[key]
				else:
					params["bonuses"][key] = bonuses[key]
		else:
			params["bonuses"] = bonuses
		
		# Добавляем бонусы монолита
		params["bonuses"]["monolith_energy_bonus"] = current_save_data.lab_data.get_monolith_energy_bonus()
		params["bonuses"]["monolith_regen_mult"] = current_save_data.lab_data.get_monolith_regen_mult()
		params["bonuses"]["rare_chance_bonus"] = current_save_data.lab_data.get_rare_chance_bonus()
	
	# Передаём в ZoneController через параметры
	get_tree().root.set_meta("run_params", params)


# ==================== СОХРАНЕНИЯ ====================

func save_game(slot: int):
	if not current_save_data:
		current_save_data = SaveData.new()
	
	current_save_data.save_time = Time.get_datetime_string_from_system()
	
	var save_path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
	var error = ResourceSaver.save(current_save_data, save_path)
	
	if error == OK:
		game_saved.emit(slot)
		print("💾 Игра сохранена в слот ", slot)
		
		# Автосохранение в слот 0
		if slot != 0:
			var autosave_path = SAVE_DIR + SAVE_FILE_PREFIX + "0" + SAVE_FILE_EXT
			ResourceSaver.save(current_save_data, autosave_path)
	else:
		push_error("Не удалось сохранить игру в слот ", slot)


func load_game(slot: int):
	var save_path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
	
	if not FileAccess.file_exists(save_path):
		push_warning("Сохранение не найдено: ", save_path)
		return false
	
	var save = load(save_path)
	if save and save is SaveData:
		current_save_data = save
		game_loaded.emit(save)
		print("📂 Игра загружена из слота ", slot)
		return true
	
	return false


func delete_save(slot: int):
	var save_path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
	
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		print("🗑️ Сохранение удалено из слота ", slot)


func get_save_info(slot: int) -> Dictionary:
	var save_path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
	
	if not FileAccess.file_exists(save_path):
		return {"exists": false}
	
	var save = load(save_path)
	if save and save is SaveData:
		return {
			"exists": true,
			"save_time": save.save_time,
			"run_number": save.lab_data.run_number if save.lab_data else 1,
			"biomass": save.lab_data.biomass if save.lab_data else 0,
			"wins": save.statistics.wins,
			"losses": save.statistics.losses
		}
	
	return {"exists": false}


func get_all_saves_info() -> Array[Dictionary]:
	var info = []
	for i in range(3):
		info.append(get_save_info(i))
	return info


# ==================== НОВАЯ ИГРА ====================

func start_new_game():
	current_save_data = SaveData.new()
	current_save_data.lab_data = LabData.new()
	current_save_data.statistics = GameStatistics.new()
	
	# Сохраняем автосохранение
	save_game(0)
	
	# Переходим в ЛК
	change_scene("lab")


# ==================== ЛАБ ДАННЫЕ ====================

func get_lab_data() -> LabData:
	if not current_save_data:
		current_save_data = SaveData.new()
		current_save_data.lab_data = LabData.new()
	
	if not current_save_data.lab_data:
		current_save_data.lab_data = LabData.new()
	
	return current_save_data.lab_data


func get_statistics() -> GameStatistics:
	if not current_save_data:
		current_save_data = SaveData.new()
		current_save_data.statistics = GameStatistics.new()
	
	if not current_save_data.statistics:
		current_save_data.statistics = GameStatistics.new()
	
	return current_save_data.statistics


# ==================== РЕЗУЛЬТАТЫ ЗАБЕГА ====================

func process_run_result(result: Dictionary):
	var lab = get_lab_data()
	var stats = get_statistics()
	
	# Добавляем биомассу
	lab.biomass += result.get("reward", 0)
	
	# Обновляем статистику
	stats.total_runs += 1
	
	if result.get("success", false):
		stats.wins += 1
	else:
		stats.losses += 1
	
	# Добавляем артефакты
	if result.has("artifacts_collected"):
		for artifact in result["artifacts_collected"]:
			lab.add_artifact(artifact["type"], artifact["value"])
	
	# Обновляем статистику забега
	if result.has("statistics"):
		var run_stats = result["statistics"]
		stats.stalkers_killed += run_stats.get("stalkers_killed", 0)
		stats.anomalies_created += run_stats.get("anomalies_created", 0)
		stats.mutants_created += run_stats.get("mutants_created", 0)
		stats.artifacts_stolen += run_stats.get("artifacts_stolen", 0)
		stats.biomass_earned += run_stats.get("biomass_earned", 0)
		stats.biomass_spent += run_stats.get("biomass_spent", 0)
	
	# Увеличиваем номер забега
	lab.run_number += 1
	
	# Автосохранение
	save_game(0)


# ==================== УЛУЧШЕНИЯ ====================

func purchase_upgrade(upgrade_type: String, cost: float) -> bool:
	var lab = get_lab_data()
	
	if lab.biomass < cost:
		return false
	
	lab.biomass -= cost
	lab.purchase_upgrade(upgrade_type)
	
	# Автосохранение после покупки
	save_game(0)
	
	return true


func exchange_artifact(artifact_type: String, value: int) -> bool:
	var lab = get_lab_data()
	
	if lab.remove_artifact(artifact_type):
		lab.biomass += value
		save_game(0)
		return true
	
	return false


func exchange_all_artifacts(rarity: String) -> int:
	var lab = get_lab_data()
	var total = lab.exchange_all_of_rarity(rarity)
	
	if total > 0:
		lab.biomass += total
		save_game(0)
	
	return total
