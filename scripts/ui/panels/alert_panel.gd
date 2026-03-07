extends Control
class_name AlertPanel

## Панель предупреждений (выброс, сталкеры и т.д.)

signal alert_dismissed(alert_id: String)

enum AlertType {
	RADIATION_PULSE,
	STALKER_APPROACHING,
	MUTANT_DETECTED,
	ARTIFACT_DISCOVERED,
	MONOLITH_DANGER
}

var active_alerts: Dictionary = {}  # type -> node
var alert_counter: int = 0


func _ready():
	# Алерты появляются как children
	pass


func show_alert(alert_type: AlertType, message: String, duration: float = 0.0):
	# Создаём визуальное оповещение
	var alert_node = _create_alert_visual(alert_type, message)
	add_child(alert_node)
	
	var alert_id = "alert_%d" % alert_counter
	alert_counter += 1
	active_alerts[alert_id] = alert_node
	
	# Позиционируем
	_reposition_alerts()
	
	# Автоматическое скрытие если есть duration
	if duration > 0:
		get_tree().create_timer(duration).timeout.connect(
			func(): hide_alert(alert_id)
		)
	
	return alert_id


func _create_alert_visual(alert_type: AlertType, message: String) -> Control:
	var container = PanelContainer.new()
	
	# Стиль по типу
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	match alert_type:
		AlertType.RADIATION_PULSE:
			style.bg_color = Color(1, 0.2, 0.2, 0.9)
		AlertType.STALKER_APPROACHING:
			style.bg_color = Color(1, 0.5, 0, 0.9)
		AlertType.MUTANT_DETECTED:
			style.bg_color = Color(1, 0.3, 0, 0.9)
		AlertType.ARTIFACT_DISCOVERED:
			style.bg_color = Color(0, 0.8, 0.2, 0.9)
		AlertType.MONOLITH_DANGER:
			style.bg_color = Color(1, 0, 0, 0.9)
	
	container.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(label)
	
	return container


func hide_alert(alert_id: String):
	if active_alerts.has(alert_id):
		var alert = active_alerts[alert_id]
		alert.queue_free()
		active_alerts.erase(alert_id)
		_reposition_alerts()
		alert_dismissed.emit(alert_id)


func _reposition_alerts():
	# Размещаем алерты вертикально
	var y_offset = 50.0
	for alert in active_alerts.values():
		alert.position = Vector2(0, y_offset)
		y_offset += 60.0


func show_radiation_pulse(level: int):
	return show_alert(AlertType.RADIATION_PULSE, "⚠️ ВЫБРОС! Уровень %d" % level, 5.0)


func show_stalker_approaching(count: int):
	return show_alert(AlertType.STALKER_APPROACHING, "⚡ Сталкеры: %d" % count)


func show_mutant_detected():
	return show_alert(AlertType.MUTANT_DETECTED, "🐺 Мутант замечен!")


func show_artifact_discovered():
	return show_alert(AlertType.ARTIFACT_DISCOVERED, "💎 Артефакт обнаружен!")


func show_monolith_danger():
	return show_alert(AlertType.MONOLITH_DANGER, "🔴 ОПАСНОСТЬ У МОНОЛИТА!")


func clear_all():
	for alert in active_alerts.values():
		alert.queue_free()
	active_alerts.clear()


func get_active_count() -> int:
	return active_alerts.size()
