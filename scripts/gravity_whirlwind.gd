extends BaseAnomaly

## Гравитационная аномалия "Карусель"
## Поднимает сталкеров в воздух и вращает их, нанося урон от центробежной силы

@export var lift_force: float = 25.0  # Сила подъёма
@export var rotation_speed: float = 5.0  # Скорость вращения
@export var centrifugal_damage: float = 20.0  # Урон от центробежной силы
@export var whirlwind_radius: float = 9.0  # Радиус действия

var whirlwind_rotation: float = 0.0

func _ready():
	anomaly_name = "Гравитационная Карусель"
	damage_per_second = centrifugal_damage
	radius = whirlwind_radius
	color = Color(0.6, 0.7, 0.8, 0.7)  # Серо-голубой
	
	super._ready()

func _process(delta):
	if not is_active:
		return
	
	# Вращение карусели
	whirlwind_rotation += rotation_speed * delta
	
	# Подъём и вращение сталкеров
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			var distance = stalker.get_global_position().distance_to(get_global_position())
			
			if distance < radius:
				# Подъёмная сила
				var direction = Vector3.UP
				stalker.apply_gravity_force(direction * lift_force * delta)
				
				# Вращение сталкера вокруг вертикальной оси
				if stalker.has_method("apply_rotation"):
					stalker.apply_rotation(Vector3.UP * rotation_speed * delta)

func _apply_damage():
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(centrifugal_damage)
				energy_consumed.emit(centrifugal_damage)

func _update_visuals():
	# Визуальное обновление будет реализовано в дочерних сценах
	pass
