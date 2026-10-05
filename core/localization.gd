extends Node

## Локализация RU/EN. Все надписи UI берутся через Loc.t("ключ").
## Язык хранится в user://settings.cfg [ui] lang, переключение - кнопкой
## или Loc.set_lang()/toggle(); сигнал changed переприменяет тексты.

signal changed

var lang: String = "ru"

const LANGS := ["ru", "en"]

# Ключ -> перевод. {имя} подставляется словарём аргументов.
const STRINGS := {
	# ==== Главное меню ====
	"menu.title": {"ru": "S.T.A.L.K.E.R. REVERT", "en": "S.T.A.L.K.E.R. REVERT"},
	"menu.subtitle": {"ru": "Ты - Зона. Останови сталкеров.", "en": "You are the Zone. Stop the stalkers."},
	"menu.new_game": {"ru": "НОВАЯ ИГРА", "en": "NEW GAME"},
	"menu.continue": {"ru": "ПРОДОЛЖИТЬ", "en": "CONTINUE"},
	"menu.load": {"ru": "ЗАГРУЗИТЬ", "en": "LOAD"},
	"menu.settings": {"ru": "НАСТРОЙКИ", "en": "SETTINGS"},
	"menu.back": {"ru": "НАЗАД", "en": "BACK"},
	"menu.quit": {"ru": "ВЫХОД", "en": "QUIT"},
	"menu.language": {"ru": "ЯЗЫК: РУССКИЙ", "en": "LANGUAGE: ENGLISH"},
	"menu.music": {"ru": "Музыка", "en": "Music"},
	"menu.sound": {"ru": "Звук", "en": "Sound"},
	"menu.empty_slot": {"ru": "СЛОТ {n} | ПУСТО", "en": "SLOT {n} | EMPTY"},
	"menu.slot_delete": {"ru": "УДАЛИТЬ", "en": "DELETE"},
	"menu.slot_info": {"ru": "СЛОТ {n} | Забег #{run} | Биомасса: {bio} | Побед: {wins}", "en": "SLOT {n} | Run #{run} | Biomass: {bio} | Wins: {wins}"},

	# ==== Лаборатория ====
	"lab.title": {"ru": "ЛАБОРАТОРНЫЙ КОМПЛЕКС", "en": "LABORATORY COMPLEX"},
	"lab.info_header": {"ru": "ИНФОРМАЦИЯ О ЗАБЕГЕ", "en": "RUN INFORMATION"},
	"lab.biomass_prefix": {"ru": "Биомасса: ", "en": "Biomass: "},
	"lab.start_run": {"ru": "НАЧАТЬ НОВЫЙ ЗАБЕГ", "en": "START NEW RUN"},
	"lab.day": {"ru": "День {n}", "en": "Day {n}"},
	"lab.anomalies": {"ru": "АНОМАЛИИ", "en": "ANOMALIES"},
	"lab.mutants": {"ru": "МУТАНТЫ", "en": "MUTANTS"},
	"lab.monolith": {"ru": "МОНОЛИТ", "en": "MONOLITH"},
	"lab.menu": {"ru": "ГЛАВНОЕ МЕНЮ", "en": "MAIN MENU"},
	"lab.settings": {"ru": "НАСТРОЙКИ", "en": "SETTINGS"},
	"lab.shop": {"ru": "МАГАЗИН", "en": "SHOP"},
	"lab.farm": {"ru": "ФЕРМА", "en": "FARM"},
	"lab.gallery": {"ru": "ГАЛЕРЕЯ", "en": "GALLERY"},
	"lab.save": {"ru": "СОХРАНИТЬ", "en": "SAVE"},
	"lab.storage": {"ru": "ХРАНИЛИЩЕ АРТЕФАКТОВ", "en": "ARTIFACT STORAGE"},
	"lab.storage_open": {"ru": "ОТКРЫТЬ ХРАНИЛИЩЕ", "en": "OPEN STORAGE"},
	"lab.back": {"ru": "НАЗАД", "en": "BACK"},
	"lab.result_title": {"ru": "ИТОГИ ЗАБЕГА", "en": "RUN RESULTS"},
	"lab.result_reward": {"ru": "Получено биомассы: {n}", "en": "Biomass earned: {n}"},
	"lab.result_continue": {"ru": "ПРОДОЛЖИТЬ", "en": "CONTINUE"},
	"lab.settings_music": {"ru": "Музыка", "en": "Music"},
	"lab.settings_sfx": {"ru": "Звуки", "en": "Sounds"},
	"lab.storage_counts": {"ru": "Common: {c}   Rare: {r}   Legendary: {l}", "en": "Common: {c}   Rare: {r}   Legendary: {l}"},
	"lab.stats": {"ru": "Всего забегов: {runs}   Побед: {wins}   Поражений: {loss}\nСталкеров убито: {kills}   Артефактов украдено: {stolen}\nРекорд выживания: {waves} волн", "en": "Total runs: {runs}   Wins: {wins}   Losses: {loss}\nStalkers killed: {kills}   Artifacts stolen: {stolen}\nSurvival record: {waves} waves"},
	"lab.campaign": {"ru": "Кампания", "en": "Campaign"},
	"lab.survival": {"ru": "Выживание", "en": "Survival"},
	"lab.level_of": {"ru": "Уровень {cur}/100 - {title}", "en": "Level {cur}/100 - {title}"},
	"lab.caravan_of": {"ru": "КАРАВАН {cur}/100: «{title}»", "en": "CARAVAN {cur}/100: \"{title}\""},
	"lab.completed": {"ru": " (пройден)", "en": " (completed)"},
	"lab.campaign_done": {"ru": "КАМПАНИЯ ПРОЙДЕНА! Финальный уровень: 100/100", "en": "CAMPAIGN COMPLETE! Final level: 100/100"},
	"lab.survival_line": {"ru": "ВЫЖИВАНИЕ - волны без предела, награда за каждую (рекорд: {rec})", "en": "SURVIVAL - endless waves, reward for each (record: {rec})"},
	"lab.level_short": {"ru": "Ур.{n}", "en": "Lv.{n}"},
	"lab.difficulty": {"ru": "Сложность: {mode}", "en": "Difficulty: {mode}"},
	"lab.saved_msg": {"ru": "Игра сохранена", "en": "Game saved"},
	"lab.upgrade_bought": {"ru": "Улучшение приобретено!", "en": "Upgrade purchased!"},
	"lab.artifact_exchanged": {"ru": "Артефакт обменян", "en": "Artifact exchanged"},

	# ==== Магазин ====
	"shop.title": {"ru": "МАГАЗИН ЗОНЫ - припасы для забега", "en": "ZONE SHOP - supplies for the run"},
	"shop.biomass": {"ru": "Биомасса лаборатории: {n}", "en": "Lab biomass: {n}"},
	"shop.mutants_header": {"ru": "МУТАНТЫ (вступят в бой в начале забега)", "en": "MUTANTS (join the fight at run start)"},
	"shop.artifacts_header": {"ru": "АРТЕФАКТЫ (приманка у монолита в забеге)", "en": "ARTIFACTS (bait at the Monolith in the run)"},
	"shop.locked": {"ru": "🔒 уровень {n}", "en": "🔒 level {n}"},
	"shop.not_enough": {"ru": "Недостаточно биомассы в лаборатории", "en": "Not enough lab biomass"},
	"shop.stars": {"ru": "★ ЗВЁЗДЫ", "en": "★ STARS"},

	# ==== Звёзды ====
	"stars.title": {"ru": "ПРОКАЧКА ЗВЁЗД - дубли гачи дают звезду, звёзды дают статы", "en": "STAR UPGRADES - gacha dupes grant stars, stars grant stats"},
	"stars.biomass_line": {"ru": "Биомасса лаборатории: {n}   (цена звезды: 500 → 1000 → 2000 → 4000)", "en": "Lab biomass: {n}   (star cost: 500 → 1000 → 2000 → 4000)"},
	"stars.mutants_header": {"ru": "МУТАНТЫ (+20% HP и урона за звезду)", "en": "MUTANTS (+20% HP and damage per star)"},
	"stars.artifacts_header": {"ru": "АРТЕФАКТЫ (+20% награды за звезду)", "en": "ARTIFACTS (+20% reward per star)"},
	"stars.artifacts_only": {"ru": "Артефактов пока нет - выигрывайте их в аномалийной гаче\nи за серьёзные достижения (30-й уровень, 30 волн).\nМутанты качаются на ФЕРМЕ: копии x звезда + корм той же звёздности.", "en": "No artifacts yet - win them in the anomaly gacha\nand for major milestones (level 30, wave 30).\nMutants are upgraded at the FARM: copies x star + same-star fodder."},
	"stars.max": {"ru": "МАКС", "en": "MAX"},
	"stars.mult_tip": {"ru": "Множитель статов: x{n}", "en": "Stat multiplier: x{n}"},
	"stars.empty": {"ru": "Коллекция пуста.\nВыигрывайте мутантов и артефакты в гаче и за вехи волн:\nдубликат уже имеющегося даёт +1 звезду автоматически.", "en": "Collection is empty.\nWin mutants and artifacts from gacha and wave milestones:\na duplicate grants +1 star automatically."},
	"stars.fail_msg": {"ru": "Недостаточно биомассы или звёзды максимальны", "en": "Not enough biomass or stars are maxed"},

	# ==== Ферма ====
	"farm.title": {"ru": "ФЕРМА МУТАНТОВ - копии и корм для звёзд", "en": "MUTANT FARM - copies and fodder for stars"},
	"farm.copies": {"ru": "копий: {n}", "en": "copies: {n}"},
	"farm.no_copies": {"ru": "копий нет", "en": "no copies"},
	"farm.star_btn": {"ru": "+★", "en": "+★"},
	"farm.feed_btn": {"ru": "🍽 кормить", "en": "🍽 feed"},
	"farm.pick_target": {"ru": "Кого кормим? Корм: {fodder} (+{points} очков)", "en": "Feed whom? Fodder: {fodder} (+{points} points)"},
	"farm.progress": {"ru": "прогресс {cur}/{need}", "en": "progress {cur}/{need}"},
	"farm.empty": {"ru": "На ферме нет копий.\nДубликаты из гачи и вех отправляются сюда:\nкопия того же типа = +1★, копии других типов = корм.", "en": "No copies on the farm.\nGacha and milestone duplicates come here:\nsame-type copy = +1★, other-type copies = fodder."},
	"farm.value_tip": {"ru": "Ценность корма: {points} очков", "en": "Fodder value: {points} points"},

	# ==== HUD ====
	"hud.energy": {"ru": "⚡ Энергия:", "en": "⚡ Energy:"},
	"hud.biomass": {"ru": "🧬 Биомасса:", "en": "🧬 Biomass:"},
	"hud.wave": {"ru": "🌊 Волна: {n}", "en": "🌊 Wave: {n}"},
	"hud.stalkers": {"ru": "👥 Сталкеров: {n}", "en": "👥 Stalkers: {n}"},
	"hud.emission": {"ru": "🔥 ВЫБРОС ⚡1000", "en": "🔥 EMISSION ⚡1000"},
	"hud.start": {"ru": "▶ СТАРТ", "en": "▶ START"},
	"hud.anomalies": {"ru": "АНОМАЛИИ", "en": "ANOMALIES"},
	"hud.mutants": {"ru": "МУТАНТЫ", "en": "MUTANTS"},
	"hud.locked_tip": {"ru": "Не разблокирован: откройте кампанией или гачей", "en": "Locked: unlock via campaign or gacha"},
	"hud.break_line": {"ru": "⏳ Пауза {sec}с - волна {n}", "en": "⏳ Break {sec}s - wave {n}"},
	"hud.emission_note": {"ru": "ВЫБРОС! Все сталкеры на поле погибнут, аномалии перемешаются", "en": "EMISSION! All stalkers on the field will die, anomalies reshuffle"},
	"hud.no_energy": {"ru": "Нужно 1000 энергии (полная шкала)!", "en": "1000 energy needed (full bar)!"},
	"hud.emission_running": {"ru": "Выброс уже идёт!", "en": "Emission already running!"},
	"hud.emission_active": {"ru": "⚠️ ВЫБРОС! ⚠️", "en": "⚠️ EMISSION! ⚠️"},
	"hud.break_countdown": {"ru": "⏳ Волна {cur}/{max} через {sec}с", "en": "⏳ Wave {cur}/{max} in {sec}s"},
	"hud.wave_announce": {"ru": "🌊 ВОЛНА {cur}/{max}", "en": "🌊 WAVE {cur}/{max}"},
	"hud.anomaly_locked": {"ru": "Аномалия закрыта - нужен артефакт: {artifact}", "en": "Anomaly locked - artifact needed: {artifact}"},
	"hud.anomaly_locked_tip": {"ru": "Получи артефакт: {artifact}", "en": "Obtain the artifact: {artifact}"},
	"hud.reward_note": {"ru": "🎁 НАГРАДА: {text}", "en": "🎁 REWARD: {text}"},
	"reward.anomaly_rolls": {"ru": "Аномалийные крутки: +{n}", "en": "Anomaly rolls: +{n}"},
	"hud.anomaly_rolls_note": {"ru": "🌀 +{n} аномалийных круток!", "en": "🌀 +{n} anomaly rolls!"},
	"farm.recipe": {"ru": "Рецепт звезды: копии x новая звезда + корм + корм той же звёздности", "en": "Star recipe: copies x new star + fodder + same-star fodder"},
	"farm.copies_need": {"ru": "копий {have}/{need}", "en": "copies {have}/{need}"},
	"farm.points_need": {"ru": "корм {have}/{need}", "en": "fodder {have}/{need}"},
	"farm.upgrade_btn": {"ru": "↑ до {n}★", "en": "↑ to {n}★"},
	"farm.fodder_star_rule": {"ru": "Кого кормим? Корм: {fodder} (+{points}) - только с {stars}★", "en": "Feed whom? Fodder: {fodder} (+{points}) - {stars}★ only"},
	"farm.no_matching_fodder": {"ru": "Нет корма с {n}★ - сначала прокачайте звёзды другим мутантам", "en": "No {n}★ fodder - upgrade other mutants' stars first"},
	"farm.need_copies": {"ru": "Нужно копий: {have}/{need}", "en": "Need copies: {have}/{need}"},
	"farm.need_points": {"ru": "Нужно корма: {have}/{need}", "en": "Need fodder: {have}/{need}"},
	"farm.target_max": {"ru": "Звёзды уже максимальны", "en": "Stars already maxed"},
	"reward.gacha_rolls": {"ru": "Крутки гачи: +{n}", "en": "Gacha rolls: +{n}"},
	"hud.rolls_note": {"ru": "🎟 +{n} круток гачи", "en": "🎟 +{n} gacha rolls"},
	"reward.gacha_mutant": {"ru": "Мутант: {name}", "en": "Mutant: {name}"},
	"reward.gacha_artifact": {"ru": "Артефакт: {name}", "en": "Artifact: {name}"},
	"gacha.title": {"ru": "ГАЧА ЗОНЫ - два рукава удачи", "en": "ZONE GACHA - two arms of luck"},
	"gacha.rolls": {"ru": "Круток: {n}", "en": "Rolls: {n}"},
	"gacha.mutants_header": {"ru": "МУТАНТЫ (новый - в коллекцию, дубль - копия на ферму)", "en": "MUTANTS (new - to collection, dup - farm copy)"},
	"gacha.artifacts_header": {"ru": "АРТЕФАКТЫ (новый - в коллекцию, дубль - +1 звезда)", "en": "ARTIFACTS (new - to collection, dup - +1 star)"},
	"gacha.level_used": {"ru": "Шансы по уровню кампании: {n}", "en": "Odds by campaign level: {n}"},
	"gacha.stats": {"ru": "{n} круток | обычные {cp}% | необычные {up}% | редкие {rp}% | легендарки {lp}%", "en": "{n} rolls | common {cp}% | uncommon {up}% | rare {rp}% | legendary {lp}%"},
	"gacha.stats_short": {"ru": "{n} круток | обычные {cp}% | редкие {rp}% | легендарки {lp}%", "en": "{n} rolls | common {cp}% | rare {rp}% | legendary {lp}%"},
	"gacha.last_drops": {"ru": "Последние дропы:", "en": "Latest drops:"},
	"gacha.no_rolls": {"ru": "Крутки закончились!", "en": "Out of rolls!"},
	"rarity.common": {"ru": "обычный", "en": "common"},
	"rarity.uncommon": {"ru": "необычный", "en": "uncommon"},
	"rarity.rare": {"ru": "РЕДКИЙ", "en": "RARE"},
	"rarity.legendary": {"ru": "ЛЕГЕНДАРНЫЙ", "en": "LEGENDARY"},
	"gacha.new_mark": {"ru": "НОВЫЙ!", "en": "NEW!"},
	"gacha.dup_mark": {"ru": "копия", "en": "copy"},
	"gacha.star_mark": {"ru": "+1★", "en": "+1★"},
	"gallery.title": {"ru": "ГАЛЕРЕЯ ЗОНЫ - открытые светятся, закрытые ждут", "en": "ZONE GALLERY - unlocked shine, locked wait"},
	"gallery.locked_tip": {"ru": "Не открыто: уровень кампании {n} или гача", "en": "Locked: campaign level {n} or gacha"},
	"gallery.unlocked_tip": {"ru": "Открыто", "en": "Unlocked"},
	"result.artifacts": {"ru": "Собрано артефактов:", "en": "Artifacts collected:"},
	"result.gacha_header": {"ru": "НАГРАДЫ ЗАБЕГА:", "en": "RUN REWARDS:"},
	"hud.event_incoming": {"ru": "⚠ СОБЫТИЕ: {title}", "en": "⚠ EVENT: {title}"},
	"hud.event_desc": {"ru": "{desc} - враг сильнее, награда щедрее!", "en": "{desc} - tougher enemies, richer rewards!"},

	# ==== Аномалии (кнопки HUD) ====
	"an.heat": {"ru": "Жарка", "en": "Burner"},
	"an.electric": {"ru": "Электра", "en": "Electra"},
	"an.acid": {"ru": "Кислота", "en": "Acid"},
	"an.vortex": {"ru": "Воронка", "en": "Vortex"},
	"an.lift": {"ru": "Лифт", "en": "Lift"},
	"an.whirlwind": {"ru": "Карусель", "en": "Carousel"},
	"an.steam": {"ru": "Пар", "en": "Steam"},
	"an.comet": {"ru": "Комета", "en": "Comet"},
	"an.jelly": {"ru": "Холодец", "en": "Jelly"},
	"an.gas": {"ru": "Газировка", "en": "Soda"},
	"an.acid_cloud": {"ru": "Кисель", "en": "Acid cloud"},
	"an.radiation": {"ru": "Радиация", "en": "Radiation"},
	"an.time": {"ru": "Время", "en": "Time"},
	"an.teleport": {"ru": "Телепорт", "en": "Teleport"},
	"an.tesla": {"ru": "Тесла", "en": "Tesla"},
	"an.fluff": {"ru": "Жг.пух", "en": "Burn fluff"},

	# ==== Мутанты (кнопки HUD) ====
	"mu.dog": {"ru": "Собака", "en": "Dog"},
	"mu.flesh": {"ru": "Плоть", "en": "Flesh"},
	"mu.snork": {"ru": "Снорк", "en": "Snork"},
	"mu.pseudodog": {"ru": "Псевдопёс", "en": "Pseudo-dog"},
	"mu.controller": {"ru": "Контролёр", "en": "Controller"},
	"mu.poltergeist": {"ru": "Полтергейст", "en": "Poltergeist"},
	"mu.bloodsucker": {"ru": "Кровосос", "en": "Bloodsucker"},
	"mu.chimera": {"ru": "Химера", "en": "Chimera"},
	"mu.zombie": {"ru": "Зомби", "en": "Zombie"},

	# ==== Итоги забега ====
	"result.victory": {"ru": "ПОБЕДА", "en": "VICTORY"},
	"result.defeat": {"ru": "ПОРАЖЕНИЕ", "en": "DEFEAT"},
	"result.to_lab": {"ru": "В ЛАБОРАТОРИЮ", "en": "TO THE LAB"},
}

# Имена типов коллекции: ru - из GachaData.DISPLAY_NAMES, en - из DISPLAY_NAMES_EN
const DISPLAY_NAMES_EN := {
	"zombie": "Zombie", "dog_mutant": "Dog", "flesh": "Flesh",
	"snork_mutant": "Snork", "pseudodog": "Pseudo-dog", "poltergeist": "Poltergeist",
	"controller_mutant": "Controller", "bloodsucker": "Bloodsucker",
	"pseudogiant": "Pseudo-giant", "chimera": "Chimera",
	"common_artifact": "Common artifact", "battery_artifact": "Battery",
	"glowstick_artifact": "Glowstick", "slime_artifact": "Slime",
	"spark_artifact": "Spark", "gas_bottle_artifact": "Gas bottle",
	"rare_artifact": "Rare artifact", "energy_artifact": "Energy cell",
	"clock_artifact": "Clock", "hourglass_artifact": "Hourglass",
	"graviton_artifact": "Graviton", "fireball_artifact": "Fireball",
	"jumper_artifact": "Jumper", "flesh_artifact": "Living flesh",
	"void_artifact": "Void", "heart_artifact": "Heart of the Lake",
	"storm_artifact": "Storm", "uranium_artifact": "Uranium",
}


func _ready():
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		var l: String = str(cfg.get_value("ui", "lang", "ru"))
		if l in LANGS:
			lang = l
	print("Loc: язык интерфейса - ", lang)


## Перевод по ключу; args подставляются в плейсхолдеры {имя}
func t(key: String, args: Dictionary = {}) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	var text: String = str(entry.get(lang, entry.get("ru", key)))
	for k in args:
		text = text.replace("{%s}" % k, str(args[k]))
	return text


## Имя типа коллекции на текущем языке
func type_name(type: String) -> String:
	if lang == "en":
		return str(DISPLAY_NAMES_EN.get(type, GachaData.display_name(type)))
	return GachaData.display_name(type)


func set_lang(new_lang: String):
	if new_lang in LANGS and new_lang != lang:
		lang = new_lang
		var cfg := ConfigFile.new()
		cfg.load("user://settings.cfg")
		cfg.set_value("ui", "lang", lang)
		cfg.save("user://settings.cfg")
		changed.emit()
		print("Loc: язык переключён на ", lang)


func toggle():
	set_lang("en" if lang == "ru" else "ru")
