# data/survival_data.gd
extends RefCounted
class_name SurvivalData

## Режим выживания: волны бесконечны, каждая следующая сильнее,
## награда растёт с числом пройденных волн. Забег заканчивается только
## гибелью Зоны (сталкер коснулся Монолита).
## Все параметры волны считаются здесь - единственное место правки баланса.

# Награда за пройденные волны: base x N + growth x N x (N+1).
# N=10: 1440, N=20: 3680, N=30: 6720, N=50: 15200 биомассы (плюс боевой доход)
const REWARD_PER_WAVE_BASE: float = 100.0
const REWARD_PER_WAVE_GROWTH: float = 4.0

# Потолки, чтобы ранние волны не были пустыми, а поздние - не рвали производительность
const MAX_COUNT_PER_WAVE: int = 28
const MAX_MASTER_PERCENT: int = 30
const MAX_VETERAN_PERCENT: int = 55
const MAX_SPEED_MULT: float = 1.15
const MIN_WAVE_BREAK: float = 30.0


## Параметры волны N: тот же формат, что у уровня кампании (ZoneController
## применяет их через те же поля SpawnManager)
static func get_wave_params(wave: int, mode: String = CampaignData.MODE_NORMAL) -> Dictionary:
	var w: int = maxi(1, wave)
	var mode_mult: float = float(CampaignData.MODE_MULTIPLIERS.get(mode, 1.0))

	# Количество: 8 на первой волне, +0.7 за волну, потолок 28
	var count_min: int = mini(MAX_COUNT_PER_WAVE, 8 + int(round(0.7 * (w - 1))))

	# Состав: ветераны с 3-й волны (+3%/волну до 55), мастера с 8-й (+1.2%/волну до 30)
	var veteran: int = clampi(3 * (w - 2), 0, MAX_VETERAN_PERCENT)
	var master: int = clampi(int(round(1.2 * (w - 8))), 0, MAX_MASTER_PERCENT)
	var novice: int = clampi(100 - veteran - master, 10, 100)

	# Статы: +4% за волну, умножить на режим сложности
	var stat_mult: float = (1.0 + 0.04 * (w - 1)) * mode_mult
	var speed_mult: float = minf(MAX_SPEED_MULT, 1.0 + 0.01 * (w - 1))

	# Передышка сокращается с волнами: 45с -> 30с к 16-й волне
	var wave_break: float = maxf(MIN_WAVE_BREAK, 45.0 - (w - 1))

	return {
		"wave": w,
		"count_min": count_min,
		"count_max": count_min + 2,
		"mix": [novice, veteran, master],
		"hp_mult": stat_mult,
		"damage_mult": stat_mult,
		"speed_mult": speed_mult,
		"wave_break": wave_break
	}


## Награда за N пройденных волн поверх боевого дохода; платится при любом исходе
static func wave_bonus(waves_survived: int) -> float:
	var n: int = maxi(0, waves_survived)
	return REWARD_PER_WAVE_BASE * n + REWARD_PER_WAVE_GROWTH * n * (n + 1.0)


## Короткая подпись для UI
static func get_mode_label() -> String:
	return "ВЫЖИВАНИЕ"
