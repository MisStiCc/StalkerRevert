extends Control
class_name UpgradePanel

## Панель улучшений станции

# Функция для получения GameManager
func _get_gm() -> Node:
	return get_tree().get_first_node_in_group("game_manager")

signal upgrade_purchased(upgrade_type: String)

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var upgrades_container: VBoxContainer = $Panel/Margin/VBox/UpgradesContainer
@onready var back_button: Button = $Panel/Margin/VBox/BackButton

var current_station: String = ""
var lab_data: LabData = null
var upgrade_callback: Callable = Callable()


func _ready():
	visible = false
	back_button.pressed.connect(_on_back_pressed)
	
	# Закрытие по Escape
	set_process_input(true)


func _input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		_on_back_pressed()


func setup(station_type: String, data: LabData, callback: Callable):
	current_station = station_type
	lab_data = data
	upgrade_callback = callback
	
	# Настраиваем заголовок
	match station_type:
		"anomaly":
			title_label.text = "СТАНЦИЯ АНОМАЛИЙ"
		"mutant":
			title_label.text = "СТАНЦИЯ МУТАНТОВ"
		"monolith":
			title_label.text = "СТАНЦИЯ МОНОЛИТА"
	
	# Очищаем контейнер
	for child in upgrades_container.get_children():
		child.queue_free()
	
	# Создаём улучшения
	_create_upgrades()
	
	visible = true


func _create_upgrades():
	var upgrades: Array
	
	match current_station:
		"anomaly":
			upgrades = [
				{"id": "anomaly_damage", "name": "Урон аномалий", "desc": "Увеличивает урон всех аномалий"},
				{"id": "anomaly_radius", "name": "Радиус аномалий", "desc": "Увеличивает радиус действия"},
				{"id": "anomaly_duration", "name": "Длительность", "desc": "Увеличивает время жизни"}
			]
		"mutant":
			upgrades = [
				{"id": "mutant_health", "name": "Здоровье мутантов", "desc": "Увеличивает HP мутантов"},
				{"id": "mutant_damage", "name": "Урон мутантов", "desc": "Увеличивает урон мутантов"},
				{"id": "mutant_speed", "name": "Скорость мутантов", "desc": "Увеличивает скорость"},
				{"id": "mutant_cost", "name": "Скидка", "desc": "Уменьшает стоимость создания"}
			]
		"monolith":
			upgrades = [
				{"id": "monolith_energy", "name": "Макс. энергия", "desc": "Увеличивает базовую энергию"},
				{"id": "monolith_regen", "name": "Регенерация", "desc": "Ускоряет восстановление"},
				{"id": "rare_chance", "name": "Редкие артефакты", "desc": "Повышает шанс Rare/Legendary"}
			]
	
	for upgrade in upgrades:
		var item = _create_upgrade_item(upgrade)
		upgrades_container.add_child(item)


func _create_upgrade_item(upgrade: Dictionary) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.custom_minimum_size.y = 80
	
	# Информация
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_label = Label.new()
	name_label.text = upgrade["name"]
	name_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = upgrade["desc"]
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(desc_label)
	
	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.add_theme_color_override("font_color", Color(0, 1, 0))
	info_vbox.add_child(level_label)
	
	container.add_child(info_vbox)
	
	# Кнопка улучшения
	var upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton"
	upgrade_button.text = "УЛУЧШИТЬ"
	upgrade_button.custom_minimum_size = Vector2(150, 60)
	upgrade_button.pressed.connect(func(): _on_upgrade_clicked(upgrade["id"]))
	container.add_child(upgrade_button)
	
	# Сохраняем ID
	container.set_meta("upgrade_id", upgrade["id"])
	
	# Обновляем отображение
	_update_upgrade_item(container, upgrade["id"])
	
	return container


func _update_upgrade_item(container: HBoxContainer, upgrade_id: String):
	if not lab_data:
		return
	
	var level = lab_data.get_upgrade_level(upgrade_id)
	var max_level = lab_data.get_max_level(upgrade_id)
	var cost = lab_data.get_upgrade_cost(upgrade_id)
	var can_upgrade = lab_data.can_upgrade(upgrade_id) and lab_data.biomass >= cost
	
	var level_label = container.get_node("LevelLabel")
	var upgrade_button = container.get_node("UpgradeButton")
	
	level_label.text = "Уровень %d/%d" % [level, max_level]
	
	if level >= max_level:
		upgrade_button.text = "MAX"
		upgrade_button.disabled = true
	else:
		upgrade_button.text = "УЛУЧШИТЬ\n%d биомассы" % int(cost)
		upgrade_button.disabled = not can_upgrade
		
		if not can_upgrade and lab_data.biomass < cost:
			upgrade_button.add_theme_color_override("font_color", Color(1, 0.3, 0.3))


func _on_upgrade_clicked(upgrade_id: String):
	if not lab_data:
		return
	
	var cost = lab_data.get_upgrade_cost(upgrade_id)
	
	if lab_data.biomass >= cost and lab_data.can_upgrade(upgrade_id):
		# Покупаем
		lab_data.biomass -= cost
		lab_data.purchase_upgrade(upgrade_id)
		
		# Сохраняем
		var gm = _get_gm()
		if gm:
			gm.save_game(0)
		
		# Обновляем UI
		for child in upgrades_container.get_children():
			var upgrade_id_child = child.get_meta("upgrade_id", "")
			_update_upgrade_item(child, upgrade_id_child)
		
		# Звук
		if gm and gm.has_method("play_sound"):
			gm.play_sound("upgrade", 0.8)
		
		upgrade_callback.call(upgrade_id)


func _on_back_pressed():
	visible = false
