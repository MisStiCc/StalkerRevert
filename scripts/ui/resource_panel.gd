extends PanelContainer
class_name ResourcePanel

@onready var energy_label = $VBoxContainer/EnergyLabel
@onready var biomass_label = $VBoxContainer/BiomassLabel


func _ready():
	# Проверяем, что все узлы существуют
	if not energy_label or not biomass_label:
		push_error("ResourcePanel: не найдены дочерние узлы!")
		return


func update_resources(energy: float, biomass: float):
	if energy_label:
		energy_label.text = "Энергия: %d" % energy
	if biomass_label:
		biomass_label.text = "Биомасса: %d" % biomass


# Для обратной совместимости со старым кодом
func update_resources_int(energy: int, biomass: int):
	update_resources(float(energy), float(biomass))