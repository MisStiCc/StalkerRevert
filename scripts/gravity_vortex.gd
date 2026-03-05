extends BaseAnomaly

## Гравитационная аномалия "Воронка"
## Втягивает сталкеров в центр и наносит урон от сжатия

@export var pull_strength: float = 20.0  # Сила притяжения
@export var squeeze_damage: float = 15.0  # Урон от сжатия
@export var rotation_speed: float = 2.0  # Скорость вращения

var vortex_rotation: float = 0.0

func _ready():
	anomaly_name = "Гравитационная Воронка"
	damage_per_second = squeeze_damage
	radius = 12.0  # Среднее значение между 10-15 м
	color = Color(0.4, 0.0, 0.6, 0.8)  # Тёмно-фиолетовый
	
	super._ready()

func _process(delta):
	if not is_active:
		return
	
	# Вращение воронки
	vortex_rotation += rotation_speed * delta
	
	# Применение гравитации к сталкерам
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker) and stalker.has_method("apply_gravity_force"):
			var direction = (get_global_position() - stalker.get_global_position()).normalized()
			var distance = stalker.get_global_position().distance_to(get_global_position())
			
			if distance < radius:
				# Чем ближе к центру, тем сильнее притяжение
				var force = pull_strength * (1.0 - distance / radius)
				stalker.apply_gravity_force(direction * force * delta)
				
				# Вращение сталкера
				if stalker.has_method("apply_rotation"):
					stalker.apply_rotation(direction.cross(Vector3.UP) * rotation_speed * delta)

func _apply_damage():
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(squeeze_damage)
				energy_consumed.emit(squeeze_damage)

func _update_visuals():
	# Визуальное обновление будет реализовано в дочерних сценах
	pass
