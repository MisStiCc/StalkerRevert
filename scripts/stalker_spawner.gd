extends Node

signal wave_started(wave_number)
signal wave_ended(wave_number, stalkers_spawned)
signal stalker_spawned(stalker)

@export var spawn_interval: float = 30.0
@export var min_stalkers_per_wave: int = 3
@export var max_stalkers_per_wave: int = 6
@export var spawn_radius: float = 500.0
@export var stalker_types: Array[PackedScene] = []

var current_wave: int = 0
var is_spawning: bool = false
var active_stalkers: Array = []

var _wave_timer: Timer

func _ready():
    _wave_timer = Timer.new()
    _wave_timer.wait_time = spawn_interval
    _wave_timer.timeout.connect(_start_wave)
    _wave_timer.one_shot = false
    add_child(_wave_timer)
    _wave_timer.start()

func _start_wave():
    if is_spawning:
        return
    
    is_spawning = true
    current_wave += 1
    wave_started.emit(current_wave)
    
    var stalkers_to_spawn = randi_range(min_stalkers_per_wave, max_stalkers_per_wave)
    var spawned_count = 0
    
    for i in range(stalkers_to_spawn):
        _spawn_stalker()
        spawned_count += 1
        await get_tree().create_timer(0.5).timeout
    
    is_spawning = false
    wave_ended.emit(current_wave, spawned_count)

func _spawn_stalker():
    if stalker_types.is_empty():
        push_error("No stalker types assigned to spawner!")
        return
    
    var stalker_scene = stalker_types[randi() % stalker_types.size()]
    var stalker = stalker_scene.instantiate()
    
    var angle = randf() * 2 * PI
    var pos = Vector2(cos(angle) * spawn_radius, sin(angle) * spawn_radius)
    pos += Vector2(randf_range(-50, 50), randf_range(-50, 50))
    stalker.position = pos
    
    if stalker.has_signal("died"):
        stalker.died.connect(_on_stalker_died)
    
    get_parent().add_child(stalker)
    active_stalkers.append(stalker)
    stalker_spawned.emit(stalker)

func _on_stalker_died(stalker):
    if stalker in active_stalkers:
        active_stalkers.erase(stalker)
    
    var zone_controller = owner
    if zone_controller and zone_controller.has_method("add_biomass"):
        var biomass_value = 10
        if stalker.has_method("get_biomass_value"):
            biomass_value = stalker.get_biomass_value()
        zone_controller.add_biomass(biomass_value)

func set_spawn_interval(new_interval: float):
    spawn_interval = new_interval
    if _wave_timer:
        _wave_timer.wait_time = spawn_interval

func start_spawning():
    if _wave_timer and not _wave_timer.is_stopped():
        _wave_timer.start()

func stop_spawning():
    if _wave_timer:
        _wave_timer.stop()

func clear_all_stalkers():
    for stalker in active_stalkers:
        if is_instance_valid(stalker):
            stalker.queue_free()
    active_stalkers.clear()
