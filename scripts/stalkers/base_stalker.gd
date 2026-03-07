extends CharacterBody3D
class_name BaseStalker

## Базовый класс для всех сталкеров с разным поведением

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

# Приоритеты поведения
var priority_artifact: bool = false
var priority_monolith: bool = false
var priority_safety: bool = false
var priority_combat: bool = false
var priority_stealth: bool = false

# Состояния
enum StalkerState {
	IDLE, PATROL, SEEK_ARTIFACT, SEEK_MONOLITH, FLEE,
	ATTACK_ANOMALY, ATTACK_MUTANT, CARRY_ARTIFACT
}

var current_state: StalkerState = StalkerState.PATROL
var health: float
var is_alive: bool = true
var carried_artifact: Node = null
var target_position: Vector3
var zone_controller: Node
var monolith: Node

# Навигация
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null
@onready var visual: Node3D = $Visual if has_node("Visual") else null
@onready var label: Label3D = $Label3D if has_node("Label3D") else null

# Память
var danger_zones: Array = []
var known_mutants: Array = []
var memory_timer: float = 0.0


func _ready():
	health = max_health
	add_to_group("stalkers")
	
	zone_controller = get_tree().get_first_node_in_group("zone_controller")
	monolith = get_tree().get_first_node_in_group("monolith")
	
	if zone_controller:
		zone_controller.register_stalker(self)
	
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.max_speed = speed
	
	# Применяем прогрессию забега
	if zone_controller and zone_controller.has_method("get_run_number"):
		var run = zone_controller.get_run_number()
		_apply_run_scaling(run)
	
	health_changed.emit(health, max_health)
	_ready_hook()


func _ready_hook():
	"""Для переопределения в наследниках"""
	pass


func _apply_run_scaling(run_number: int):
	"""Масштабирование характеристик в зависимости от номера забега"""
	var scale = 1.0 + (run_number - 1) * 0.15
	max_health *= scale
	health = max_health
	speed *= (1.0 + (run_number - 1) * 0.05)
	damage *= scale


func _physics_process(delta):
	if not is_alive or not zone_controller or zone_controller.is_radiating:
		return
	
	# Обновляем память
	memory_timer += delta
	if memory_timer >= 5.0:
		_refresh_memory()
		memory_timer = 0.0
	
	# Оцениваем ситуацию
	_evaluate_situation()
	
	# Выполняем действие
	_execute_state()
	
	# Движение
	if navigation_agent and not navigation_agent.is_navigation_finished():
		var next_pos = navigation_agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		velocity = direction * speed
		navigation_agent.velocity = velocity
	

func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()


# ==================== ОЦЕНКА СИТУАЦИИ ====================
func _evaluate_situation():
	"""Оценка текущей ситуации и выбор приоритета"""
	
	# 1. Если несём артефакт - главная цель унести
	if carried_artifact:
		current_state = StalkerState.CARRY_ARTIFACT
		if monolith:
			target_position = global_position + (global_position - monolith.global_position).normalized() * 100
		return
	
	# 2. Проверка опасностей (аномалии)
	var nearest_danger = _get_nearest_anomaly_in_range(5.0)
	if nearest_danger and _can_kill_anomaly(nearest_danger):
		if behavior in ["aggressive", "brave"]:
			current_state = StalkerState.ATTACK_ANOMALY
			target_position = nearest_danger.global_position
			return
	elif nearest_danger:
		if behavior in ["cautious", "stealthy"]:
			current_state = StalkerState.FLEE
			target_position = (global_position - nearest_danger.global_position).normalized() * 30
			return
	
	# 3. Проверка мутантов
	var nearest_mutant = _get_nearest_mutant_in_range(10.0)
	if nearest_mutant:
		if behavior == "aggressive":
			current_state = StalkerState.ATTACK_MUTANT
			target_position = nearest_mutant.global_position
			return
		elif behavior == "cautious":
			current_state = StalkerState.FLEE
			target_position = (global_position - nearest_mutant.global_position).normalized() * 30
			return
	
	# 4. Видим артефакт?
	var visible_artifact = _get_nearest_artifact_in_range(vision_range)
	if visible_artifact:
		if behavior == "greedy":
			current_state = StalkerState.SEEK_ARTIFACT
			target_position = visible_artifact.global_position
			return
	
	# 5. По умолчанию - идём к монолиту
	if monolith:
		current_state = StalkerState.SEEK_MONOLITH
		target_position = monolith.global_position


func _execute_state():
	"""Выполнение действия в зависимости от состояния"""
	match current_state:
		StalkerState.SEEK_ARTIFACT, StalkerState.SEEK_MONOLITH, StalkerState.CARRY_ARTIFACT:
			if navigation_agent:
				navigation_agent.target_position = target_position
		
		StalkerState.ATTACK_ANOMALY:
			if navigation_agent:
				navigation_agent.target_position = target_position
			if global_position.distance_to(target_position) < 3.0:
				var anomaly = _get_nearest_anomaly_in_range(3.0)
				if anomaly and anomaly.has_method("take_damage"):
					anomaly.take_damage(damage, self)
		
		StalkerState.ATTACK_MUTANT:
			if navigation_agent:
				navigation_agent.target_position = target_position
			if global_position.distance_to(target_position) < 3.0:
				var mutant = _get_nearest_mutant_in_range(3.0)
				if mutant and mutant.has_method("take_damage"):
					mutant.take_damage(damage, self)
		
		StalkerState.FLEE:
			if navigation_agent:
				navigation_agent.target_position = global_position + target_position.normalized() * 30


func _can_kill_anomaly(anomaly) -> bool:
	"""Проверяет, может ли сталкер убить аномалию"""
	var anomaly_level = 1
	if anomaly.has_method("get_difficulty"):
		anomaly_level = anomaly.get_difficulty()
	
	match stalker_type:
		"novice": return anomaly_level == 1
		"veteran": return anomaly_level <= 2
		"master": return anomaly_level <= 3
		_: return false


# ==================== ПАМЯТЬ ====================
func _refresh_memory():
	"""Обновляет информацию о замеченных угрозах"""
	danger_zones = []
	known_mutants = []
	
	var anomalies = get_tree().get_nodes_in_group("anomalies")
	for a in anomalies:
		if is_instance_valid(a) and global_position.distance_to(a.global_position) < vision_range:
			danger_zones.append(a)
	
	var mutants = get_tree().get_nodes_in_group("mutants")
	for m in mutants:
		if is_instance_valid(m) and global_position.distance_to(m.global_position) < vision_range:
			known_mutants.append(m)


func _get_nearest_anomaly_in_range(range_val: float):
	var nearest = null
	var min_dist = range_val
	for a in danger_zones:
		if not is_instance_valid(a): continue
		var dist = global_position.distance_to(a.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = a
	return nearest


func _get_nearest_mutant_in_range(range_val: float):
	var nearest = null
	var min_dist = range_val
	for m in known_mutants:
		if not is_instance_valid(m): continue
		var dist = global_position.distance_to(m.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = m
	return nearest


func _get_nearest_artifact_in_range(range_val: float):
	var artifacts = get_tree().get_nodes_in_group("artifacts")
	var nearest = null
	var min_dist = range_val
	for a in artifacts:
		if not is_instance_valid(a) or a.is_collected: continue
		var dist = global_position.distance_to(a.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = a
	return nearest


# ==================== АРТЕФАКТЫ ====================
func get_carried_artifact():
	return carried_artifact


func set_carried_artifact(artifact: Node):
	carried_artifact = artifact
	_update_carry_visual(true)


func drop_artifact():
	if carried_artifact:
		carried_artifact.global_position = global_position + Vector3(0, 1, 0)
		carried_artifact.visible = true
		if carried_artifact.has_method("set_collected"):
			carried_artifact.set_collected(false)
		carried_artifact = null
		_update_carry_visual(false)


func _update_carry_visual(is_carrying: bool):
	# Переопределить в наследниках
	pass


# ==================== ЗДОРОВЬЕ И СМЕРТЬ ====================
func take_damage(amount: float, source = null):
	if not is_alive: return
	
	var actual_damage = max(1, amount - armor)
	health -= actual_damage
	health_changed.emit(health, max_health)
	
	if health <= 0:
		die()


func die():
	if not is_alive: return
	
	is_alive = false
	died.emit()
	
	if carried_artifact:
		drop_artifact()
	
	queue_free()


# ==================== ГЕТТЕРЫ ====================
func get_stalker_type() -> String:
	return stalker_type


func get_behavior() -> String:
	return behavior
