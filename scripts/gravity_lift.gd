extends BaseAnomaly

## Гравитационная аномалия "Лифт"
## Безвредная аномалия, которая подбрасывает сталкеров вверх
## Можно использовать для прыжков на большую высоту

@export var lift_force: float = 30.0  # Сила подъёма
@export var lift_radius: float = 4.0  # Радиус действия
@export var lift_duration: float = 3.0  # Длительность подъёма

var lift_timer: float = 0.0

func _ready():
	anomaly_name = "Гравитационный Лифт"
	damage_per_second = 0.0  # Безвредная аномалия
	radius = lift_radius
	color = Color(0.5, 0.8, 1.0, 0.4)  # Полупрозрачный голубой
	
	super._ready()

func _process(delta):
	if not is_active:
		return
	
	# Подъём сталкеров
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			var direction = Vector3.UP
			var distance = stalker.get_global_position().distance_to(get_global_position())
			
			if distance < radius:
				# Применяем подъёмную силу
				stalker.apply_gravity_force(direction * lift_force * delta)
				
				# Ограничиваем высоту подъёма
				if stalker.get_global_position().y > get_global_position().y + lift_duration:
					# Замедляем подъём перед верхней границей
					var height_diff = stalker.get_global_position().y - (get_global_position().y + lift_duration)
					stalker.apply_gravity_force(direction * -lift_force * 0.5 * delta)

func _apply_damage():
	# GravityLift безвредная - не наносит урон
	pass

func _update_visuals():
	# Визуальное обновление будет реализовано в дочерних сценах
	pass
