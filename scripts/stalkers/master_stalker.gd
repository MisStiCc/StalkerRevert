extends BaseStalker
class_name MasterStalker

## Master Stalker - самый сильный тип сталкера с уникальными способностями

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
var current_target_node: Node = null


func _ready_hook():
	stalker_type = "master"
	behavior = "aggressive"
	max_health = 250.0
	health = max_health
	speed = 6.0
	damage = 25.0
	vision_range = 30.0
	armor = 10.0
	
	_update_visual()
	_update_label()

	print("👑 MasterStalker: инициализирован")


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
		label.text = "MASTER"
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
	
	# Используем стандартную логику + атаку
	if current_state == StalkerState.SEEK_ARTIFACT or current_state == StalkerState.SEEK_MONOLITH:
		if current_target_node and is_instance_valid(current_target_node):
			var dist = global_position.distance_to(current_target_node.global_position)
			if dist < attack_range:
				_try_attack()
			elif dist < detection_range and ability_cooldown == 0:
				_try_special_ability()


func _try_attack():
	if attack_cooldown > 0: return
	attack_cooldown = 0.8
	
	if current_target_node and is_instance_valid(current_target_node):
		var final_damage = master_damage
		
		if randf() < critical_chance:
			final_damage *= 2.5
			print("Мастер нанес сокрушительный удар!")
		
		if current_target_node.has_method("take_damage"):
			current_target_node.take_damage(final_damage)


func _try_special_ability():
	ability_cooldown = 5.0
	print("Мастер использует способность!")
	
	# Создаёт временную аномалию
	var anomaly_scene = preload("res://scenes/zone/anomalies/gravity_vortex.tscn")
	if anomaly_scene:
		var anomaly = anomaly_scene.instantiate()
		anomaly.position = current_target_node.global_position + Vector3(0, 2, 0) if current_target_node else global_position
		get_tree().current_scene.add_child(anomaly)
		
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
