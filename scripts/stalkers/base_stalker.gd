extends CharacterBody3D
class_name BaseStalker

## Базовый класс для всех сталкеров с разным поведением
## Использует компонентную архитектуру

# Состояния сталкера
enum StalkerState {
	IDLE, PATROL, SEEK_ARTIFACT, SEEK_MONOLITH, FLEE,
	ATTACK_ANOMALY, ATTACK_MUTANT, CARRY_ARTIFACT
}

# Сигналы
signal died
signal health_changed(current: float, max: float)

# Параметры
@export var stalker_type: String = "novice"
@export var max_health: float = 80.0
@export var speed: float = 4.0
@export var damage: float = 8.0
@export var armor: float = 0.0
@export var vision_range: float = 30.0
@export var behavior: String = "greedy"  # greedy, brave, cautious, aggressive, stealthy

# Компоненты
var state_machine: StalkerStateMachine
var navigation: StalkerNavigation
var memory: StalkerMemory
var health_component: StalkerHealth  # Переименовано для ясности
var carry: StalkerCarry

# Ссылки для обратной связи
@onready var visual: Node3D = $Visual if has_node("Visual") else null
@onready var label: Label3D = $Label3D if has_node("Label3D") else null

# Локальные переменные для совместимости (deprecated - использовать компоненты)
var current_state: int = 0
var is_alive: bool = true
var target_position: Vector3 = Vector3.ZERO
var zone_controller: Node
var monolith: Node

# Память (deprecated - использовать memory компонент)
var danger_zones: Array = []
var known_mutants: Array = []
var memory_timer: float = 0.0

# Ландшафт (deprecated - использовать navigation компонент)
var terrain_manager: Node = null
var current_terrain_type: int = 0
var terrain_speed_multiplier: float = 1.0
var terrain_danger: float = 1.0
var terrain_cover: float = 0.0
var terrain_update_timer: float = 0.0

# Базовые множители
var base_speed: float = 4.0


func _ready():
	health_component = null  # Инициализируем
	base_speed = speed
	is_alive = true
	add_to_group("stalkers")
	
	# Инициализируем компоненты
	_initialize_components()
	
	# ... остальной код ...
	health_changed.emit(max_health, max_health)
	_ready_hook()


func _initialize_components():
	# Создаём компоненты
	health_component = StalkerHealth.new(self)
	health_component.max_health = max_health
	health_component.armor = armor
	add_child(health_component)
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	
	navigation = StalkerNavigation.new(self)
	add_child(navigation)
	navigation.set_speed(speed)
	
	memory = StalkerMemory.new(self)
	add_child(memory)
	
	carry = StalkerCarry.new(self)
	add_child(carry)
	
	state_machine = StalkerStateMachine.new(self)
	add_child(state_machine)
	state_machine.setup({
		"behavior": null,  # Установим позже
		"navigation": navigation,
		"memory": memory,
		"health": health_component,
		"carry": carry
	})


func _ready_hook():
	"""Для переопределения в наследниках"""
	pass


func _apply_run_scaling(run_number: int):
	"""Масштабирование характеристик в зависимости от номера забега"""
	var scale = 1.0 + (run_number - 1) * 0.15
	if health_component:
		health_component.set_max_health(max_health * scale)
	max_health *= scale
	
	speed *= (1.0 + (run_number - 1) * 0.05)
	base_speed = speed
	navigation.set_speed(speed)
	damage *= scale


func _physics_process(delta):
	if not is_alive:
		return
	
	# Проверяем радиацию
	var zone_controller = get_tree().get_first_node_in_group("zone_controller")
	if zone_controller and zone_controller.is_radiating:
		return
	
	# Обновляем компоненты
	_update_terrain_info(delta)
	
	# Обновляем state machine
	if state_machine:
		state_machine._physics_process(delta)
	
	# Legacy: обновляем память для совместимости
	memory_timer += delta
	if memory_timer >= 5.0:
		_refresh_memory()
		memory_timer = 0.0


func _on_health_changed(current: float, max_h: float):
	health_changed.emit(current, max_h)


func _on_died():
	die()


# ==================== LEGACY МЕТОДЫ (для совместимости) ====================

func _evaluate_situation():
	"""Legacy - оценка ситуации. Теперь используется state_machine"""
	# Делегируем в state machine
	if state_machine:
		state_machine._evaluate_state_transitions()


func _execute_state():
	"""Legacy - выполнение состояния. Теперь используется state_machine"""
	pass  # Теперь в state_machine


func _can_kill_anomaly(anomaly) -> bool:
	"""Legacy - проверка может ли сталкер убить аномалию"""
	var anomaly_level = 1
	if anomaly.has_method("get_difficulty"):
		anomaly_level = anomaly.get_difficulty()
	
	match stalker_type:
		"novice": return anomaly_level == 1
		"veteran": return anomaly_level <= 2
		"master": return anomaly_level <= 3
		_: return false


func _refresh_memory():
	"""Legacy - обновление памяти"""
	if memory:
		memory._refresh_memory()


func _get_nearest_anomaly_in_range(range_val: float):
	"""Legacy - получение ближайшей аномалии"""
	if memory:
		var threat = memory.get_nearest_threat()
		if threat and global_position.distance_to(threat.global_position) <= range_val:
			return threat
	return null


func _get_nearest_mutant_in_range(range_val: float):
	"""Legacy - получение ближайшего мутанта"""
	if memory:
		var mutant = memory.get_nearest_mutant()
		if mutant and global_position.distance_to(mutant.global_position) <= range_val:
			return mutant
	return null


func _get_nearest_artifact_in_range(range_val: float):
	"""Legacy - получение ближайшего артефакта"""
	if memory:
		var artifact = memory.get_nearest_artifact()
		if artifact and global_position.distance_to(artifact.global_position) <= range_val:
			return artifact
	return null


# ==================== АРТЕФАКТЫ ====================
func get_carried_artifact():
	"""Legacy - получить переносимый артефакт"""
	if carry:
		return carry.get_carried_artifact()
	return null


func set_carried_artifact(artifact: Node):
	"""Legacy - установить артефакт"""
	if carry:
		carry.pick_up_artifact(artifact)


func drop_artifact():
	"""Legacy - выбросить артефакт"""
	if carry:
		carry.drop_artifact()


func _update_carry_visual(is_carrying: bool):
	# Переопределить в наследниках
	pass


# ==================== ЗДОРОВЬЕ И СМЕРТЬ ====================
func take_damage(amount: float, source = null):
	if not is_alive:
		return
	
	if health_component:
		health_component.take_damage(amount, source)
	else:
		# Legacy - без компонента
		var actual_damage = max(1, amount - armor)
		max_health -= actual_damage
		health_changed.emit(max_health, max_health)
		if max_health <= 0:
			die()


func die():
	if not is_alive:
		return
	
	is_alive = false
	died.emit()
	
	# Выбрасываем артефакт
	if carry and carry.has_artifact():
		carry.drop_artifact()
	
	queue_free()


# ==================== ГЕТТЕРЫ ====================
func get_stalker_type() -> String:
	return stalker_type


func get_behavior() -> String:
	return behavior


# ==================== ЛАНДШАФТ ====================

func _update_terrain_info(delta: float = 0.0):
	"""Обновляет информацию о типе местности"""
	terrain_update_timer += delta
	if terrain_update_timer >= 0.5:
		terrain_update_timer = 0.0
		
		if terrain_manager:
			current_terrain_type = terrain_manager.get_terrain_type_at(global_position)
			terrain_speed_multiplier = terrain_manager.get_terrain_speed_multiplier(global_position)
			terrain_danger = terrain_manager.get_terrain_danger(global_position)
			terrain_cover = terrain_manager.get_terrain_cover(global_position)
			
			# Обновляем навигацию
			if navigation:
				navigation.set_terrain_multiplier(terrain_speed_multiplier)


func get_current_speed() -> float:
	return speed


func get_terrain_danger() -> float:
	return terrain_danger


func get_terrain_cover() -> float:
	return terrain_cover


func get_visibility_to(observer_pos: Vector3) -> float:
	var distance = global_position.distance_to(observer_pos)
	var base_visibility = 1.0 / (1.0 + distance * 0.1)
	base_visibility *= (1.0 - terrain_cover * 0.7)
	return clamp(base_visibility, 0.1, 1.0)


func is_terrain_safe() -> bool:
	return terrain_danger < 1.5


func has_artifact() -> bool:
	if carry:
		return carry.has_artifact()
	return false
