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
	health = max_health
	speed = 4.0
	damage = 8.0
	vision_range = 20.0
	
	_update_visual()
	_update_label()

	print("🌱 NoviceStalker: инициализирован")


func _update_visual():
	if not visual: return
	
	var material = StandardMaterial3D.new()
	material.albedo_color = novice_color
	material.emission_enabled = true
	material.emission = novice_color
	material.emission_energy_multiplier = 0.3
	
	for mesh in visual.find_children("*", "MeshInstance3D"):
		mesh.material_override = material


func _update_label():
	if label:
		label.text = "NOVICE"
		label.modulate = novice_color


func _physics_hook(delta):
	if not is_alive: return
	
	# Если здоровье низкое - убегаем
	if health < max_health * flee_threshold and not is_fleeing:
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
		if navigation_agent:
			navigation_agent.target_position = target_position
	
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
	if health < max_health * flee_threshold:
		is_fleeing = true
		search_timer = 0.0
		current_state = StalkerState.FLEE
