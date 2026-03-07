extends Node
class_name MutantSpawner

## Спавн мутантов (покупка за биомассу)

signal mutant_spawned(mutant: Node, mutant_type: String)

var owner: Node

# Сцены мутантов
@export var mutant_scenes: Dictionary = {
	"dog_mutant": null,
	"flesh": null,
	"snork_mutant": null,
	"pseudodog": null,
	"controller_mutant": null,
	"poltergeist": null,
	"bloodsucker": null,
	"chimera": null,
	"pseudogiant": null,
	"zombie": null
}

# Стоимость мутантов
@export var mutant_costs: Dictionary = {
	"dog_mutant": 15.0,
	"flesh": 15.0,
	"snork_mutant": 25.0,
	"pseudodog": 25.0,
	"controller_mutant": 40.0,
	"poltergeist": 40.0,
	"bloodsucker": 50.0,
	"chimera": 75.0,
	"pseudogiant": 75.0,
	"zombie": 10.0
}

# Активные мутанты
var active_mutants: Array[Node] = []


func _init(node: Node):
	owner = node


func spawn_mutant(mutant_type: String, position: Vector3, cost: float) -> Node:
	"""Создать мутанта определённого типа"""
	if not mutant_scenes.has(mutant_type):
		push_error("MutantSpawner: неизвестный тип - ", mutant_type)
		return null
	
	var scene = mutant_scenes[mutant_type]
	if not scene:
		push_error("MutantSpawner: сцена не найдена для ", mutant_type)
		return null
	
	var mutant = scene.instantiate()
	mutant.position = position
	
	owner.get_tree().current_scene.add_child(mutant)
	active_mutants.append(mutant)
	
	mutant_spawned.emit(mutant, mutant_type)
	return mutant


func remove_mutant(mutant: Node):
	"""Удалить мутанта"""
	if mutant in active_mutants:
		active_mutants.erase(mutant)
	if is_instance_valid(mutant):
		mutant.queue_free()


func get_mutant_cost(mutant_type: String) -> float:
	return mutant_costs.get(mutant_type, 20.0)


func get_available_types() -> Array:
	return mutant_scenes.keys()


func get_active_count() -> int:
	return active_mutants.size()


func get_active_mutants() -> Array[Node]:
	return active_mutants.filter(func(m): return is_instance_valid(m))


func clear_all():
	"""Удалить всех мутантов"""
	for mutant in active_mutants:
		if is_instance_valid(mutant):
			mutant.queue_free()
	active_mutants.clear()


func set_mutant_scenes(scenes: Dictionary):
	mutant_scenes = scenes


func set_costs(costs: Dictionary):
	mutant_costs = costs


func apply_cost_discount(discount: float):
	"""Применить скидку к стоимости (0.9 = -10%)"""
	for key in mutant_costs:
		mutant_costs[key] *= discount
