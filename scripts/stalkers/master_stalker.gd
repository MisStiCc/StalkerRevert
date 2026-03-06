extends BaseStalker
class_name MasterStalker

# Дополнительные параметры
@export var detection_range: float = 30.0
@export var attack_range: float = 4.0
@export var critical_chance: float = 0.5
@export var master_color: Color = Color(0.8, 0.2, 0.8)  # Фиолетовый
@export var master_damage: float = 25.0
@export var regeneration_rate: float = 2.0  # здоровья в секунду

# Специфичные переменные
var attack_cooldown: float = 0.0
var ability_cooldown: float = 0.0
var regeneration_timer: float = 0.0

func _ready_hook():
	stalker_type = "master"
	max_health = 250.0
	health = max_health
	speed = 6.0
	# armor есть в BaseStalker? Если нет, используем переменную напрямую
	# или добавляем @export var armor в BaseStalker
	
	_update_visual()
	_update_label()

func _update_visual():
	if not visual: return
	
	# Фиолетовый цвет с пульсацией
	var material = StandardMaterial3D.new()
	material.albedo_color = master_color
	material.metallic = 0.8
	material.roughness = 0.1
	material.emission_enabled = true
	material.emission = master_color
	material.emission_energy_multiplier = 0.5
	
	for mesh in visual.find_children("*", "MeshInstance3D"):
		mesh.material_override = material

func _update_label():
	if label:
		label.text = "МАСТЕР"
		label.modulate = master_color
		label.font_size = 56
		label.outline_size = 3

func _physics_hook(delta):
	if not is_alive: return
	
	# Регенерация
	regeneration_timer += delta
	while regeneration_timer >= 1.0:
		regeneration_timer -= 1.0
		health = min(health + regeneration_rate, max_health)
		health_changed.emit(health, max_health)
	
	attack_cooldown = max(0, attack_cooldown - delta)
	ability_cooldown = max(0, ability_cooldown - delta)
	
	if not target or not is_instance_valid(target):
		_find_best_target()
	
	if target and is_instance_valid(target):
		set_target(target.global_position)
		
		var dist = global_position.distance_to(target.global_position)
		if dist < attack_range:
			_try_attack()
		elif dist < detection_range and ability_cooldown == 0:
			_try_special_ability()

func _find_best_target():
	var artifacts = get_tree().get_nodes_in_group("artifacts")
	var anomalies = get_tree().get_nodes_in_group("anomalies")
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	
	var best_target = null
	var best_score = -INF
	
	# Артефакты — высший приоритет
	for a in artifacts:
		if not is_instance_valid(a): continue
		var dist = global_position.distance_to(a.global_position)
		if dist > detection_range: continue
		var score = 2000 - dist
		if score > best_score:
			best_score = score
			best_target = a
	
	# Аномалии — средний приоритет
	for a in anomalies:
		if not is_instance_valid(a): continue
		var dist = global_position.distance_to(a.global_position)
		if dist > detection_range: continue
		var score = 1000 - dist
		if score > best_score:
			best_score = score
			best_target = a
	
	# Враги (другие сталкеры) — низкий приоритет
	for s in stalkers:
		if s == self: continue
		if not is_instance_valid(s): continue
		var dist = global_position.distance_to(s.global_position)
		if dist > detection_range: continue
		var score = 500 - dist
		if score > best_score:
			best_score = score
			best_target = s
	
	target = best_target

func _try_attack():
	if attack_cooldown > 0: return
	attack_cooldown = 0.8
	
	if target and is_instance_valid(target):
		var final_damage = master_damage
		
		if randf() < critical_chance:
			final_damage *= 2.5
			print("Мастер нанес сокрушительный удар!")
		
		if target.has_method("take_damage"):
			target.take_damage(final_damage)
		elif target.has_method("collect"):
			target.collect(self)

func _try_special_ability():
	ability_cooldown = 5.0
	print("Мастер использует способность!")
	
	# Создаёт временную аномалию
	var anomaly_scene = preload("res://scenes/zone/anomalies/gravity_vortex.tscn")
	var anomaly = anomaly_scene.instantiate()
	anomaly.position = target.global_position + Vector3(0, 2, 0)
	get_parent().add_child(anomaly)
	
	# Временное ускорение
	var original_speed = speed
	speed = speed * 1.5
	await get_tree().create_timer(3.0).timeout
	speed = original_speed

func _damage_hook(amount: float):
	# Мастер телепортируется при сильном уроне
	if amount > 20 and ability_cooldown == 0:
		ability_cooldown = 8.0
		_teleport()

func _teleport():
	var teleport_pos = global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
	global_position = teleport_pos
	print("Мастер телепортировался!")

func _get_biomass_value() -> float:
	return 30.0