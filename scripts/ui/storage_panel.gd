extends Control
class_name StoragePanel

## Панель хранилища артефактов

signal artifact_exchanged()

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var tabs: TabContainer = $Panel/Margin/VBox/Tabs
@onready var common_container: GridContainer = $Panel/Margin/VBox/Tabs/Common
@onready var rare_container: GridContainer = $Panel/Margin/VBox/Tabs/Rare
@onready var legendary_container: GridContainer = $Panel/Margin/VBox/Tabs/Legendary
@onready var biomass_label: Label = $Panel/Margin/VBox/BiomassLabel
@onready var back_button: Button = $Panel/Margin/VBox/BackButton

var lab_data: LabData = null
var exchange_callback: Callable = Callable()


func _ready():
	visible = false
	back_button.pressed.connect(_on_back_pressed)
	tabs.tab_changed.connect(_on_tab_changed)


func setup(data: LabData, callback: Callable):
	lab_data = data
	exchange_callback = callback
	
	title_label.text = "ХРАНИЛИЩЕ АРТЕФАКТОВ"
	_update_biomass()
	_refresh_all()
	
	visible = true


func _update_biomass():
	if lab_data:
		biomass_label.text = "Биомасса: %d" % int(lab_data.biomass)


func _refresh_all():
	_refresh_rarity_tab("common", common_container)
	_refresh_rarity_tab("rare", rare_container)
	_refresh_rarity_tab("legendary", legendary_container)


func _refresh_rarity_tab(rarity: String, container: GridContainer):
	# Очищаем
	for child in container.get_children():
		child.queue_free()
	
	if not lab_data:
		return
	
	var artifacts: Array
	match rarity:
		"common": artifacts = lab_data.artifacts_common
		"rare": artifacts = lab_data.artifacts_rare
		"legendary": artifacts = lab_data.artifacts_legendary
	
	# Создаём иконки
	for i in range(artifacts.size()):
		var artifact = artifacts[i]
		var value = artifact.get("value", 10)
		
		var btn = _create_artifact_button(rarity, value, i)
		container.add_child(btn)


func _create_artifact_button(rarity: String, value: int, index: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 80)
	
	# Цвет рамки по редкости
	var border_color: Color
	match rarity:
		"common": border_color = Color.WHITE
		"rare": border_color = Color(1, 0.8, 0)
		"legendary": border_color = Color(0.8, 0.4, 1)
	
	# Текст на кнопке
	btn.text = "%s\n%d" % [rarity.to_upper(), value]
	
	# Стилизация
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2)
	style.border_color = border_color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.3, 0.3, 0.3)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	# Обработчик клика
	btn.pressed.connect(func(): _on_artifact_clicked(rarity, value, index))
	
	# Подсказка
	btn.tooltip_text = "Нажмите для обмена на %d биомассы" % value
	
	return btn


func _on_artifact_clicked(rarity: String, value: int, index: int):
	if not lab_data:
		return
	
	# Удаляем артефакт
	match rarity:
		"common": 
			if lab_data.artifacts_common.size() > index:
				lab_data.artifacts_common.remove_at(index)
		"rare": 
			if lab_data.artifacts_rare.size() > index:
				lab_data.artifacts_rare.remove_at(index)
		"legendary": 
			if lab_data.artifacts_legendary.size() > index:
				lab_data.artifacts_legendary.remove_at(index)
	
	# Добавляем биомассу
	lab_data.biomass += value
	
	# Сохраняем
	GameManager.save_game(0)
	
	# Звук
	if GameManager.sound_manager:
		GameManager.sound_manager.play_sound("exchange", 0.7)
	
	# Обновляем UI
	_update_biomass()
	_refresh_all()
	exchange_callback.call()


func _on_tab_changed(_tab_idx):
	# Обновляем при переключении
	_refresh_all()


func _on_back_pressed():
	visible = false
