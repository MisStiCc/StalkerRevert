extends BaseStalker

## Veteran Stalker - более сильный и опытный сталкер

# Дополнительные параметры
@export var detection_range: float = 25.0
@export var attack_range: float = 3.0
@export var critical_chance: float = 0.3
@export var veteran_color: Color = Color(0.2, 0.4, 1.0)
@export var veteran_damage: float = 15.0

# Специфичные для ветерана переменные
var attack_cooldown: float = 0.0
var current_target_node: Node = null


func _ready_hook():
	stalker_type = "veteran"
	behavior = "brave"
	max_health = 150.0
	health = max_health
	speed = 5.5
	damage = 15.0
	vision_range = 25.0
	
	_update_visual()
	_update_label()

	print("🎖️ VeteranStalker: инициализирован")


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
		label.text = "VETERAN"
		label.modulate = veteran_color
		label.font_size = 48


func _physics_hook(delta):
	if not is_alive: return
	
	attack_cooldown = max(0, attack_cooldown - delta)
	
	# Используем стандартную логику из base, но добавляем атаку
	if current_state == StalkerState.SEEK_ARTIFACT or current_state == StalkerState.SEEK_MONOLITH:
		if current_target_node and is_instance_valid(current_target_node):
			var dist = global_position.distance_to(current_target_node.global_position)
			if dist < attack_range:
				_try_attack()


func _try_attack():
	if attack_cooldown > 0: return
	
	attack_cooldown = 1.0
	
	if current_target_node and is_instance_valid(current_target_node):
		var final_damage = veteran_damage
		
		if randf() < critical_chance:
			final_damage *= 2
			print("Ветеран нанес критический удар!")
		
		if current_target_node.has_method("take_damage"):
			current_target_node.take_damage(final_damage)