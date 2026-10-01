# entities/stalkers/novice_stalker.gd
extends BaseStalker
class_name NoviceStalker

## Новичок - базовый сталкер с жадным поведением

var _monolith_check_timer: float = 0.0
var _nav_check_timer: float = 0.0

# ВЫСОТА СТАЛКЕРА НАД ЗЕМЛЁЙ - origin тела на земле Y=0
# (капсула высотой 1.8 со смещением -0.9 в base_stalker.tscn)
const STALKER_HEIGHT: float = 1.8


func _ready():
	# Устанавливаем параметры
	stalker_type = GameEnums.StalkerType.NOVICE
	behavior_type = GameEnums.StalkerBehavior.GREEDY
	health = 80.0
	max_health = 80.0
	speed = 2.8
	damage = 8.0
	detection_radius = 20.0
	attack_range = 3.0
	attack_cooldown = 1.0
	biomass_return = 16.0
	armor = 0.0
	
	# Инициализация компонентов
	_init_components()
	
	# Поиск монолита
	monolith = get_tree().get_first_node_in_group("monolith")
	if monolith:
		print("NoviceStalker: Монолит НАЙДЕН на позиции ", monolith.global_position)
	else:
		print("NoviceStalker: ОШИБКА - Монолит НЕ НАЙДЕН в группе 'monolith'!")
	
	# Настройка StateMachine с зависимостями
	if state_machine:
		state_machine.setup({
			"behavior": behavior_strategy,
			"navigation": navigation_component,
			"memory": memory_component,
			"carry": carry_component,
			"health": health_component,
			"monolith": monolith
		})
	
	# Настройка визуала
	_setup_visuals()
	
	super._ready()
	
	# Высоту задаёт спавн по лучу (рельеф) и физика: фиксированный Y=1.8
	# на холмах закапывал тело в рельеф, и оно проваливалось насквозь
	
	print("NoviceStalker готов на позиции ", global_position)


func _init_components():
	# HealthComponent
	health_component = HealthComponent.new()
	health_component.entity = self
	health_component.max_health = max_health
	health_component.armor = armor
	health_component.current_health = health
	add_child(health_component)
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	
	# NavigationComponent
	navigation_component = NavigationComponent.new()
	navigation_component.entity = self
	if has_node("NavigationAgent3D"):
		navigation_component.nav_agent = $NavigationAgent3D
	navigation_component.move_speed = speed
	navigation_component.enable_debug(false)  # Отключаем отладку для чистоты
	add_child(navigation_component)
	
	# MemoryComponent
	memory_component = MemoryComponent.new()
	memory_component.stalker = self
	memory_component.vision_range = detection_radius
	add_child(memory_component)
	memory_component.threat_detected.connect(_on_threat_detected)
	memory_component.threat_lost.connect(_on_threat_lost)
	memory_component.artifact_detected.connect(_on_artifact_detected)
	
	# CarryComponent
	carry_component = CarryComponent.new()
	carry_component.stalker = self
	add_child(carry_component)
	carry_component.artifact_picked_up.connect(_on_artifact_picked_up)
	carry_component.artifact_dropped.connect(_on_artifact_dropped)
	carry_component.artifact_stolen.connect(_on_artifact_stolen)
	
	# Behavior Strategy
	behavior_strategy = StalkerBehaviorStrategy.create(behavior_type, self)
	
	# StateMachine
	state_machine = StateMachineComponent.new()
	state_machine.stalker = self
	add_child(state_machine)


func _setup_visuals():
	if visuals:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.8, 0.2)
		visuals.material_override = material
	
	if label:
		label.text = "🟢 НОВИЧОК"
		label.modulate = Color(0.2, 0.8, 0.2)


func _physics_hook(delta):
	# Проверяем высоту каждые 2 секунды
	_nav_check_timer += delta
	if _nav_check_timer > 2.0:
		_nav_check_timer = 0.0
		_check_height()
	
	# Проверяем монолит для отладки
	_monolith_check_timer += delta
	if _monolith_check_timer > 5.0:
		_monolith_check_timer = 0.0
		if monolith and is_instance_valid(monolith):
			var dist = global_position.distance_to(monolith.global_position)
			print("NoviceStalker: расстояние до монолита = ", dist)
	
	# ГРАВИТАЦИЯ
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0:
			velocity.y = 0
	
	# Движение
	move_and_slide()
	
	# Проверка атаки
	_check_attack(delta)


func _check_height():
	"""Спасение на рельефе: сильно зарыт или завис над землёй - ставим на пол.
	На склоне origin законно отличается от нуля, фиксированная Y больше не эталон."""
	var query = PhysicsRayQueryParameters3D.new()
	query.from = global_position + Vector3.UP * 3.0
	query.to = global_position + Vector3.DOWN * 12.0
	query.collision_mask = 1
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	
	if result and abs(global_position.y - (result.position.y + STALKER_HEIGHT)) <= 2.0:
		return  # Стоит на рельефе штатно
	
	velocity = Vector3.ZERO
	if result:
		global_position.y = result.position.y + STALKER_HEIGHT
		print("NoviceStalker: провалился под землю, возвращён на рельеф Y=", global_position.y)
	else:
		# Земли нет (чанк выгружен) - возвращаем к монолиту
		var mx = 10.0
		var mz = 10.0
		if monolith and is_instance_valid(monolith):
			mx = monolith.global_position.x + 10.0
			mz = monolith.global_position.z + 10.0
		global_position = Vector3(mx, STALKER_HEIGHT, mz)
		print("NoviceStalker: земли нет под сталкером, возвращён к монолиту")


func _check_attack(delta):
	if current_target and is_instance_valid(current_target) and attack_timer <= 0:
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= attack_range:
			if not _attack_hook(current_target):
				_attack_target(current_target)
	
	if attack_timer > 0:
		attack_timer -= delta


func _attack_target(target: Node):
	if target.has_method("take_damage"):
		target.take_damage(damage, self)
		attack_timer = attack_cooldown
		attacked.emit(target)
		print("NoviceStalker атакует ", target.name)


func _log_status():
	var state_name = "unknown"
	if state_machine:
		state_name = state_machine.get_state_name()
	
	var target_info = "нет цели"
	if current_target and is_instance_valid(current_target):
		target_info = "цель: " + current_target.name + " на дистанции " + str(global_position.distance_to(current_target.global_position))
	
	print("NoviceStalker: состояние=", state_name, ", ", target_info)
	
	if navigation_component:
		print("NoviceStalker: навигация active=", navigation_component.is_navigating(), 
			  " target=", navigation_component.target_position)
	
	if monolith and is_instance_valid(monolith):
		print("NoviceStalker: дистанция до монолита = ", global_position.distance_to(monolith.global_position))


func _on_threat_detected(threat: Node, type: String):
	super._on_threat_detected(threat, type)


func _on_artifact_detected(artifact: Node):
	super._on_artifact_detected(artifact)
