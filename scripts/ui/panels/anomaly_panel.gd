extends Control
class_name AnomalyPanel

## Панель создания аномалий

signal anomaly_requested(anomaly_type: String, cost: float)

@onready var buttons_container: VBoxContainer = $ScrollContainer/ButtonsContainer

var anomaly_buttons: Dictionary = {}  # type -> Button
var current_energy: float = 0.0


func _ready():
	# Кнопки создаются динамически
	pass


func setup(anomaly_types: Array, costs: Dictionary, enabled: bool = true):
	# Очищаем старые кнопки
	if buttons_container:
		for child in buttons_container.get_children():
			child.queue_free()
	
	anomaly_buttons.clear()
	
	# Создаём кнопки для каждого типа
	for type in anomaly_types:
		var cost = costs.get(type, 50.0)
		var btn = _create_anomaly_button(type, cost, enabled)
		if buttons_container:
			buttons_container.add_child(btn)
		anomaly_buttons[type] = btn


func _create_anomaly_button(anomaly_type: String, cost: float, enabled: bool) -> Button:
	var btn = Button.new()
	btn.text = "%s\nСтоимость: %d" % [anomaly_type, int(cost)]
	btn.pressed.connect(func(): _on_anomaly_clicked(anomaly_type, cost))
	btn.disabled = not enabled
	
	# Сохраняем данные
	btn.set_meta("anomaly_type", anomaly_type)
	btn.set_meta("cost", cost)
	
	return btn


func _on_anomaly_clicked(anomaly_type: String, cost: float):
	if current_energy >= cost:
		anomaly_requested.emit(anomaly_type, cost)
	else:
		# Звук ошибки или визуальная обратная связь
		print("Недостаточно энергии для ", anomaly_type)


func update_energy(energy: float):
	current_energy = energy
	
	# Обновляем доступность кнопок
	for type in anomaly_buttons:
		var btn = anomaly_buttons[type]
		var cost = btn.get_meta("cost", 0)
		btn.disabled = energy < cost


func set_enabled(enabled: bool):
	for btn in anomaly_buttons.values():
		if not btn.disabled:
			btn.disabled = not enabled


func highlight_anomaly(anomaly_type: String):
	# Визуально выделить кнопку
	if anomaly_buttons.has(anomaly_type):
		var btn = anomaly_buttons[anomaly_type]
		# Анимация или эффект
		pass
