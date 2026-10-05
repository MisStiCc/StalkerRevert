# data/gacha_data.gd
extends RefCounted
class_name GachaData

## Гача Зоны: два рукава - артефакты и мутанты.
## Дроп зависит от уровня кампании: чем выше уровень, тем жирнее редкость.
## Химера - джекпот гачи (маленький вес всегда), либо гарантия на середине
## кампании (уровень CHIMERA_GUARANTEE_LEVEL).

const CHIMERA_GUARANTEE_LEVEL: int = 50

# ГЕЙТИНГ КОЛЛЕКЦИИ: пока тип не разблокирован, применить его в бою нельзя.
# На старте доступны только слабейшие; кампания открывает остальных на 1 звезду.
# Химера вне таблицы - джекпот гачи с гарантией на уровне 50.
const DEFAULT_UNLOCKED_MUTANTS := ["zombie", "dog_mutant", "flesh"]
const DEFAULT_UNLOCKED_ARTIFACTS := ["common_artifact", "battery_artifact", "glowstick_artifact"]

# Уровень кампании -> что открывается (мутанты по силе, арты по редкости)
const UNLOCK_TABLE := {
	3: {"artifacts": ["slime_artifact", "spark_artifact"]},
	5: {"mutants": ["snork_mutant"], "artifacts": ["gas_bottle_artifact"]},
	8: {"mutants": ["pseudodog"]},
	10: {"artifacts": ["rare_artifact", "energy_artifact"]},
	15: {"mutants": ["poltergeist"]},
	20: {"mutants": ["controller_mutant"], "artifacts": ["clock_artifact"]},
	25: {"mutants": ["bloodsucker"], "artifacts": ["hourglass_artifact"]},
	30: {"artifacts": ["graviton_artifact"]},
	35: {"artifacts": ["fireball_artifact"]},
	40: {"artifacts": ["jumper_artifact", "flesh_artifact"]},
	45: {"mutants": ["pseudogiant"]},
	60: {"artifacts": ["void_artifact"]},
	70: {"artifacts": ["heart_artifact"]},
	80: {"artifacts": ["storm_artifact"]},
	90: {"artifacts": ["uranium_artifact"]},
}

# Пул мутантов: редкость -> [тип, вес]
# Химера - джекпот: исключена из пула до 30 уровня кампании, дальше её вес растёт
const MUTANT_POOL := {
	"common": [["zombie", 30.0], ["dog_mutant", 25.0], ["flesh", 25.0]],
	"uncommon": [["snork_mutant", 12.0], ["pseudodog", 10.0], ["poltergeist", 8.0]],
	"rare": [["controller_mutant", 6.0], ["bloodsucker", 5.0]],
	"legendary": [["pseudogiant", 4.0], ["chimera", 0.0]],
}

# Пул артефактов по редкости (сцены из entities/artifacts)
const ARTIFACT_POOL := {
	"common": ["common_artifact", "battery_artifact", "glowstick_artifact", "slime_artifact", "spark_artifact", "gas_bottle_artifact"],
	"rare": ["rare_artifact", "energy_artifact", "clock_artifact", "hourglass_artifact", "graviton_artifact", "fireball_artifact", "jumper_artifact", "flesh_artifact"],
	"legendary": ["void_artifact", "heart_artifact", "storm_artifact", "uranium_artifact"],
}

# Награда артефактом: ресурсный бонус по редкости (энергия / биомасса)
const ARTIFACT_BONUS := {
	"common": [300.0, 100.0],
	"rare": [600.0, 250.0],
	"legendary": [1200.0, 500.0],
}

# Круглые волны выживания: сбалансированные награды
const MILESTONE_WAVES := [10, 20, 30]

# МАГАЗИН: покупка НЕтоповых мутантов и артефактов за биомассу лаборатории.
# Купленный мутант бесплатно вступит в бой в начале следующего забега,
# артефакт - заспавнится у монолита как приманка для сталкеров.
# Химеры, псевдогиганта и легендарных артефактов в магазине нет - только гача и вехи.
const SHOP_MUTANTS := [
	["zombie", "Зомби", 30], ["dog_mutant", "Собака", 45], ["flesh", "Плоть", 45],
	["snork_mutant", "Снорк", 75], ["pseudodog", "Псевдопёс", 75],
	["poltergeist", "Полтергейст", 120], ["controller_mutant", "Контролёр", 120],
	["bloodsucker", "Кровосос", 150],
]
const SHOP_ARTIFACTS := [
	["battery_artifact", "Батарейка", 150],
	["energy_artifact", "Энергетик", 350],
	["clock_artifact", "Часы", 350],
	["rare_artifact", "Редкий артефакт", 600],
]


# КОРМ ЗВЁЗД: дубликат того же типа даёт звезду сразу; слабые типы можно
# ПОЖЕРТВОВАТЬ - они покидают коллекцию, давая очки корма цели.
# Ценность корма по редкости и очковая цена следующей звезды (текущие звёзды -> очков).
const FODDER_VALUE := {"common": 1, "uncommon": 2, "rare": 3, "legendary": 5}
const STAR_FEED_COST := {1: 2, 2: 4, 3: 6, 4: 8}

# Русские имена всех типов коллекции (панель звёзд, логи)
const DISPLAY_NAMES := {
	"zombie": "Зомби", "dog_mutant": "Собака", "flesh": "Плоть",
	"snork_mutant": "Снорк", "pseudodog": "Псевдопёс", "poltergeist": "Полтергейст",
	"controller_mutant": "Контролёр", "bloodsucker": "Кровосос",
	"pseudogiant": "Псевдогигант", "chimera": "Химера",
	"common_artifact": "Обычный артефакт", "battery_artifact": "Батарейка",
	"glowstick_artifact": "Светляк", "slime_artifact": "Слизь",
	"spark_artifact": "Искра", "gas_bottle_artifact": "Газовый баллон",
	"rare_artifact": "Редкий артефакт", "energy_artifact": "Энергетик",
	"clock_artifact": "Часы", "hourglass_artifact": "Песочные часы",
	"graviton_artifact": "Гравитон", "fireball_artifact": "Огненный шар",
	"jumper_artifact": "Прыгун", "flesh_artifact": "Живая плоть",
	"void_artifact": "Пустота", "heart_artifact": "Сердце Озера",
	"storm_artifact": "Гроза", "uranium_artifact": "Уран",
}


static func display_name(type: String) -> String:
	return DISPLAY_NAMES.get(type, type)


static func get_default_unlocked_mutants() -> Array:
	return DEFAULT_UNLOCKED_MUTANTS.duplicate()


static func get_default_unlocked_artifacts() -> Array:
	return DEFAULT_UNLOCKED_ARTIFACTS.duplicate()


static func get_unlocks_at(campaign_level: int) -> Dictionary:
	return UNLOCK_TABLE.get(int(campaign_level), {})


## Уровень кампании, на котором открывается тип. 0 = доступен с самого начала.
static func get_unlock_campaign_level(type: String) -> int:
	for level in UNLOCK_TABLE:
		var entry: Dictionary = UNLOCK_TABLE[level]
		if entry.get("mutants", []).has(type) or entry.get("artifacts", []).has(type):
			return int(level)
	return 0


static func get_mutant_rarity(type: String) -> String:
	for rarity in MUTANT_POOL:
		for e in MUTANT_POOL[rarity]:
			if e[0] == type:
				return rarity
	return "common"


static func get_artifact_rarity(type: String) -> String:
	for rarity in ARTIFACT_POOL:
		if ARTIFACT_POOL[rarity].has(type):
			return rarity
	return "common"


## Очки корма за пожертвованный тип
static func get_fodder_value(type: String, is_mutant: bool) -> int:
	var rarity: String = get_mutant_rarity(type) if is_mutant else get_artifact_rarity(type)
	return int(FODDER_VALUE.get(rarity, 1))


## Очков корма до следующей звезды при текущих звёздах
static func get_star_feed_cost(current_stars: int) -> int:
	return int(STAR_FEED_COST.get(maxi(current_stars, 1), 8))


static func get_shop_mutants() -> Array:
	return SHOP_MUTANTS


static func get_shop_artifacts() -> Array:
	return SHOP_ARTIFACTS


static func rarity_weights(level: int) -> Dictionary:
	# Легендарки: ~4% на старте, до 10% к концу кампании
	var legendary := minf(4.0 + float(level) * 0.06, 12.0)
	var rare := 20.0 + float(level) * 0.1
	if rare > 35.0: rare = 35.0
	return {
		"common": 100.0 - legendary - rare,
		"rare": rare,
		"legendary": legendary,
	}


static func _pick_weighted(pool: Array) -> String:
	var total := 0.0
	for e in pool:
		total += e[1]
	var r := randf() * total
	for e in pool:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return pool[0][0]


static func roll_rarity(level: int) -> String:
	var w := rarity_weights(level)
	return _pick_weighted([["common", w["common"]], ["rare", w["rare"]], ["legendary", w["legendary"]]])


static func roll_mutant_gacha(level: int) -> Dictionary:
	var rarity := roll_rarity(level)
	var pool: Array = MUTANT_POOL[rarity].duplicate(true)
	# Химера - джекпот: до 30 уровня исключена, дальше её вес растёт с уровнем
	if level >= 30:
		for e in pool:
			if e[0] == "chimera":
				e[1] = float(level) / 10.0
	var type := _pick_weighted(pool)
	return {"type": type, "rarity": rarity}


static func roll_artifact_gacha(level: int) -> Dictionary:
	var rarity := roll_rarity(level)
	var types: Array = ARTIFACT_POOL[rarity]
	var type: String = types[randi() % types.size()]
	var bonus: Array = ARTIFACT_BONUS[rarity]
	return {"type": type, "rarity": rarity, "energy": bonus[0], "biomass": bonus[1]}


static func milestone_wave_reward(waves: int) -> Dictionary:
	# Круглые волны выживания: сбалансированные награды (мутант + артефакт)
	if waves >= 30:
		return {"mutant": "pseudogiant", "artifact": "rare_artifact", "label": "30 волн"}
	if waves >= 20:
		return {"mutant": "bloodsucker", "artifact": "energy_artifact", "label": "20 волн"}
	if waves >= 10:
		return {"mutant": "snork_mutant", "artifact": "battery_artifact", "label": "10 волн"}
	return {}
