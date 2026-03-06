extends CharacterBody3D
class_name BaseStalker

## Базовый класс для всех сталкеров
## Содержит ТОЛЬКО самый общий функционал, необходимый ВСЕМ сталкерам

# Сигналы (общие для всех)
signal died(stalker: Node)
signal health_changed(current: float, max: float)
signal artifact_stolen(artifact)

# Параметры (обязательные для всех)
@export var max_health: float = 100.0
@export var speed: float = 5.0
@export var stalker_type: String = "base"  # novice, veteran, master
@export var attack_damage: float = 10.0

# Артефакт который несёт сталкер
var carried_artifact: BaseArtifact = null

# Состояние
var health: float
var is_alive: bool = true
var zone_controller: Node = null
var target: Node3D = null

# Референсы (должны быть в сцене)
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: Node3D = $Visual
@onready var label: Label3D = $Label3D


func _ready():
	health = max_health
	add_to_group("stalkers")
	zone_controller = get_tree().get_first_node_in_group("zone_controller")
	
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.max_speed = speed
	
	health_changed.emit(health, max_health)
	
	# Вызываем хуки для наследников
	_ready_hook()


# --- Хуки для наследников ---
func _ready_hook(): pass
func _process_hook(_delta): pass
func _physics_hook(_delta): pass
func _damage_hook(_amount: float): pass
func _death_hook(): pass


# --- Может ли сталкер убить аномалию ---
func can_kill_anomaly(anomaly_difficulty: int) -> bool:
	match stalker_type:
		"novice":
			return anomaly_difficulty == 1
		"veteran":
			return anomaly_difficulty <= 2
		"master":
			return true
		_:
			return false


# --- Методы для работы с артефактами ---
func get_stalker_type() -> String:
	return stalker_type


func get_carried_artifact() -> BaseArtifact:
	return carried_artifact


func has_artifact() -> bool:
	return carried_artifact != null


func _on_artifact_stolen(artifact: BaseArtifact):
	carried_artifact = artifact
	artifact_stolen.emit(artifact)
	# Визуальный эффект - несёт артефакт
	_update_artifact_visual(true)


func _update_artifact_visual(has_artifact: bool):
	# Переопределить в наследниках для визуального эффекта
	pass


# --- Публичные методы ---
func take_damage(amount: float):
	if not is_alive: return
	
	health -= amount
	health_changed.emit(health, max_health)
	_damage_hook(amount)
	
	if health <= 0:
		die()


func die():
	if not is_alive: return
	
	is_alive = false
	
	# При смерти артефакт падает на землю
	if carried_artifact:
		carried_artifact.global_position = global_position
		carried_artifact = null
	
	died.emit(self)
	_death_hook()
	
	# Возврат биомассы за убитого сталкера
	if zone_controller and zone_controller.has_method("on_stalker_died"):
		zone_controller.on_stalker_died(self)
	
	queue_free()


func _get_biomass_value() -> float:
	match stalker_type:
		"novice":
			return 8.0
		"veteran":
			return 15.0
		"master":
			return 30.0
		_:
			return 10.0


func set_target(target_pos: Vector3):
	if navigation_agent:
		navigation_agent.target_position = target_pos


# --- Навигация ---
func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()


func _physics_process(delta):
	if not is_alive: return
	
	if navigation_agent and not navigation_agent.is_navigation_finished():
		var next_pos = navigation_agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		velocity = direction * speed
		navigation_agent.velocity = velocity
	
	_physics_hook(delta)


func _process(delta):
	_process_hook(delta)
