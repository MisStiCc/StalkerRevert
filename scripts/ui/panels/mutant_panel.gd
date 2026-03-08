extends Control
class_name MutantPanel

## Панель создания мутантов

signal mutant_requested(mutant_type: String, cost: float)

@onready var buttons_container: VBoxContainer = $ScrollContainer/ButtonsContainer

var mutant_buttons: Dictionary = {}  # type -> Button
var current_biomass: float = 0.0


func _ready():
	# Кнопки создаются динамически
	pass


func setup(mutant_types: Array, costs: Dictionary, enabled: bool = true):
	# Очищаем старые кнопки
	if buttons_container:
		for child in buttons_container.get_children():
			child.queue_free()
	
	mutant_buttons.clear()
	
	# Создаём кнопки для каждого типа
	for type in mutant_types:
		var cost = costs.get(type, 20.0)
		var btn = _create_mutant_button(type, cost, enabled)
		if buttons_container:
			buttons_container.add_child(btn)
		mutant_buttons[type] = btn


func _create_mutant_button(mutant_type: String, cost: float, enabled: bool) -> Button:
	var btn = Button.new()
	btn.text = "%s\nСтоимость: %d" % [mutant_type, int(cost)]
	btn.pressed.connect(func(): _on_mutant_clicked(mutant_type, cost))
	btn.disabled = not enabled
	
	# Сохраняем данные
	btn.set_meta("mutant_type", mutant_type)
	btn.set_meta("cost", cost)
	
	return btn


func _on_mutant_clicked(mutant_type: String, cost: float):
	if current_biomass >= cost:
		mutant_requested.emit(mutant_type, cost)
	else:
		print("Недостаточно биомассы для ", mutant_type)


func update_biomass(biomass: float):
	current_biomass = biomass
	
	# Обновляем доступность кнопок
	for type in mutant_buttons:
		var btn = mutant_buttons[type]
		var cost = btn.get_meta("cost", 0)
		btn.disabled = biomass < cost


func set_enabled(enabled: bool):
	for btn in mutant_buttons.values():
		if not btn.disabled:
			btn.disabled = not enabled


func apply_discount(discount: float):
	"""Применить скидку ко всем мутантам"""
	for type in mutant_buttons:
		var btn = mutant_buttons[type]
		var original_cost = btn.get_meta("cost", 0)
		var new_cost = original_cost * discount
		btn.set_meta("cost", new_cost)
		btn.text = "%s\nСтоимость: %d" % [type, int(new_cost)]
		
		# Обновить доступность
		btn.disabled = current_biomass < new_cost
