# ui/main_menu/main_menu.gd
extends BasePanel
class_name MainMenu

## Главное меню игры

signal new_game_pressed
signal load_pressed
signal settings_pressed
signal quit_pressed

@onready var new_game_button: Button = $VBox/Buttons/NewGameButton
@onready var load_button: Button = $VBox/Buttons/LoadButton
@onready var settings_button: Button = $VBox/Buttons/SettingsButton
@onready var quit_button: Button = $VBox/Buttons/QuitButton

@onready var load_screen: Control = $LoadScreen
@onready var settings_screen: Control = $SettingsScreen
@onready var save_slots_container: VBoxContainer = $LoadScreen/Panel/VBox/SaveSlots


func _ready():
    panel_name = "MainMenu"
    close_on_escape = false
    
    _setup_buttons()
    _setup_sounds()
    
    load_screen.visible = false
    settings_screen.visible = false
    
    open()
    Logger.info("MainMenu инициализирован", "MainMenu")


func _setup_buttons():
    new_game_button.pressed.connect(_on_new_game_pressed)
    load_button.pressed.connect(_on_load_pressed)
    settings_button.pressed.connect(_on_settings_pressed)
    quit_button.pressed.connect(_on_quit_pressed)


func _setup_sounds():
    new_game_button.mouse_entered.connect(_play_hover_sound)
    load_button.mouse_entered.connect(_play_hover_sound)
    settings_button.mouse_entered.connect(_play_hover_sound)
    quit_button.mouse_entered.connect(_play_hover_sound)


func _play_hover_sound():
    var sm = get_tree().get_first_node_in_group("sound_manager")
    if sm and sm.has_method("play_sound"):
        sm.play_sound("ui_hover", 0.3)


func _play_click_sound():
    var sm = get_tree().get_first_node_in_group("sound_manager")
    if sm and sm.has_method("play_sound"):
        sm.play_sound("ui_click", 0.6)


func _on_new_game_pressed():
    _play_click_sound()
    new_game_pressed.emit()
    
    var gm = Engine.get_singleton("GameManager")
    if gm:
        gm.start_new_game()


func _on_load_pressed():
    _play_click_sound()
    load_pressed.emit()
    load_screen.visible = true
    _refresh_save_slots()


func _on_settings_pressed():
    _play_click_sound()
    settings_pressed.emit()
    settings_screen.visible = true


func _on_quit_pressed():
    _play_click_sound()
    quit_pressed.emit()
    await get_tree().create_timer(0.2).timeout
    get_tree().quit()


func _refresh_save_slots():
    # Очищаем старые кнопки
    for child in save_slots_container.get_children():
        child.queue_free()
    
    var gm = Engine.get_singleton("GameManager")
    if not gm:
        return
    
    var saves_info = gm.get_all_saves_info()
    
    for i in range(3):
        var save_info = saves_info[i]
        var slot_container = HBoxContainer.new()
        
        var info_label = Label.new()
        if save_info.get("exists", false):
            info_label.text = "СЛОТ %d | Забег #%d | Биомасса: %d | Побед: %d" % [
                i + 1,
                save_info.get("run_number", 1),
                save_info.get("biomass", 0),
                save_info.get("wins", 0)
            ]
        else:
            info_label.text = "СЛОТ %d | ПУСТО" % (i + 1)
        
        slot_container.add_child(info_label)
        
        var load_btn = Button.new()
        load_btn.text = "ЗАГРУЗИТЬ"
        load_btn.disabled = not save_info.get("exists", false)
        load_btn.pressed.connect(_load_slot.bind(i))
        slot_container.add_child(load_btn)
        
        var delete_btn = Button.new()
        delete_btn.text = "УДАЛИТЬ"
        delete_btn.disabled = not save_info.get("exists", false)
        delete_btn.pressed.connect(_delete_slot.bind(i))
        slot_container.add_child(delete_btn)
        
        save_slots_container.add_child(slot_container)


func _load_slot(slot: int):
    _play_click_sound()
    var gm = Engine.get_singleton("GameManager")
    if gm and gm.load_game(slot):
        await get_tree().create_timer(0.2).timeout
        gm.change_scene("lab")


func _delete_slot(slot: int):
    _play_click_sound()
    var gm = Engine.get_singleton("GameManager")
    if gm:
        gm.delete_save(slot)
    _refresh_save_slots()


func _on_back_pressed():
    _play_click_sound()
    load_screen.visible = false
    settings_screen.visible = false