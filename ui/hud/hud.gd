# ui/hud/hud.gd
extends CanvasLayer
class_name HUD

## Интерфейс во время забега

signal anomaly_requested(anomaly_type: String)
signal mutant_requested(mutant_type: String)
signal emission_requested

@onready var energy_label: Label = $EnergyLabel
@onready var energy_value: Label = $EnergyValue
@onready var biomass_label: Label = $BiomassLabel
@onready var biomass_value: Label = $BiomassValue

@onready var emission_button: Button = $EmissionButton
@onready var emission_label: Label = $EmissionLabel
@onready var emission_timer_label: Label = $EmissionTimerLabel

@onready var wave_label: Label = $WaveLabel
@onready var difficulty_label: Label = $DifficultyLabel
@onready var stalker_count_label: Label = $StalkerCountLabel

# Панели аномалий и мутантов (можно добавить позже)
@onready var anomaly_panel: Control = $AnomalyPanel
@onready var mutant_panel: Control = $MutantPanel

var zone_controller: Node
var emission_cooldown: float = 60.0
var emission_timer: float = 0.0
var is_emission_active: bool = false


func _ready():
    zone_controller = get_tree().get_first_node_in_group("zone_controller")
    
    if zone_controller:
        zone_controller.energy_changed.connect(_on_energy_changed)
        zone_controller.biomass_changed.connect(_on_biomass_changed)
        zone_controller.radiation_pulse_started.connect(_on_emission_started)
        zone_controller.radiation_pulse_ended.connect(_on_emission_ended)
        zone_controller.wave_started.connect(_on_wave_started)
    
    emission_button.pressed.connect(_on_emission_pressed)
    
    _setup_sounds()
    
    Logger.info("HUD инициализирован", "HUD")


func _setup_sounds():
    emission_button.mouse_entered.connect(_play_hover_sound)


func _play_hover_sound():
    var sm = get_tree().get_first_node_in_group("sound_manager")
    if sm and sm.has_method("play_sound"):
        sm.play_sound("ui_hover", 0.3)


func _play_click_sound():
    var sm = get_tree().get_first_node_in_group("sound_manager")
    if sm and sm.has_method("play_sound"):
        sm.play_sound("ui_click", 0.6)


func _process(delta):
    if emission_timer > 0:
        emission_timer -= delta
        emission_timer_label.text = "⌛ %dс" % int(emission_timer)
        emission_timer_label.visible = true
    else:
        emission_timer_label.visible = false
    
    if zone_controller:
        var status = zone_controller.get_status()
        stalker_count_label.text = "👥 %d" % status.get("stalkers", 0)


func _on_energy_changed(current: float, max_val: float):
    energy_value.text = "%d / %d" % [int(current), int(max_val)]


func _on_biomass_changed(current: float, max_val: float):
    biomass_value.text = "%d / %d" % [int(current), int(max_val)]


func _on_wave_started(wave_number: int, count: int):
    wave_label.text = "🌊 ВОЛНА %d" % wave_number
    wave_label.modulate = Color.YELLOW
    wave_label.visible = true
    
    var tween = create_tween()
    tween.tween_property(wave_label, "modulate:a", 0.0, 2.0)
    tween.tween_callback(func(): wave_label.visible = false)


func _on_emission_started(level: int):
    is_emission_active = true
    emission_button.disabled = true
    emission_label.text = "⚠️ ВЫБРОС! ⚠️"
    emission_label.modulate = Color.RED
    emission_timer = 0
    emission_timer_label.visible = false


func _on_emission_ended():
    is_emission_active = false
    emission_label.text = ""
    emission_timer = emission_cooldown


func _on_emission_pressed():
    _play_click_sound()
    emission_requested.emit()
    
    if zone_controller and zone_controller.has_method("start_radiation_pulse"):
        if zone_controller.spend_energy(200):
            zone_controller.start_radiation_pulse()


func show_anomaly_panel(visible: bool):
    if anomaly_panel:
        anomaly_panel.visible = visible


func show_mutant_panel(visible: bool):
    if mutant_panel:
        mutant_panel.visible = visible


func update_difficulty(difficulty: float):
    difficulty_label.text = "Сложность: %.1f" % difficulty