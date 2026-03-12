# entities/stalkers/novice_stalker.gd
extends BaseStalker
class_name NoviceStalker

func _ready_hook():
	stalker_type = GameEnums.StalkerType.NOVICE
	behavior_type = GameEnums.StalkerBehavior.GREEDY
	
	# Параметры уже установлены в базовом классе, но можно переопределить
	max_health = 80.0
	move_speed = 4.0
	damage = 8.0
	vision_range = 20.0
	
	# Визуал
	if visuals:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.8, 0.2)
		visuals.material_override = material
	
	# Подпись уже настроена в базовом классе
	
	print("NoviceStalker инициализирован")


func _physics_hook(delta):
	# Новички часто оглядываются
	if randf() < 0.01 and current_state == GameEnums.StalkerState.PATROL:
		print("Новичок оглядывается по сторонам")