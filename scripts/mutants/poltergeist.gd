extends BaseMutant
class_name PoltergeistMutant

## Полтергейст - летающее существо с телекинезом
## Может становиться невидимым и бросать предметы в сталкеров

@export var flight_height: float = 5.0  # Высота полёта
@export var telekinesis_range: float = 20.0  # Дистанция телекинеза
@export var throw_damage: float = 30.0  # Урон от брошенных предметов
@export var invisibility_threshold: float = 0.3  # Шанс невидимости при атаке

var is_flying: bool = true
var can_telekinesis: bool = true
var telekinesis_timer: Timer
var is_invisible: bool = false
var float_offset: float = 0.0  # Для анимации парения

func _ready():
	# Полтергейст - уникальный летающий мутант
	health = 60.0  # Хрупкий
	max_health = 60.0
	speed = 6.0  # Быстрый
	damage = 0.0  # Не наносит прямой урон (через телекинез)
	armor = 0.0  # Без брони
	biomass_cost = 120.0
	detection_radius = 25.0
	mutant_type = "poltergeist"
	
	super._ready()
	
	# Таймер телекинеза
	telekinesis_timer = Timer.new()
	telekinesis_timer.one_shot = true
	telekinesis_timer.wait_time = 3.0
	telekinesis_timer.timeout.connect(_on_telekinesis_cooldown_ended)
	add_child(telekinesis_timer)
	
	# Начинаем летать
	current_state = State.PATROL
	
	print("Poltergeist mutant initialized")


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	# Парим в воздухе
	_float(delta)
	
	# Пытаемся стать невидимым при атаке
	if current_state == State.CHASE and randf() < 0.01:
		_try_become_invisible()
	
	# Обновляем видимость
	_update_invisibility()
	
	super._physics_process(delta)


func _float(delta):
	"""Анимация парения"""
	float_offset += delta * 2.0
	var hover_y = sin(float_offset) * 0.5
	
	# Поддерживаем высоту
	if global_position.y < flight_height:
		velocity.y = 2.0
	elif global_position.y > flight_height + 1:
		velocity.y = -2.0
	else:
		velocity.y = hover_y


func _patrol(delta):
	"""Патрулирование - летаем и ищем сталкеров"""
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	var nearest_stalker = null
	var nearest_dist = INF
	
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < detection_radius and dist < nearest_dist:
				nearest_dist = dist
				nearest_stalker = stalker
	
	if nearest_stalker:
		target_stalker = nearest_stalker
		current_state = State.CHASE
	
	# Летаем вокруг
	_fly_in_patrol(delta)


func _fly_in_patrol(delta):
	"""Полёт по патрульному маршруту"""
	# Просто летаем кругами
	var time = Time.get_ticks_msec() * 0.001
	var radius = 10.0
	
	var target_x = cos(time * 0.5) * radius
	var target_z = sin(time * 0.5) * radius
	
	var direction = (Vector3(target_x, flight_height, target_z) - global_position).normalized()
	velocity.x = direction.x * speed * 0.5
	velocity.z = direction.z * speed * 0.5


func _chase(delta):
	"""Преследование - атакуем телекинезом"""
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	# Держим дистанцию
	var dist = global_position.distance_to(target_stalker.global_position)
	
	if dist < telekinesis_range:
		# Достаточно близко для телекинеза
		_try_telekinesis_attack()
		
		# Держимся на расстоянии
		var retreat_direction = (global_position - target_stalker.global_position).normalized()
		velocity.x = retreat_direction.x * speed
		velocity.z = retreat_direction.z * speed
	else:
		# Нужно приблизиться
		var direction = (target_stalker.global_position - global_position).normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed


func _try_telekinesis_attack():
	"""Попытка атаки телекинезом"""
	if not can_telekinesis:
		return
	
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	print("Poltergeist: атакую телекинезом!")
	can_telekinesis = false
	
	# Бросаем предмет (визуальный эффект)
	_throw_object(target_stalker.global_position)
	
	# Наносим урон
	if target_stalker.has_method("take_damage"):
		target_stalker.take_damage(throw_damage)
		attacked_stalker.emit(target_stalker)
	
	# Запускаем кулдаун
	telekinesis_timer.start()


func _throw_object(target_pos: Vector3):
	"""Бросаем предмет в цель"""
	# Создаём визуальный эффект "предмета"
	var projectile = MeshInstance3D.new()
	projectile.mesh = SphereMesh.new()
	projectile.mesh.radius = 0.3
	projectile.mesh.height = 0.6
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.5, 0.5)
	material.emission = Color(0.3, 0.3, 0.3)
	material.emission_energy = 1.0
	projectile.material_override = material
	
	projectile.global_position = global_position
	get_tree().current_scene.add_child(projectile)
	
	# Анимация полёта
	var direction = (target_pos - global_position).normalized()
	var tween = create_tween()
	tween.tween_property(projectile, "global_position", target_pos, 0.5)
	
	# Удаляем после попадания
	await tween.finished
	if is_instance_valid(projectile):
		projectile.queue_free()


func _on_telekinesis_cooldown_ended():
	can_telekinesis = true


func _try_become_invisible():
	"""Попытка стать невидимым"""
	if not is_invisible and randf() < invisibility_threshold:
		is_invisible = true


func _update_invisibility():
	"""Обновление видимости"""
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = not is_invisible


func take_damage(dmg: float):
	# Полтергейст получает увеличенный урон (хрупкий)
	# Но имеет шанс уклониться
	if randf() < 0.3:
		print("Poltergeist: уклонился от атаки!")
		return
	
	super.take_damage(dmg * 1.5)
	
	# При получении урона становимся видимым
	is_invisible = false


func die():
	is_invisible = false
	super.die()
