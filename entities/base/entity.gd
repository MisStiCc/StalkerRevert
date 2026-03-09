# entities/base/entity.gd
extends CharacterBody3D
class_name Entity

## Базовый класс для всего живого в игре

signal died(entity: Entity, source: Node)
signal health_changed(current: float, max_health: float)
signal damaged(amount: float, source: Node, critical: bool)
signal entity_spawned(entity: Entity)

# Основные параметры
@export var entity_name: String = "Entity"
@export var max_health: float = 100.0
@export var health: float = 100.0
@export var armor: float = 0.0
@export var move_speed: float = 5.0
@export var is_alive: bool = true

# Компоненты
var health_component: HealthComponent
var navigation_component: NavigationComponent

# Визуал (опционально)
@onready var visuals: Node3D = $Visuals if has_node("Visuals") else null
@onready var label: Label3D = $Label3D if has_node("Label3D") else null

# Ссылки
var zone_controller: Node
var spawn_position: Vector3


func _ready():
	add_to_group("entities")
	spawn_position = global_position
	
	_initialize_components()
	_update_label()
	
	entity_spawned.emit(self)
	health_changed.emit(health, max_health)
	
	# Поиск ZoneController
	zone_controller = get_tree().get_first_node_in_group("zone_controller")
	
	print("Entity инициализирован: " + entity_name)


func _initialize_components():
	# HealthComponent
	health_component = HealthComponent.new()
	health_component.entity = self
	add_child(health_component)
	
	# Копируем параметры в компонент
	health_component.max_health = max_health
	health_component.armor = armor
	health_component.current_health = health
	
	# Подключаем сигналы компонента
	health_component.health_changed.connect(_on_health_changed)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	
	# NavigationComponent (если есть NavigationAgent3D)
	if has_node("NavigationAgent3D"):
		navigation_component = NavigationComponent.new()
		navigation_component.entity = self
		navigation_component.nav_agent = $NavigationAgent3D
		navigation_component.move_speed = move_speed
		add_child(navigation_component)
		print("NavigationComponent добавлен")


func _on_health_changed(current: float, max_h: float):
	health = current
	max_health = max_h
	health_changed.emit(current, max_h)
	_update_label()


func _on_damaged(amount: float, source: Node, critical: bool):
	damaged.emit(amount, source, critical)
	
	# Визуальная обратная связь
	if visuals:
		_flash_red()


func _on_died(source: Node):
	is_alive = false
	died.emit(self, source)
	
	print("Entity умер: " + entity_name)
	
	# Очистка
	queue_free()


func _flash_red():
	if not visuals:
		return
	
	var original_modulate = visuals.modulate if "modulate" in visuals else Color.WHITE
	visuals.modulate = Color.RED
	
	await get_tree().create_timer(0.1).timeout
	
	if is_instance_valid(visuals):
		visuals.modulate = original_modulate


func _update_label():
	if label:
		label.text = "%s\n%.0f/%.0f" % [entity_name, health, max_health]
		label.modulate = _get_health_color()


func _get_health_color() -> Color:
	var percent = health / max_health if max_health > 0 else 0.0
	if percent > 0.6:
		return Color.GREEN
	elif percent > 0.3:
		return Color.YELLOW
	else:
		return Color.RED


# ==================== ПУБЛИЧНОЕ API ====================

func take_damage(amount: float, source: Node = null):
	if health_component:
		health_component.take_damage(amount, source)


func heal(amount: float) -> float:
	if health_component:
		return health_component.heal(amount)
	return 0.0


func set_invulnerable(duration: float):
	if health_component:
		health_component.set_invulnerable(duration)


func get_health_percent() -> float:
	return health / max_health if max_health > 0 else 0.0


func is_critical() -> bool:
	return get_health_percent() < 0.25


func move_to(position: Vector3):
	if navigation_component:
		navigation_component.move_to(position)


func stop_moving():
	if navigation_component:
		navigation_component.stop()


func get_status() -> Dictionary:
	return {
		"name": entity_name,
		"health": health,
		"max_health": max_health,
		"health_percent": get_health_percent(),
		"alive": is_alive,
		"position": global_position
	}