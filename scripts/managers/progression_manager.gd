extends Node
class_name ProgressionManager

## Управление прогрессией: забеги, апгрейды, сложность

signal run_started(run_number: int, difficulty: float)
signal run_ended(run_number: int, reward: float, success: bool)
signal upgrade_unlocked(upgrade_type: String, level: int)
signal difficulty_changed(new_difficulty: float)

@export var base_difficulty: float = 1.0
@export var difficulty_increase_per_run: float = 0.2
@export var pulses_to_win_base: int = 5
@export var difficulty_increase_per_pulse: float = 0.15

# Параметры масштабирования
@export var health_scale_per_run: float = 0.15
@export var speed_scale_per_run: float = 0.05
@export var damage_scale_per_run: float = 0.15

var current_run: int = 1
var current_difficulty: float = 1.0
var pulses_to_win: int = 5

# Апгрейды
var upgrades: Dictionary = {
	"anomaly_damage": 0,
	"anomaly_radius": 0,
	"mutant_health": 0,
	"mutant_damage": 0,
	"mutant_cost": 0,
	"monolith_energy": 0,
	"monolith_regen": 0
}

# Стоимость апгрейдов
var upgrade_costs: Dictionary = {
	"anomaly_damage": 50.0,
	"anomaly_radius": 40.0,
	"mutant_health": 60.0,
	"mutant_damage": 55.0,
	"mutant_cost": 45.0,
	"monolith_energy": 70.0,
	"monolith_regen": 35.0
}

# Бонусы апгрейдов
var upgrade_bonuses: Dictionary = {
	"anomaly_damage": 0.2,      # +20% урона аномалий за уровень
	"anomaly_radius": 0.15,     # +15% радиуса за уровень
	"mutant_health": 0.25,      # +25% здоровья мутантов за уровень
	"mutant_damage": 0.2,       # +20% урона мутантов за уровень
	"mutant_cost": -0.1,        # -10% стоимости мутантов за уровень
	"monolith_energy": 100.0,   # +100 макс. энергии за уровень
	"monolith_regen": 0.5       # +0.5 регенерации за уровень
}

# Статистика
var total_runs: int = 0
var total_wins: int = 0
var total_biomass_earned: float = 0.0
var total_stalkers_killed: int = 0

var _current_biomass: float = 0.0


func _ready():
	add_to_group("progression_manager")


# ==================== ЗАБЕГИ ====================

func start_new_run() -> Dictionary:
	current_run = total_runs + 1
	current_difficulty = base_difficulty + (current_run - 1) * difficulty_increase_per_run
	pulses_to_win = pulses_to_win_base + int((current_run - 1) / 2)
	_current_biomass = 0.0
	
	print("🏃 Забег #", current_run, " | Сложность: ", current_difficulty, " | Цель: ", pulses_to_win, " выбросов")
	
	run_started.emit(current_run, current_difficulty)
	
	return {
		"run_number": current_run,
		"difficulty": current_difficulty,
		"pulses_to_win": pulses_to_win
	}


func end_run(success: bool, accumulated_biomass: float) -> float:
	total_runs += 1
	_current_biomass = accumulated_biomass
	
	var reward = 0.0
	if success:
		total_wins += 1
		reward = _calculate_reward(accumulated_biomass)
		total_biomass_earned += reward
	
	print("Забег #", current_run, " завершён. Успех: ", success, " | Награда: ", reward)
	run_ended.emit(current_run, reward, success)
	
	return reward


func _calculate_reward(accumulated: float) -> float:
	var base_reward = 100.0 * current_run
	var difficulty_mult = current_difficulty
	var accumulated_part = accumulated * 0.3
	return accumulated_part + (base_reward * difficulty_mult)


func increase_difficulty(amount: float = difficulty_increase_per_pulse):
	current_difficulty += amount
	difficulty_changed.emit(current_difficulty)


# ==================== АПГРЕЙДЫ ====================

func purchase_upgrade(upgrade_type: String, available_biomass: float) -> bool:
	if not upgrades.has(upgrade_type):
		push_error("ProgressionManager: неизвестный тип апгрейда - ", upgrade_type)
		return false
	
	var cost = get_upgrade_cost(upgrade_type)
	if available_biomass < cost:
		return false
	
	upgrades[upgrade_type] += 1
	upgrade_unlocked.emit(upgrade_type, upgrades[upgrade_type])
	
	print("✅ Апгрейд ", upgrade_type, " приобретён! Уровень: ", upgrades[upgrade_type])
	return true


func get_upgrade_cost(upgrade_type: String) -> float:
	if not upgrade_costs.has(upgrade_type):
		return 100.0
	
	var base_cost = upgrade_costs[upgrade_type]
	var level = upgrades.get(upgrade_type, 0)
	return base_cost * (1.0 + level * 0.5)


func get_upgrade_level(upgrade_type: String) -> int:
	return upgrades.get(upgrade_type, 0)


func get_upgrade_bonus(upgrade_type: String) -> float:
	var level = upgrades.get(upgrade_type, 0)
	var bonus_per_level = upgrade_bonuses.get(upgrade_type, 0.0)
	return level * bonus_per_level


func get_all_upgrades() -> Dictionary:
	return upgrades.duplicate()


# ==================== МНОЖИТЕЛИ ====================

func get_health_multiplier() -> float:
	return 1.0 + (current_run - 1) * health_scale_per_run


func get_speed_multiplier() -> float:
	return 1.0 + (current_run - 1) * speed_scale_per_run


func get_damage_multiplier() -> float:
	return 1.0 + (current_run - 1) * damage_scale_per_run


func get_anomaly_damage_bonus() -> float:
	return get_upgrade_bonus("anomaly_damage")


func get_anomaly_radius_bonus() -> float:
	return get_upgrade_bonus("anomaly_radius")


func get_mutant_health_bonus() -> float:
	return get_upgrade_bonus("mutant_health")


func get_mutant_damage_bonus() -> float:
	return get_upgrade_bonus("mutant_damage")


func get_mutant_cost_mult() -> float:
	return 1.0 + get_upgrade_bonus("mutant_cost")


func get_monolith_energy_bonus() -> float:
	return get_upgrade_bonus("monolith_energy")


func get_monolith_regen_bonus() -> float:
	return get_upgrade_bonus("monolith_regen")


# ==================== СТАТИСТИКА ====================

func record_stalker_killed():
	total_stalkers_killed += 1


func get_statistics() -> Dictionary:
	return {
		"total_runs": total_runs,
		"total_wins": total_wins,
		"win_rate": float(total_wins) / max(1, total_runs) * 100.0,
		"total_biomass_earned": total_biomass_earned,
		"total_stalkers_killed": total_stalkers_killed,
		"current_run": current_run,
		"current_difficulty": current_difficulty
	}


func reset_statistics():
	total_runs = 0
	total_wins = 0
	total_biomass_earned = 0.0
	total_stalkers_killed = 0.0
	_current_biomass = 0.0


# ==================== ГЕТТЕРЫ ====================

func get_current_run() -> int:
	return current_run


func get_current_difficulty() -> float:
	return current_difficulty


func get_pulses_to_win() -> int:
	return pulses_to_win


func is_first_run() -> bool:
	return current_run == 1
