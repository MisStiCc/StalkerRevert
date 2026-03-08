# core/signals.gd
extends Node
class_name GameSignals

# Автозагрузка: Signals

# Игровые события
signal game_started
signal game_paused(paused: bool)
signal game_over(victory: bool, run_number: int, reward: float)
signal game_won(run_number: int, reward: float)

# События зоны
signal zone_entered(zone_name: String)
signal zone_exited(zone_name: String)

# События сталкеров
signal stalker_spawned(stalker: Node, type: GameEnums.StalkerType, position: Vector3)
signal stalker_died(stalker: Node, type: GameEnums.StalkerType, position: Vector3, biomass_returned: float)
signal stalker_stole_artifact(stalker: Node, artifact: Node, value: int)
signal stalker_picked_up_artifact(stalker: Node, artifact: Node)
signal stalker_dropped_artifact(stalker: Node, artifact: Node)

# События мутантов
signal mutant_spawned(mutant: Node, type: GameEnums.MutantType, position: Vector3, cost: float)
signal mutant_died(mutant: Node, type: GameEnums.MutantType, position: Vector3, biomass_returned: float)

# События аномалий
signal anomaly_created(anomaly: Node, type: GameEnums.AnomalyType, position: Vector3, difficulty: int)
signal anomaly_destroyed(anomaly: Node, type: GameEnums.AnomalyType, position: Vector3, difficulty: int)
signal anomaly_damaged(anomaly: Node, damage: float, health: float)

# События артефактов
signal artifact_created(artifact: Node, rarity: GameEnums.Rarity, position: Vector3, value: int)
signal artifact_collected(artifact: Node, collector: Node, value: int)
signal artifact_expired(artifact: Node, position: Vector3)

# События выброса
signal radiation_pulse_started(level: int, duration: float)
signal radiation_pulse_ended
signal radiation_pulse_warning(seconds_left: float)

# События волн
signal wave_started(wave_number: int, stalker_count: int, difficulty: float)
signal wave_ended(wave_number: int, survivors: int, killed: int)

# События ресурсов
signal energy_changed(current: float, max_value: float, percent: float)
signal biomass_changed(current: float, max_value: float, percent: float)
signal critical_energy_reached(percent: float)
signal critical_biomass_reached(percent: float)

# События сложности
signal difficulty_changed(old_difficulty: float, new_difficulty: float)
signal run_started(run_number: int, difficulty: float, pulses_to_win: int)
signal run_ended(run_number: int, success: bool, reward: float)

# UI события
signal ui_button_hovered(button_name: String)
signal ui_button_clicked(button_name: String)
signal ui_panel_opened(panel_name: String)
signal ui_panel_closed(panel_name: String)

# Аудио события
signal music_changed(track_name: String, fade_time: float)
signal sound_played(sound_name: String, volume: float, pitch: float)

# Визуальные события
signal particle_spawned(particle_type: String, position: Vector3)
signal fog_density_changed(density: float)

# Сохранения
signal game_saved(slot: int, save_time: String)
signal game_loaded(slot: int, save_data: Resource)
signal save_deleted(slot: int)

# Ошибки
signal error_occurred(error_code: int, error_message: String, source: String)