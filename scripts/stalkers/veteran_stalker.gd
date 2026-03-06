extends BaseStalker

# Дополнительные параметры
@export var detection_range: float = 25.0
@export var attack_range: float = 3.0
@export var critical_chance: float = 0.3
@export var veteran_color: Color = Color(0.2, 0.4, 1.0)
@export var veteran_damage: float = 15.0

# Специфичные для ветерана переменные
var attack_cooldown: float = 0.0

func _ready_hook():
	stalker_type = "veteran"
	max_health = 150.0
	health = max_health
	speed = 5.5
	
	_update_visual()
	_update_label()

func _update_visual():
	if not visual: return
	
	var material = StandardMaterial3D.new()
	material.albedo_color = veteran_color
	material.metallic = 0.7
	material.roughness = 0.2
	material.emission_enabled = true
	material.emission = veteran_color
	material.emission_energy_multiplier = 0.2
	
	for mesh in visual.find_children("*", "MeshInstance3D"):
		mesh.material_override = material

func _update_label():
	if label:
		label.text = "ВЕТЕРАН"
		label.modulate = veteran_color
		label.font_size = 48

func _physics_hook(delta):
	if not is_alive: return
	
	attack_cooldown = max(0, attack_cooldown - delta)
	
	if not target or not is_instance_valid(target):
		_find_best_target()
	
	if target and is_instance_valid(target):
		set_target(target.global_position)
		
		var dist = global_position.distance_to(target.global_position)
		if dist < attack_range:
			_try_attack()

func _find_best_target():
	var artifacts = get_tree().get_nodes_in_group("artifacts")
	var anomalies = get_tree().get_nodes_in_group("anomalies")
	
	var best_target = null
	var best_score = -INF
	
	for a in artifacts:
		if not is_instance_valid(a): continue
		var dist = global_position.distance_to(a.global_position)
		if dist > detection_range: continue
		
		var score = 1000 - dist
		if score > best_score:
			best_score = score
			best_target = a
	
	for a in anomalies:
		if not is_instance_valid(a): continue
		var dist = global_position.distance_to(a.global_position)
		if dist > detection_range: continue
		
		var score = 500 - dist
		if score > best_score:
			best_score = score
			best_target = a
	
	target = best_target

func _try_attack():
	if attack_cooldown > 0: return
	
	attack_cooldown = 1.0
	
	if target and is_instance_valid(target):
		var final_damage = veteran_damage
		
		if randf() < critical_chance:
			final_damage *= 2
			print("Ветеран нанес критический удар!")
		
		if target.has_method("take_damage"):
			target.take_damage(final_damage)
		elif target.has_method("collect"):
			target.collect(self)

func _damage_hook(amount: float):
	if target and target.has_method("get_owner"):
		var attacker = target.get_owner()
		if attacker and attacker != self:
			target = attacker

func _get_biomass_value() -> float:
	return 15.0