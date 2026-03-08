extends Node
class_name SoundManager

## Управление звуками и музыкой
## Автоматически подстраивает громкость и переключает треки

signal music_changed(track_name: String)
signal sound_played(sound_name: String)

@export var master_volume: float = 1.0
@export var music_volume: float = 0.7
@export var sfx_volume: float = 0.8

# Музыкальные треки
@export var music_tracks: Dictionary = {
	"ambient": null,
	"combat": null,
	"pulse": null,
	"victory": null,
	"defeat": null
}

# Звуки окружения
@export var ambient_sounds: Dictionary = {
	"wind": null,
	"rain": null,
	"thunder": null,
	"birds": null
}

# Звуки аномалий
@export var anomaly_sounds: Dictionary = {
	"electric": null,
	"thermal": null,
	"gravity": null,
	"chemical": null,
	"radiation": null
}

# Звуки мутантов
@export var mutant_sounds: Dictionary = {
	"dog": null,
	"flesh": null,
	"snork": null,
	"bloodsucker": null,
	"chimera": null
}

# Шаги по местности
@export var footstep_sounds: Dictionary = {
	"plain": null,
	"forest": null,
	"road": null,
	"water": null,
	"ruins": null
}

var _music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []

var _current_music_track: String = ""
var _target_music: AudioStream = null
var _music_fade_timer: float = 0.0
var _music_fade_duration: float = 1.0

var _is_music_playing: bool = false


func _ready():
	_setup_players()
	add_to_group("sound_manager")
	print("🔊 SoundManager: инициализирован")


func _setup_players():
	# Музыка
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	_music_player.volume_db = linear_to_db(music_volume)
	add_child(_music_player)
	
	# Окружение
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.bus = "Ambient"
	_ambient_player.volume_db = linear_to_db(sfx_volume * 0.5)
	add_child(_ambient_player)
	
	# Пулы SFX игроков
	for i in range(5):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_" + str(i)
		player.bus = "SFX"
		player.volume_db = linear_to_db(sfx_volume)
		add_child(player)
		_sfx_players.append(player)


# ==================== МУЗЫКА ====================

func play_music(track_name: String, fade_time: float = 1.0):
	if not music_tracks.has(track_name):
		push_warning("SoundManager: неизвестный трек - ", track_name)
		return
	
	var track = music_tracks[track_name]
	if not track:
		return
	
	if _current_music_track == track_name and _is_music_playing:
		return
	
	_target_music = track
	_music_fade_duration = fade_time
	_music_fade_timer = fade_time
	_current_music_track = track_name
	
	music_changed.emit(track_name)


func stop_music(fade_time: float = 1.0):
	_music_fade_duration = fade_time
	_music_fade_timer = fade_time
	_target_music = null
	_current_music_track = ""


func _process(delta):
	# Плавное затухание/нарастание музыки
	if _music_fade_timer > 0:
		_music_fade_timer -= delta
		var t = 1.0 - (_music_fade_timer / _music_fade_duration)
		
		if _target_music:
			# Нарастание
			if not _is_music_playing:
				_music_player.stream = _target_music
				_music_player.play()
				_is_music_playing = true
			
			_music_player.volume_db = linear_to_db(music_volume * ease(t, 0.5))
		else:
			# Затухание
			_music_player.volume_db = linear_to_db(music_volume * (1.0 - ease(t, 0.5)))
			
			if _music_fade_timer <= 0:
				_music_player.stop()
				_is_music_playing = false


# ==================== ЗВУКИ ====================

func play_sound(sound_name: String, volume_mod: float = 1.0, pitch_mod: float = 1.0):
	var sound = _find_sound(sound_name)
	if not sound:
		return
	
	# Ищем свободный плеер
	var player = _get_free_sfx_player()
	if not player:
		return
	
	player.stream = sound
	player.volume_db = linear_to_db(sfx_volume * volume_mod)
	player.pitch_scale = pitch_mod
	player.play()
	
	sound_played.emit(sound_name)


func _find_sound(sound_name: String) -> AudioStream:
	# Ищем во всех категориях
	if footstep_sounds.has(sound_name):
		return footstep_sounds[sound_name]
	if ambient_sounds.has(sound_name):
		return ambient_sounds[sound_name]
	if anomaly_sounds.has(sound_name):
		return anomaly_sounds[sound_name]
	if mutant_sounds.has(sound_name):
		return mutant_sounds[sound_name]
	
	return null


func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	
	# Все заняты - берём первый
	return _sfx_players[0]


# ==================== СПЕЦИФИЧЕСКИЕ ЗВУКИ ====================

func play_footstep(terrain_type: String):
	play_sound(terrain_type, 0.5, randf_range(0.9, 1.1))


func play_anomaly_sound(anomaly_type: String):
	var sound_key = ""
	match anomaly_type:
		"electric_anomaly", "electric_tesla":
			sound_key = "electric"
		"heat_anomaly", "thermal_steam", "thermal_comet":
			sound_key = "thermal"
		"gravity_vortex", "gravity_lift", "gravity_whirlwind":
			sound_key = "gravity"
		"chemical_gas", "chemical_acid_cloud", "chemical_jelly":
			sound_key = "chemical"
		"radiation_hotspot":
			sound_key = "radiation"
	
	if sound_key and anomaly_sounds.has(sound_key):
		play_sound(sound_key, 0.7)


func play_mutant_sound(mutant_type: String):
	var sound_key = mutant_type
	if mutant_sounds.has(sound_key):
		play_sound(sound_key, 0.8, randf_range(0.9, 1.1))


func play_ui_click():
	play_sound("ui_click", 0.6)


func play_pulse_warning():
	play_sound("pulse_warning", 1.0)


# ==================== НАСТРОЙКИ ====================

func set_master_volume(value: float):
	master_volume = clamp(value, 0.0, 1.0)
	_update_volumes()


func set_music_volume(value: float):
	music_volume = clamp(value, 0.0, 1.0)
	_music_player.volume_db = linear_to_db(music_volume)


func set_sfx_volume(value: float):
	sfx_volume = clamp(value, 0.0, 1.0)
	_update_volumes()


func _update_volumes():
	_music_player.volume_db = linear_to_db(music_volume * master_volume)
	_ambient_player.volume_db = linear_to_db(sfx_volume * master_volume * 0.5)
	for player in _sfx_players:
		player.volume_db = linear_to_db(sfx_volume * master_volume)


func get_current_music() -> String:
	return _current_music_track


func is_playing() -> bool:
	return _is_music_playing
