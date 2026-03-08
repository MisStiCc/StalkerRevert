extends Control
class_name MainMenu

## Главное меню игры

# Функция для получения GameManager (autoload)
func _get_gm() -> Node:
	return get_tree().get_first_node_in_group("game_manager")


@onready var new_game_button: Button = $VBox/Buttons/NewGameButton
@onready var load_button: Button = $VBox/Buttons/LoadButton
@onready var settings_button: Button = $VBox/Buttons/SettingsButton
@onready var quit_button: Button = $VBox/Buttons/QuitButton

# Экраны
@onready var load_screen: Control = $LoadScreen
@onready var settings_screen: Control = $SettingsScreen
@onready var save_slots_container: VBoxContainer = $LoadScreen/Panel/VBox/SaveSlots

var save_slot_buttons: Array[Button] = []


func _ready():
	# Настройка кнопок
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Скрываем дополнительные экраны
	load_screen.visible = false
	settings_screen.visible = false
	
	# Настраиваем звук
	_setup_sounds()
	
	print("🎮 MainMenu: инициализирован")


func _setup_sounds():
	# Наведение на кнопку
	new_game_button.mouse_entered.connect(func(): _play_hover_sound())
	load_button.mouse_entered.connect(func(): _play_hover_sound())
	settings_button.mouse_entered.connect(func(): _play_hover_sound())
	quit_button.mouse_entered.connect(func(): _play_hover_sound())


func _play_hover_sound():
	var gm = _get_gm()
	if gm and gm.has_method("play_sound"):
		gm.play_sound("ui_hover", 0.3)


func _on_new_game_pressed():
	_play_click_sound()
	await get_tree().create_timer(0.2).timeout
	var gm = _get_gm()
	if gm:
		gm.start_new_game()


func _on_load_pressed():
	_play_click_sound()
	load_screen.visible = true
	_refresh_save_slots()


func _on_settings_pressed():
	_play_click_sound()
	settings_screen.visible = true


func _on_quit_pressed():
	_play_click_sound()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _play_click_sound():
	var gm = _get_gm()
	if gm and gm.has_method("play_sound"):
		gm.play_sound("ui_click", 0.6)


func _refresh_save_slots():
	# Очищаем старые кнопки
	for child in save_slots_container.get_children():
		child.queue_free()
	
	# Получаем информацию о сохранениях
	var gm = _get_gm()
	var saves_info = [] if not gm else gm.get_all_saves_info()
	
	for i in range(3):
		var save_info = saves_info[i]
		var slot_container = HBoxContainer.new()
		
		# Информация о слоте
		var info_label = Label.new()
		if save_info["exists"]:
			info_label.text = "СЛОТ %d | Забег #%d | Биомасса: %d | Побед: %d | Поражений: %d" % [
				i + 1,
				save_info.get("run_number", 1),
				save_info.get("biomass", 0),
				save_info.get("wins", 0),
				save_info.get("losses", 0)
			]
		else:
			info_label.text = "СЛОТ %d | ПУСТО" % (i + 1)
		
		slot_container.add_child(info_label)
		
		# Кнопка загрузки
		var load_btn = Button.new()
		load_btn.text = "ЗАГРУЗИТЬ"
		load_btn.disabled = not save_info["exists"]
		load_btn.pressed.connect(func(): _load_slot(i))
		slot_container.add_child(load_btn)
		
		# Кнопка удаления
		var delete_btn = Button.new()
		delete_btn.text = "УДАЛИТЬ"
		delete_btn.disabled = not save_info["exists"]
		delete_btn.pressed.connect(func(): _delete_slot(i))
		slot_container.add_child(delete_btn)
		
		save_slots_container.add_child(slot_container)


func _load_slot(slot: int):
	_play_click_sound()
	var gm = _get_gm()
	if gm and gm.load_game(slot):
		await get_tree().create_timer(0.2).timeout
		gm.change_scene("lab")


func _delete_slot(slot: int):
	_play_click_sound()
	var gm = _get_gm()
	if gm:
		gm.delete_save(slot)
	_refresh_save_slots()


func _on_back_pressed():
	_play_click_sound()
	load_screen.visible = false
	settings_screen.visible = false
