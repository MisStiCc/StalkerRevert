extends BaseStalker

## Novice Stalker - базовый тип сталкера для новичков

# Дополнительные параметры
@export var detection_range: float = 15.0
@export var flee_threshold: float = 0.3
@export var novice_color: Color = Color(0.2, 0.8, 0.2)

# Специфичные для новичка переменные
var is_fleeing: bool = false
var search_timer: float = 0.0


func _ready_hook():
	stalker_type = "novice"
	behavior = "greedy"
	max_health = 80.0
	if health_component:
		health_component.set_max_health(max_health)
		health_component.heal(max_health)
	speed = 4.0
	damage = 8.0
	vision_range = 20.0
	
	# Визуал через компонент или напрямую
	_update_visual()
	_update_label()

	print("🌱 NoviceStalker: инициализирован")


func _update_visual():
	# Пытаемся найти визуал через компонент или в себе
	var mesh_instance = find_child("*MeshInstance3D", true, false)
	if mesh_instance:
		var material = StandardMaterial3D.new()
		material.albedo_color = novice_color
		material.emission_enabled = true
		material.emission = novice_color
		material.emission_energy_multiplier = 0.3
		mesh_instance.material_override = material


func _update_label():
	# Пытаемся найти Label3D
	var label_node = find_child("*Label3D", true, false)
	if label_node and label_node is Label3D:
		label_node.text = "NOVICE"
		label_node.modulate = novice_color


func _physics_hook(delta):
	if not is_alive: return
	
	# Используем компонент health
	var current_health = max_health
	if health_component:
		current_health = health_component.get_health()
	
	# Если здоровье низкое - убегаем
	if current_health < max_health * flee_threshold and not is_fleeing:
		is_fleeing = true
		search_timer = 0.0

	if is_fleeing:
		_flee_logic(delta)
	elif current_state == StalkerState.SEEK_ARTIFACT:
		_check_for_danger()


func _flee_logic(delta):
	# Убегаем от опасности
	var danger_pos = _get_nearest_danger_position()
	if danger_pos != Vector3.ZERO:
		var flee_dir = (global_position - danger_pos).normalized()
		target_position = global_position + flee_dir * 20
		# Используем компонент navigation
		if navigation:
			navigation.set_target(target_position)
	
	search_timer += delta
	if search_timer > 3.0:
		is_fleeing = false
		search_timer = 0.0


func _get_nearest_danger_position() -> Vector3:
	var anomalies = get_tree().get_nodes_in_group("anomalies")
	var nearest_pos = Vector3.ZERO
	var min_dist = INF
	
	for a in anomalies:
		if not is_instance_valid(a): continue
		var dist = global_position.distance_to(a.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_pos = a.global_position
	
	return nearest_pos


func _check_for_danger():
	var anomalies = get_tree().get_nodes_in_group("anomalies")
	for a in anomalies:
		if not is_instance_valid(a): continue
		var dist = global_position.distance_to(a.global_position)
		if dist < 5.0:
			is_fleeing = true
			search_timer = 0.0
			current_state = StalkerState.FLEE
			return


func _damage_hook(amount: float):
	var current_health = max_health
	if health_component:
		current_health = health_component.get_health()
	
	if current_health < max_health * flee_threshold:
		is_fleeing = true
		search_timer = 0.0
		current_state = StalkerState.FLEE
