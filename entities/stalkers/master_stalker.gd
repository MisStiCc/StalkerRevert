# entities/stalkers/master_stalker.gd
extends BaseStalker
class_name MasterStalker

## Мастер - элитный сталкер с агрессивным поведением

var _monolith_check_timer: float = 0.0
var _nav_check_timer: float = 0.0
var _scan_timer: float = 0.0
var _combo_ready: bool = false
var _combo_chance: float = 0.2
var _execute_threshold: float = 0.2
var _scan_interval: float = 1.5

# ВЫСОТА СТАЛКЕРА НАД ЗЕМЛЁЙ - origin тела на земле Y=0
# (капсула высотой 1.8 со смещением -0.9 в base_stalker.tscn)
const STALKER_HEIGHT: float = 1.8


func _ready():
	stalker_type = GameEnums.StalkerType.MASTER
	behavior_type = GameEnums.StalkerBehavior.AGGRESSIVE
	health = 250.0
	max_health = 250.0
	speed = 4.2
	damage = 25.0
	detection_radius = 30.0
	attack_range = 4.0
	attack_cooldown = 0.6
	biomass_return = 30.0
	armor = 10.0
	
	_init_components()
	
	monolith = get_tree().get_first_node_in_group("monolith")
	if monolith:
		print("MasterStalker: Монолит НАЙДЕН на позиции ", monolith.global_position)
	else:
		print("MasterStalker: ОШИБКА - Монолит НЕ НАЙДЕН!")
	
	if state_machine:
		state_machine.setup({
			"behavior": behavior_strategy,
			"navigation": navigation_component,
			"memory": memory_component,
			"carry": carry_component,
			"health": health_component,
			"monolith": monolith
		})
	
	_setup_visuals()
	
	super._ready()
	
	var pos = global_position
	pos.y = STALKER_HEIGHT
	global_position = pos
	
	print("MasterStalker готов на позиции ", global_position)


func _init_components():
	health_component = HealthComponent.new()
	health_component.entity = self
	health_component.max_health = max_health
	health_component.armor = armor
	health_component.current_health = health
	add_child(health_component)
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	
	navigation_component = NavigationComponent.new()
	navigation_component.entity = self
	if has_node("NavigationAgent3D"):
		navigation_component.nav_agent = $NavigationAgent3D
	navigation_component.move_speed = speed
	navigation_component.enable_debug(false)
	add_child(navigation_component)
	
	memory_component = MemoryComponent.new()
	memory_component.stalker = self
	memory_component.vision_range = detection_radius
	add_child(memory_component)
	memory_component.threat_detected.connect(_on_threat_detected)
	memory_component.threat_lost.connect(_on_threat_lost)
	memory_component.artifact_detected.connect(_on_artifact_detected)
	
	carry_component = CarryComponent.new()
	carry_component.stalker = self
	add_child(carry_component)
	carry_component.artifact_picked_up.connect(_on_artifact_picked_up)
	carry_component.artifact_dropped.connect(_on_artifact_dropped)
	carry_component.artifact_stolen.connect(_on_artifact_stolen)
	
	behavior_strategy = StalkerBehaviorStrategy.create(behavior_type, self)
	
	state_machine = StateMachineComponent.new()
	state_machine.stalker = self
	add_child(state_machine)


func _setup_visuals():
	if visuals:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.8, 0.2, 0.8)
		material.metallic = 0.8
		material.roughness = 0.1
		material.emission_enabled = true
		material.emission = Color(0.8, 0.2, 0.8)
		visuals.material_override = material
	
	if label:
		label.text = "🟣 МАСТЕР"
		label.modulate = Color(0.8, 0.2, 0.8)
		label.font_size = 56
		label.outline_size = 3


func _physics_hook(delta):
	_nav_check_timer += delta
	if _nav_check_timer > 2.0:
		_nav_check_timer = 0.0
		_check_height()
	
	_monolith_check_timer += delta
	if _monolith_check_timer > 5.0:
		_monolith_check_timer = 0.0
		if monolith and is_instance_valid(monolith):
			var dist = global_position.distance_to(monolith.global_position)
			print("MasterStalker: расстояние до монолита = ", dist)
	
	_scan_timer += delta
	if state_machine and state_machine.current_state == GameEnums.StalkerState.PATROL and _scan_timer > _scan_interval:
		_scan_timer = 0.0
		_scan_for_targets()
	
	# ГРАВИТАЦИЯ
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0:
			velocity.y = 0
	
	# Движение
	move_and_slide()
	
	_check_attack(delta)


func _check_height():
	"""Спасение только при провале под землю (Y < 0).
	Физика сама ставит тело на пол, поэтому штатную высоту не трогаем."""
	if global_position.y >= 0.0:
		return
	
	var query = PhysicsRayQueryParameters3D.new()
	query.from = Vector3(global_position.x, 5.0, global_position.z)
	query.to = Vector3(global_position.x, -10.0, global_position.z)
	query.collision_mask = 1
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	
	velocity = Vector3.ZERO
	if result:
		var pos = global_position
		pos.y = result.position.y + STALKER_HEIGHT
		global_position = pos
		print("MasterStalker: провалился под землю, возвращён на пол Y=", pos.y)
	else:
		# Земли нет (чанк выгружен) - возвращаем к монолиту
		var mx = 10.0
		var mz = 10.0
		if monolith and is_instance_valid(monolith):
			mx = monolith.global_position.x + 10.0
			mz = monolith.global_position.z + 10.0
		global_position = Vector3(mx, STALKER_HEIGHT, mz)
		print("MasterStalker: земли нет под сталкером, возвращён к монолиту")


func _scan_for_targets():
	var mutants = get_tree().get_nodes_in_group("mutants")
	var best_target = null
	var best_score = -INF
	
	for mutant in mutants:
		if not is_instance_valid(mutant):
			continue
		
		var dist = global_position.distance_to(mutant.global_position)
		if dist > detection_radius * 1.5:
			continue
		
		var health_percent = 1.0
		if mutant.has_method("get_health_percent"):
			health_percent = mutant.get_health_percent()
		
		var score = 100.0 / (dist + 1.0) + (1.0 - health_percent) * 100.0
		
		if score > best_score:
			best_score = score
			best_target = mutant
	
	if best_target:
		current_target = best_target
		if state_machine:
			state_machine.set_state(GameEnums.StalkerState.ATTACK_MUTANT)
		print("MasterStalker: найдена цель для атаки - ", best_target.name)


func _check_attack(delta):
	if current_target and is_instance_valid(current_target) and attack_timer <= 0:
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= attack_range:
			if not _attack_hook(current_target):
				_attack_target(current_target)
	
	if attack_timer > 0:
		attack_timer -= delta


func _attack_target(target: Node):
	if not target.has_method("take_damage"):
		return
	
	if _combo_ready:
		_combo_ready = false
		target.take_damage(damage * 0.5, self)
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(target):
			target.take_damage(damage * 0.5, self)
		attack_timer = attack_cooldown
		attacked.emit(target)
		print("MasterStalker выполняет комбо на ", target.name)
		return
	
	if randf() < _combo_chance:
		_combo_ready = true
	
	var health_percent = 1.0
	if target.has_method("get_health_percent"):
		health_percent = target.get_health_percent()
	
	if health_percent < _execute_threshold:
		target.take_damage(damage * 2.0, self)
		attack_timer = attack_cooldown
		attacked.emit(target)
		print("MasterStalker добивает ", target.name)
		return
	
	target.take_damage(damage, self)
	attack_timer = attack_cooldown
	attacked.emit(target)
	print("MasterStalker атакует ", target.name)


func _on_threat_detected(threat: Node, type: String):
	super._on_threat_detected(threat, type)