# data/gacha_data.gd
extends RefCounted
class_name GachaData

## Гача Зоны: два рукава - артефакты и мутанты.
## Дроп зависит от уровня кампании: чем выше уровень, тем жирнее редкость.
## Химера - джекпот гачи (маленький вес всегда), либо гарантия на середине
## кампании (уровень CHIMERA_GUARANTEE_LEVEL).

const CHIMERA_GUARANTEE_LEVEL: int = 50

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
