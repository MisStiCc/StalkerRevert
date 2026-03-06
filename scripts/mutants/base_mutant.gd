extends CharacterBody3D
class_name BaseMutant

signal died(mutant: BaseMutant)
signal attacked_stalker(stalker: Node3D)
signal spotted_stalker(stalker: Node3D)

# Общие параметры
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var speed: float = 5.0
@export var damage: float = 20.0
@export var armor: float = 0.0
@export var detection_radius: float = 20.0
@export var attack_cooldown: float = 1.0
@export var biomass_cost: float = 50.0
@export var mutant_type: String = "base"

# Состояния
enum State { PATROL, CHASE, ATTACK, DEAD }
var current_state: State = State.PATROL
var target_stalker: Node3D = null
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0

# Ноды
@onready var detection_area: Area3D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer

# ZoneController
var zone_controller: Node = null


func _ready():
	if not detection_area:
		push_error("Mutant: DetectionArea не найден!")
		return
	
	if not attack_timer:
		push_error("Mutant: AttackTimer не найден!")
		return
	
	detection_area.body_entered.connect(_on_stalker_detected)
	detection_area.body_exited.connect(_on_stalker_lost)
	
	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_try_attack)
	
	add_to_group("mutants")
	
	zone_controller = get_tree().get_first_node_in_group("zone_controller")
	if zone_controller and zone_controller.has_method("register_mutant"):
		zone_controller.register_mutant(self)
	
	health = max_health


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	match current_state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_attack(delta)
	
	move_and_slide()


func _patrol(delta):
	if patrol_points.is_empty():
		return
	
	var target_pos = patrol_points[current_patrol_index]
	var direction = (target_pos - global_position).normalized()
	velocity = direction * speed
	
	if global_position.distance_to(target_pos) < 1.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()


func _chase(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		_find_best_target()
		if not target_stalker:
			current_state = State.PATROL
			target_stalker = null
		return
	
	# Движение к сталкеру
	var direction = (target_stalker.global_position - global_position).normalized()
	velocity = direction * speed
	
	# Проверка дистанции для атаки
	if global_position.distance_to(target_stalker.global_position) < 2.0:
		current_state = State.ATTACK
		_try_attack()


func _attack(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		target_stalker = null
		return
	
	if global_position.distance_to(target_stalker.global_position) > 3.0:
		current_state = State.CHASE


# --- НОВЫЙ МЕТОД: Поиск лучшей цели (с артефактом) ---
func _find_best_target():
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	
	# Сначала ищем сталкеров с артефактами
	for s in stalkers:
		if not is_instance_valid(s):
			continue
		if s == self:
			continue
		if s.has_method("has_artifact") and s.has_artifact():
			target_stalker = s
			current_state = State.CHASE
			return
	
	# Иначе ищем любого сталкера
	for s in stalkers:
		if not is_instance_valid(s):
			continue
		if s == self:
			continue
		if s.has_method("take_damage"):
			target_stalker = s
			current_state = State.CHASE
			return


func _on_stalker_detected(body: Node3D):
	if body.has_method("take_damage") and body.is_in_group("stalkers"):
		# Проверяем, есть ли у него артефакт - если да, сразу атакуем
		if body.has_method("has_artifact") and body.has_artifact():
			target_stalker = body
			current_state = State.CHASE
			spotted_stalker.emit(body)
		elif not target_stalker:
			# Запоминаем, но ищем лучшую цель
			_find_best_target()


func _on_stalker_lost(body: Node3D):
	if body == target_stalker:
		_find_best_target()


func _try_attack():
	if current_state == State.ATTACK and target_stalker and is_instance_valid(target_stalker):
		if target_stalker.has_method("take_damage"):
			target_stalker.take_damage(damage)
			attacked_stalker.emit(target_stalker)


func take_damage(dmg: float):
	var actual_damage = max(dmg - armor, 1.0)
	health -= actual_damage
	
	if health <= 0:
		die()


func die():
	if current_state == State.DEAD:
		return
	
	current_state = State.DEAD
	
	# Добавляем биомассу в ZoneController (половину стоимости)
	if zone_controller and zone_controller.has_method("add_biomass"):
		zone_controller.add_biomass(biomass_cost * 0.5)
	
	died.emit(self)
	
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()


func set_patrol_points(points: Array[Vector3]):
	patrol_points = points
	current_patrol_index = 0


func _exit_tree():
	if zone_controller and zone_controller.has_method("unregister_mutant"):
		zone_controller.unregister_mutant(self)
