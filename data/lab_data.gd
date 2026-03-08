# data/lab_data.gd
extends Resource
class_name LabData

## Данные лабораторного комплекса

# Основные данные
@export var run_number: int = 1
@export var biomass: float = 0.0

# Улучшения аномалий
@export var anomaly_damage_level: int = 0
@export var anomaly_radius_level: int = 0
@export var anomaly_duration_level: int = 0

# Улучшения мутантов
@export var mutant_health_level: int = 0
@export var mutant_damage_level: int = 0
@export var mutant_speed_level: int = 0
@export var mutant_cost_level: int = 0

# Улучшения монолита
@export var monolith_energy_level: int = 0
@export var monolith_regen_level: int = 0
@export var rare_chance_level: int = 0

# Хранилище артефактов
@export var artifacts_common: Array[Dictionary] = []
@export var artifacts_rare: Array[Dictionary] = []
@export var artifacts_legendary: Array[Dictionary] = []

# Максимальные уровни
const MAX_LEVELS = {
    "anomaly_damage": 5,
    "anomaly_radius": 5,
    "anomaly_duration": 3,
    "mutant_health": 5,
    "mutant_damage": 5,
    "mutant_speed": 3,
    "mutant_cost": 3,
    "monolith_energy": 5,
    "monolith_regen": 3,
    "rare_chance": 3
}

# Стоимости улучшений
const COSTS = {
    "anomaly_damage": [100, 200, 400, 800, 1600],
    "anomaly_radius": [150, 300, 600, 1200, 2400],
    "anomaly_duration": [200, 400, 800],
    "mutant_health": [100, 200, 400, 800, 1600],
    "mutant_damage": [120, 240, 480, 960, 1920],
    "mutant_speed": [150, 300, 600],
    "mutant_cost": [200, 400, 800],
    "monolith_energy": [150, 300, 600, 1200, 2400],
    "monolith_regen": [200, 400, 800],
    "rare_chance": [300, 600, 1200]
}

# Бонусы за уровень
const BONUS_PER_LEVEL = {
    "anomaly_damage": 0.10,
    "anomaly_radius": 0.10,
    "anomaly_duration": 0.20,
    "mutant_health": 0.10,
    "mutant_damage": 0.10,
    "mutant_speed": 0.10,
    "mutant_cost": -0.10,
    "monolith_energy": 100.0,
    "monolith_regen": 0.20,
    "rare_chance": 0.10
}


# ==================== УЛУЧШЕНИЯ ====================

func get_upgrade_level(upgrade_type: String) -> int:
    match upgrade_type:
        "anomaly_damage": return anomaly_damage_level
        "anomaly_radius": return anomaly_radius_level
        "anomaly_duration": return anomaly_duration_level
        "mutant_health": return mutant_health_level
        "mutant_damage": return mutant_damage_level
        "mutant_speed": return mutant_speed_level
        "mutant_cost": return mutant_cost_level
        "monolith_energy": return monolith_energy_level
        "monolith_regen": return monolith_regen_level
        "rare_chance": return rare_chance_level
        _: return 0


func get_max_level(upgrade_type: String) -> int:
    return MAX_LEVELS.get(upgrade_type, 5)


func can_upgrade(upgrade_type: String) -> bool:
    var current = get_upgrade_level(upgrade_type)
    var max_lvl = get_max_level(upgrade_type)
    return current < max_lvl


func get_upgrade_cost(upgrade_type: String) -> float:
    var current = get_upgrade_level(upgrade_type)
    if not COSTS.has(upgrade_type):
        return 100.0
    
    var costs = COSTS[upgrade_type]
    if current >= costs.size():
        return 99999.0
    
    return costs[current]


func purchase_upgrade(upgrade_type: String) -> bool:
    if not can_upgrade(upgrade_type):
        return false
    
    match upgrade_type:
        "anomaly_damage": anomaly_damage_level += 1
        "anomaly_radius": anomaly_radius_level += 1
        "anomaly_duration": anomaly_duration_level += 1
        "mutant_health": mutant_health_level += 1
        "mutant_damage": mutant_damage_level += 1
        "mutant_speed": mutant_speed_level += 1
        "mutant_cost": mutant_cost_level += 1
        "monolith_energy": monolith_energy_level += 1
        "monolith_regen": monolith_regen_level += 1
        "rare_chance": rare_chance_level += 1
    
    return true


func get_bonus(upgrade_type: String) -> float:
    var level = get_upgrade_level(upgrade_type)
    var bonus = BONUS_PER_LEVEL.get(upgrade_type, 0.0)
    
    if upgrade_type in ["monolith_energy"]:
        return level * bonus
    
    return 1.0 + (level * bonus)


# ==================== БОНУСЫ ====================

func get_bonuses() -> Dictionary:
    return {
        "anomaly_damage_mult": get_bonus("anomaly_damage"),
        "anomaly_radius_mult": get_bonus("anomaly_radius"),
        "anomaly_duration_mult": get_bonus("anomaly_duration"),
        "mutant_health_mult": get_bonus("mutant_health"),
        "mutant_damage_mult": get_bonus("mutant_damage"),
        "mutant_speed_mult": get_bonus("mutant_speed"),
        "mutant_cost_mult": get_bonus("mutant_cost")
    }


func get_monolith_energy_bonus() -> float:
    return get_bonus("monolith_energy")


func get_monolith_regen_mult() -> float:
    return get_bonus("monolith_regen")


func get_rare_chance_bonus() -> float:
    return get_bonus("rare_chance")


func get_total_anomaly_levels() -> int:
    return anomaly_damage_level + anomaly_radius_level + anomaly_duration_level


func get_total_mutant_levels() -> int:
    return mutant_health_level + mutant_damage_level + mutant_speed_level + mutant_cost_level


func get_total_monolith_levels() -> int:
    return monolith_energy_level + monolith_regen_level + rare_chance_level


# ==================== АРТЕФАКТЫ ====================

func add_artifact(rarity: String, value: int):
    var artifact = {"value": value}
    
    match rarity:
        "common":
            artifacts_common.append(artifact)
        "rare":
            artifacts_rare.append(artifact)
        "legendary":
            artifacts_legendary.append(artifact)


func remove_artifact(rarity: String) -> bool:
    match rarity:
        "common":
            if artifacts_common.size() > 0:
                artifacts_common.pop_back()
                return true
        "rare":
            if artifacts_rare.size() > 0:
                artifacts_rare.pop_back()
                return true
        "legendary":
            if artifacts_legendary.size() > 0:
                artifacts_legendary.pop_back()
                return true
    return false


func get_artifact_count(rarity: String) -> int:
    match rarity:
        "common": return artifacts_common.size()
        "rare": return artifacts_rare.size()
        "legendary": return artifacts_legendary.size()
    return 0


func get_total_artifact_value(rarity: String) -> int:
    var artifacts: Array
    match rarity:
        "common": artifacts = artifacts_common
        "rare": artifacts = artifacts_rare
        "legendary": artifacts = artifacts_legendary
        _: return 0
    
    var total = 0
    for a in artifacts:
        total += a.get("value", 0)
    return total


func exchange_all_of_rarity(rarity: String) -> int:
    var total = get_total_artifact_value(rarity)
    
    match rarity:
        "common": artifacts_common.clear()
        "rare": artifacts_rare.clear()
        "legendary": artifacts_legendary.clear()
    
    return total


func get_all_artifacts() -> Dictionary:
    return {
        "common": {
            "count": get_artifact_count("common"),
            "value": get_total_artifact_value("common"),
            "items": artifacts_common
        },
        "rare": {
            "count": get_artifact_count("rare"),
            "value": get_total_artifact_value("rare"),
            "items": artifacts_rare
        },
        "legendary": {
            "count": get_artifact_count("legendary"),
            "value": get_total_artifact_value("legendary"),
            "items": artifacts_legendary
        }
    }


# ==================== СБРОС ====================

func reset():
    run_number = 1
    biomass = 0.0
    
    anomaly_damage_level = 0
    anomaly_radius_level = 0
    anomaly_duration_level = 0
    mutant_health_level = 0
    mutant_damage_level = 0
    mutant_speed_level = 0
    mutant_cost_level = 0
    monolith_energy_level = 0
    monolith_regen_level = 0
    rare_chance_level = 0
    
    artifacts_common.clear()
    artifacts_rare.clear()
    artifacts_legendary.clear()