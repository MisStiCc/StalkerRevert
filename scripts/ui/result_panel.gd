extends Control
class_name ResultPanel

## Панель результатов забега

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var result_label: Label = $Panel/Margin/VBox/ResultLabel
@onready var reward_label: Label = $Panel/Margin/VBox/RewardLabel
@onready var stats_label: Label = $Panel/Margin/VBox/StatsLabel
@onready var artifacts_label: Label = $Panel/Margin/VBox/ArtifactsLabel
@onready var continue_button: Button = $Panel/Margin/VBox/ContinueButton

var run_result: Dictionary = {}


func _ready():
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)


func show_result(result: Dictionary):
	run_result = result
	
	# Заголовок
	title_label.text = "ИТОГИ ЗАБЕГА #%d" % result.get("run_number", 1)
	
	# Результат
	var success = result.get("success", false)
	if success:
		result_label.text = "ПОБЕДА"
		result_label.add_theme_color_override("font_color", Color(0, 1, 0))
	else:
		result_label.text = "ПОЧАЩ"
		result_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	
	# Награда
	var reward = result.get("reward", 0)
	reward_label.text = "Получено биомассы: %d" % reward
	
	# Статистика забега
	if result.has("statistics"):
		var stats = result["statistics"]
		stats_label.text = "Сталкеров убито: %d\nАномалий создано: %d\nМутантов создано: %d\nАртефактов украдено: %d" % [
			stats.get("stalkers_killed", 0),
			stats.get("anomalies_created", 0),
			stats.get("mutants_created", 0),
			stats.get("artifacts_stolen", 0)
		]
	
	# Артефакты
	if result.has("artifacts_collected"):
		var common = 0
		var rare = 0
		var legendary = 0
		
		for a in result["artifacts_collected"]:
			match a.get("type", "common"):
				"common": common += 1
				"rare": rare += 1
				"legendary": legendary += 1
		
		artifacts_label.text = "Собрано артефактов:\nCommon: %d   Rare: %d   Legendary: %d" % [common, rare, legendary]
		artifacts_label.visible = true
	else:
		artifacts_label.visible = false
	
	visible = true


func _on_continue_pressed():
	visible = false
