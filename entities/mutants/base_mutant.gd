# entities/mutants/base_mutant.gd
extends CharacterBody3D
class_name BaseMutant

signal died(mutant: BaseMutant)
signal attacked_stalker(stalker: Node3D)
signal spotted_stalker(stalker: Node3D)

@export var health: float = 100.0
@export var max_health: float = 100.0
@export var speed: float = 5.0
@export var damage: float = 20.0
@export var armor: float = 0.0
@export var detection_radius: float = 20.0
@export var attack_cooldown: float = 1.0
@export var biomass_cost: float = 50.0
@export var mutant_type: String = "base"
@export var gravity: float = 15.0

enum State { PATROL, CHASE, ATTACK, DEAD }
var current_state: State = State.PATROL
var target_stalker: Node3D = null
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0

# Навигационный компонент
var navigation_component: NavigationComponent
var zone_controller: Node = null

@onready var detection_area: Area3D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer


func _ready():
	if not detection_area:
		push_error("Mutant: DetectionArea не найден!")
		return
	
	if not attack_timer:
		push_error("Mutant: AttackTimer не найден!")
		return
	
	# Создаем навигационный компонент
	_setup_navigation_component()
	
	detection_area.body_entered.connect(_on_stalker_detected)
	detection_area.body_exited.connect(_on_stalker_lost)
	
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_cooldown_ended)
	
	add_to_group("mutants")
	
	zone_controller = get_tree().get_first_node_in_group("zone_controller")
	if zone_controller and zone_controller.has_method("register_mutant"):
		zone_controller.register_mutant(self)
	
	health = max_health


func _setup_navigation_component():
	# Создаем NavigationAgent3D если его нет
	var nav_agent = get_node_or_null("NavigationAgent3D")
	if not nav_agent:
		nav_agent = NavigationAgent3D.new()
		nav_agent.name = "NavigationAgent3D"
		add_child(nav_agent)
	
	# Создаем компонент навигации
	navigation_component = NavigationComponent.new()
	navigation_component.entity = self
	navigation_component.nav_agent = nav_agent
	navigation_component.move_speed = speed
	add_child(navigation_component)
	print("NavigationComponent добавлен для мутанта")


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	# Добавляем гравитацию
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# NavigationComponent обновляется сам в своём _physics_process
	
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
		# Если нет точек патруля, просто стоим
		if navigation_component and not navigation_component.is_navigating():
			# Ищем сталкеров
			_find_best_target()
		return
	
	var target_pos = patrol_points[current_patrol_index]
	
	# Используем навигацию для движения к точке патруля
	if navigation_component and not navigation_component.is_navigating():
		navigation_component.move_to(target_pos)
	
	if global_position.distance_to(target_pos) < 2.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		if navigation_component:
			navigation_component.move_to(patrol_points[current_patrol_index])
	
	# В патруле тоже ищем цели
	_find_best_target()


func _chase(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		_find_best_target()
		if not target_stalker:
			current_state = State.PATROL
			target_stalker = null
			if navigation_component:
				navigation_component.stop()
		return
	
	# Используем навигацию для движения к цели
	if navigation_component:
		navigation_component.move_to(target_stalker.global_position)
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist < 2.0:
		current_state = State.ATTACK
		_try_attack()
	elif dist > detection_radius * 1.5:
		# Потеряли цель
		target_stalker = null
		current_state = State.PATROL
		if navigation_component:
			navigation_component.stop()


func _attack(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		target_stalker = null
		if navigation_component:
			navigation_component.stop()
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 3.0:
		current_state = State.CHASE
		return
	
	# Не двигаемся во время атаки
	if navigation_component:
		navigation_component.stop()
	
	velocity.x = 0
	velocity.z = 0
	
	# Пытаемся атаковать
	_try_attack()


func _find_best_target():
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	var nearest = null
	var nearest_dist = INF
	
	for s in stalkers:
		if not is_instance_valid(s):
			continue
		if s == self:
			continue
		
		var dist = global_position.distance_to(s.global_position)
		if dist < detection_radius and dist < nearest_dist:
			nearest_dist = dist
			nearest = s
	
	if nearest:
		target_stalker = nearest
		current_state = State.CHASE
		spotted_stalker.emit(nearest)
		print("Мутант нашёл цель: ", nearest.name)


func _on_stalker_detected(body: Node3D):
	if not is_instance_valid(body):
		return
		
	if body.has_method("take_damage") and body.is_in_group("stalkers"):
		# Если у сталкера есть артефакт - сразу в приоритет
		if body.has_method("has_artifact") and body.has_artifact():
			target_stalker = body
			current_state = State.CHASE
			spotted_stalker.emit(body)
		# Иначе если нет цели или новая цель ближе
		elif not target_stalker or not is_instance_valid(target_stalker):
			target_stalker = body
			current_state = State.CHASE
			spotted_stalker.emit(body)
		else:
			var dist_to_new = global_position.distance_to(body.global_position)
			var dist_to_current = global_position.distance_to(target_stalker.global_position)
			if dist_to_new < dist_to_current:
				target_stalker = body
				spotted_stalker.emit(body)


func _on_stalker_lost(body: Node3D):
	if body == target_stalker:
		_find_best_target()


func _try_attack():
	if current_state != State.ATTACK:
		return
	
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	if attack_timer.time_left > 0:
		return
	
	if target_stalker.has_method("take_damage"):
		target_stalker.take_damage(damage, self)
		attacked_stalker.emit(target_stalker)
		attack_timer.start()


func _on_attack_cooldown_ended():
	# Можно атаковать снова
	pass


func take_damage(dmg: float, source = null):
	var actual_damage = max(dmg - armor, 1.0)
	health -= actual_damage
	
	if health <= 0:
		die()


func die():
	if current_state == State.DEAD:
		return
	
	current_state = State.DEAD
	
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