extends Resource
class_name SaveData

## Сохранённые данные игры

@export var save_time: String = ""
@export var lab_data: LabData
@export var statistics: GameStatistics


func _init():
	lab_data = LabData.new()
	statistics = GameStatistics.new()
