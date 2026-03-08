# core/game_manager.gd
extends Node
class_name GameManager

## Глобальный менеджер игры (автозагрузка)
## Отвечает только за:
## - Сохранения/загрузки
## - Переходы между сценами
## - Глобальное состояние

signal game_loaded(save_data: Resource)
signal game_saved(slot: int)
signal scene_changed(scene_name: String)

# Текущее состояние
var current_save_data: SaveData = null
var is_in_lab: bool = true
var is_loading: bool = false
var current_scene_name: String = ""

# Константы
const SAVE_DIR := "user://saves/"
const SAVE_FILE_PREFIX := "save_"
const SAVE_FILE_EXT := ".tres"


func _ready():
    _create_save_directory()
    _load_autosave_if_exists()
    Signals.game_started.emit()
    Logger.info("GameManager инициализирован", "GameManager")


func _create_save_directory():
    var dir = DirAccess.open("user://")
    if not dir.dir_exists("saves"):
        dir.make_dir("saves")
    Logger.debug("Директория сохранений создана", "GameManager")


func _load_autosave_if_exists():
    var path = SAVE_DIR + SAVE_FILE_PREFIX + "0" + SAVE_FILE_EXT
    if FileAccess.file_exists(path):
        var save = load(path)
        if save and save is SaveData:
            current_save_data = save
            Logger.info("Автосохранение загружено", "GameManager")
    else:
        Logger.debug("Автосохранение не найдено", "GameManager")


# ==================== УПРАВЛЕНИЕ СЦЕНАМИ ====================

func change_scene(scene_name: String, params: Dictionary = {}):
    Logger.info("Смена сцены на: " + scene_name, "GameManager")
    current_scene_name = scene_name
    scene_changed.emit(scene_name)
    
    match scene_name:
        "main_menu":
            is_in_lab = true
            _transition_to_scene("res://ui/main_menu/main_menu.tscn")
        "lab":
            is_in_lab = true
            _transition_to_scene("res://ui/lab/lab.tscn")
        "run":
            is_in_lab = false
            _setup_run_params(params)
            _transition_to_scene("res://scenes/main.tscn")
        _:
            Logger.error("Неизвестная сцена: " + scene_name, "GameManager")


func _transition_to_scene(scene_path: String):
    is_loading = true
    var error = get_tree().change_scene_to_file(scene_path)
    if error != OK:
        Logger.error("Ошибка загрузки сцены: " + scene_path + " код: " + str(error), "GameManager")
        Signals.error_occurred.emit(error, "Ошибка загрузки сцены", "GameManager")
    is_loading = false


func _setup_run_params(params: Dictionary):
    # Получаем бонусы из лаборатории
    var bonuses = {}
    if current_save_data and current_save_data.lab_data:
        bonuses = current_save_data.lab_data.get_bonuses()
        
        # Добавляем в параметры
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
    
    # Сохраняем параметры для ZoneController
    get_tree().root.set_meta("run_params", params)
    Logger.debug("Параметры забега установлены: " + str(params), "GameManager")


# ==================== СОХРАНЕНИЯ ====================

func save_game(slot: int) -> bool:
    if not current_save_data:
        current_save_data = SaveData.new()
        Logger.debug("Создан новый SaveData", "GameManager")
    
    current_save_data.save_time = Time.get_datetime_string_from_system()
    
    var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
    var error = ResourceSaver.save(current_save_data, path)
    
    if error == OK:
        game_saved.emit(slot)
        Signals.game_saved.emit(slot, current_save_data.save_time)
        Logger.info("Игра сохранена в слот " + str(slot), "GameManager")
        
        # Автосохранение в слот 0
        if slot != 0:
            var autopath = SAVE_DIR + SAVE_FILE_PREFIX + "0" + SAVE_FILE_EXT
            ResourceSaver.save(current_save_data, autopath)
            Logger.debug("Автосохранение обновлено", "GameManager")
        
        return true
    else:
        Logger.error("Ошибка сохранения в слот " + str(slot) + " код: " + str(error), "GameManager")
        Signals.error_occurred.emit(error, "Ошибка сохранения", "GameManager")
        return false


func load_game(slot: int) -> bool:
    var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
    
    if not FileAccess.file_exists(path):
        Logger.warning("Сохранение не найдено: " + path, "GameManager")
        return false
    
    var save = load(path)
    if save and save is SaveData:
        current_save_data = save
        game_loaded.emit(save)
        Signals.game_loaded.emit(slot, save)
        Logger.info("Игра загружена из слота " + str(slot), "GameManager")
        return true
    
    Logger.error("Файл сохранения поврежден: " + path, "GameManager")
    return false


func delete_save(slot: int) -> bool:
    var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
    
    if FileAccess.file_exists(path):
        var error = DirAccess.remove_absolute(path)
        if error == OK:
            Signals.save_deleted.emit(slot)
            Logger.info("Сохранение удалено из слота " + str(slot), "GameManager")
            return true
        else:
            Logger.error("Ошибка удаления сохранения: " + str(error), "GameManager")
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
            "biomass": save.lab_data.biomass if save.lab_data else 0,
            "wins": save.statistics.wins if save.statistics else 0,
            "losses": save.statistics.losses if save.statistics else 0,
            "total_runs": save.statistics.total_runs if save.statistics else 0,
            "anomaly_upgrades": save.lab_data.get_total_anomaly_levels() if save.lab_data else 0,
            "mutant_upgrades": save.lab_data.get_total_mutant_levels() if save.lab_data else 0,
            "monolith_upgrades": save.lab_data.get_total_monolith_levels() if save.lab_data else 0
        }
    
    return {"exists": false, "slot": slot}


func get_all_saves_info() -> Array[Dictionary]:
    var info = []
    for i in range(3):
        info.append(get_save_info(i))
    return info


# ==================== НОВАЯ ИГРА ====================

func start_new_game():
    Logger.info("Начало новой игры", "GameManager")
    current_save_data = SaveData.new()
    current_save_data.lab_data = LabData.new()
    current_save_data.statistics = GameStatistics.new()
    
    if save_game(0):
        change_scene("lab")
    else:
        Logger.error("Не удалось создать новую игру", "GameManager")


# ==================== ДАННЫЕ ЛАБОРАТОРИИ ====================

func get_lab_data() -> LabData:
    if not current_save_data:
        current_save_data = SaveData.new()
        current_save_data.lab_data = LabData.new()
        Logger.debug("Создан новый LabData", "GameManager")
    
    if not current_save_data.lab_data:
        current_save_data.lab_data = LabData.new()
        Logger.debug("LabData создан в существующем SaveData", "GameManager")
    
    return current_save_data.lab_data


func get_statistics() -> GameStatistics:
    if not current_save_data:
        current_save_data = SaveData.new()
        current_save_data.statistics = GameStatistics.new()
        Logger.debug("Создан новый GameStatistics", "GameManager")
    
    if not current_save_data.statistics:
        current_save_data.statistics = GameStatistics.new()
        Logger.debug("GameStatistics создан в существующем SaveData", "GameManager")
    
    return current_save_data.statistics


# ==================== РЕЗУЛЬТАТЫ ЗАБЕГА ====================

func process_run_result(result: Dictionary):
    Logger.info("Обработка результатов забега: " + str(result), "GameManager")
    
    var lab = get_lab_data()
    var stats = get_statistics()
    
    # Добавляем биомассу
    var reward = result.get("reward", 0.0)
    lab.biomass += reward
    Logger.debug("Добавлено биомассы: " + str(reward), "GameManager")
    
    # Обновляем статистику
    stats.total_runs += 1
    var success = result.get("success", false)
    if success:
        stats.wins += 1
        Logger.debug("Победа", "GameManager")
    else:
        stats.losses += 1
        Logger.debug("Поражение", "GameManager")
    
    # Добавляем артефакты
    if result.has("artifacts_collected"):
        var artifacts = result["artifacts_collected"]
        for artifact in artifacts:
            lab.add_artifact(artifact.get("type", "common"), artifact.get("value", 10))
        Logger.debug("Добавлено артефактов: " + str(artifacts.size()), "GameManager")
    
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
    Logger.debug("Номер забега: " + str(lab.run_number), "GameManager")
    
    # Автосохранение
    save_game(0)
    
    Signals.run_ended.emit(lab.run_number - 1, success, reward)


# ==================== УЛУЧШЕНИЯ ====================

func purchase_upgrade(upgrade_type: String, cost: float) -> bool:
    var lab = get_lab_data()
    
    if lab.biomass < cost:
        Logger.warning("Недостаточно биомассы для " + upgrade_type + " (нужно: " + str(cost) + ", есть: " + str(lab.biomass) + ")", "GameManager")
        return false
    
    lab.biomass -= cost
    lab.purchase_upgrade(upgrade_type)
    
    Logger.info("Куплено улучшение: " + upgrade_type + " за " + str(cost), "GameManager")
    
    # Автосохранение после покупки
    save_game(0)
    
    return true


func exchange_artifact(artifact_type: String, value: int) -> bool:
    var lab = get_lab_data()
    
    if lab.remove_artifact(artifact_type):
        lab.biomass += value
        Logger.info("Обменян артефакт " + artifact_type + " на " + str(value) + " биомассы", "GameManager")
        save_game(0)
        return true
    
    Logger.warning("Не удалось обменять артефакт " + artifact_type, "GameManager")
    return false


func exchange_all_artifacts(rarity: String) -> int:
    var lab = get_lab_data()
    var total = lab.exchange_all_of_rarity(rarity)
    
    if total > 0:
        lab.biomass += total
        Logger.info("Обменяны все артефакты редкости " + rarity + " на " + str(total) + " биомассы", "GameManager")
        save_game(0)
    else:
        Logger.debug("Нет артефактов редкости " + rarity + " для обмена", "GameManager")
    
    return total


# ==================== УТИЛИТЫ ====================

func get_current_save_data() -> SaveData:
    return current_save_data


func is_game_running() -> bool:
    return not is_in_lab and not is_loading


func get_current_scene() -> String:
    return current_scene_name


func reset_game():
    Logger.warning("Сброс игры", "GameManager")
    current_save_data = null
    is_in_lab = true
    is_loading = false
    current_scene_name = ""