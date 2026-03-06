extends BaseStalker  # Теперь работает, потому что есть class_name!

# Дополнительные параметры
@export var detection_range: float = 15.0
@export var flee_threshold: float = 0.3
@export var novice_color: Color = Color(0.2, 0.8, 0.2)

# Специфичные для новичка переменные
var is_fleeing: bool = false
var search_timer: float = 0.0

func _ready_hook():
	stalker_type = "novice"
	max_health = 80.0
	health = max_health
	speed = 4.0
	
	_update_visual()
	_update_label()

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
		label.text = "НОВИЧОК"
		label.modulate = novice_color

func _physics_hook(delta):
	if not is_alive: return
	
	if is_fleeing:
		_flee_logic(delta)
	else:
		_search_logic(delta)

func _search_logic(delta):
	if not target or not is_instance_valid(target):
		_find_nearest_artifact()
	
	if target and is_instance_valid(target):
		set_target(target.global_position)
		
		var dist = global_position.distance_to(target.global_position)
		if dist < 2.0 and target.has_method("collect"):
			target.collect(self)
			target = null
	
	_check_for_danger()

func _flee_logic(delta):
	var danger_pos = _get_nearest_danger_position()
	if danger_pos != Vector3.ZERO:
		var flee_dir = (global_position - danger_pos).normalized()
		set_target(global_position + flee_dir * 20)
	
	search_timer += delta
	if search_timer > 3.0:
		is_fleeing = false
		search_timer = 0.0

func _find_nearest_artifact():
	var artifacts = get_tree().get_nodes_in_group("artifacts")
	var nearest = null
	var min_dist = INF
	
	for a in artifacts:
		if not is_instance_valid(a): continue
		var dist = global_position.distance_to(a.global_position)
		if dist < min_dist and dist < detection_range:
			min_dist = dist
			nearest = a
	
	target = nearest

func _check_for_danger():
	var anomalies = get_tree().get_nodes_in_group("anomalies")
	for a in anomalies:
		if not is_instance_valid(a): continue
		var dist = global_position.distance_to(a.global_position)
		if dist < 5.0:
			is_fleeing = true
			search_timer = 0.0
			return

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

func _damage_hook(amount: float):
	if health < max_health * flee_threshold:
		is_fleeing = true
		search_timer = 0.0

func _get_biomass_value() -> float:
	return 8.0
