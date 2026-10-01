# entities/stalkers/veteran_stalker.gd
extends BaseStalker
class_name VeteranStalker

## Ветеран - опытный сталкер с храбрым поведением

var _monolith_check_timer: float = 0.0
var _nav_check_timer: float = 0.0
var _original_speed: float
var _charge_chance: float = 0.15
var _confidence_range: float = 15.0

# ВЫСОТА СТАЛКЕРА НАД ЗЕМЛЁЙ - origin тела на земле Y=0
# (капсула высотой 1.8 со смещением -0.9 в base_stalker.tscn)
const STALKER_HEIGHT: float = 1.8


func _ready():
	stalker_type = GameEnums.StalkerType.VETERAN
	behavior_type = GameEnums.StalkerBehavior.BRAVE
	health = 150.0
	max_health = 150.0
	speed = 5.5
	damage = 15.0
	detection_radius = 25.0
	attack_range = 3.5
	attack_cooldown = 0.8
	biomass_return = 15.0
	armor = 5.0
	_original_speed = speed
	
	_init_components()
	
	monolith = get_tree().get_first_node_in_group("monolith")
	if monolith:
		print("VeteranStalker: Монолит НАЙДЕН на позиции ", monolith.global_position)
	else:
		print("VeteranStalker: ОШИБКА - Монолит НЕ НАЙДЕН!")
	
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
	
	print("VeteranStalker готов на позиции ", global_position)


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
		material.albedo_color = Color(0.2, 0.4, 1.0)
		material.metallic = 0.7
		material.roughness = 0.2
		visuals.material_override = material
	
	if label:
		label.text = "🔵 ВЕТЕРАН"
		label.modulate = Color(0.2, 0.4, 1.0)


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
			print("VeteranStalker: расстояние до монолита = ", dist)
	
	_update_speed_based_on_distance()
	
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
		print("VeteranStalker: провалился под землю, возвращён на пол Y=", pos.y)
	else:
		# Земли нет (чанк выгружен) - возвращаем к монолиту
		var mx = 10.0
		var mz = 10.0
		if monolith and is_instance_valid(monolith):
			mx = monolith.global_position.x + 10.0
			mz = monolith.global_position.z + 10.0
		global_position = Vector3(mx, STALKER_HEIGHT, mz)
		print("VeteranStalker: земли нет под сталкером, возвращён к монолиту")


func _update_speed_based_on_distance():
	if not state_machine or not navigation_component:
		return
	
	if state_machine.current_state == GameEnums.StalkerState.SEEK_MONOLITH and is_instance_valid(monolith):
		var dist = global_position.distance_to(monolith.global_position)
		if dist < _confidence_range:
			navigation_component.set_speed(_original_speed * 1.3)
		else:
			navigation_component.set_speed(_original_speed)


func _check_attack(delta):
	if current_target and is_instance_valid(current_target) and attack_timer <= 0:
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= attack_range:
			if randf() < _charge_chance and navigation_component and is_instance_valid(current_target):
				var dir = (current_target.global_position - global_position).normalized()
				var charge_pos = current_target.global_position + dir * 2.0
				navigation_component.move_to(charge_pos)
			
			if not _attack_hook(current_target):
				_attack_target(current_target)
	
	if attack_timer > 0:
		attack_timer -= delta


func _attack_target(target: Node):
	if target.has_method("take_damage"):
		target.take_damage(damage, self)
		attack_timer = attack_cooldown
		attacked.emit(target)
		print("VeteranStalker атакует ", target.name)


func _on_threat_detected(threat: Node, type: String):
	super._on_threat_detected(threat, type)