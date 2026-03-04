extends BaseMutant
class_name SnorkMutant

# Уникальные параметры снорка
@export var jump_force: float = 10.0
@export var jump_cooldown: float = 3.0
@export var jump_range: float = 8.0
@export var leap_damage_multiplier: float = 1.5  # Урон в прыжке увеличен

var can_jump: bool = true
var is_jumping: bool = false
var jump_target: Vector3
var jump_timer: Timer


func _ready():
	# Установка параметров ДО вызова super._ready()
	health = 120.0
	max_health = 120.0
	speed = 6.0
	damage = 30.0
	armor = 5.0
	biomass_cost = 60.0
	mutant_type = "snork"
	
	# Вызываем базовый _ready
	super._ready()
	
	# Настройка таймера прыжка
	jump_timer = Timer.new()
	jump_timer.one_shot = true
	jump_timer.timeout.connect(_on_jump_cooldown_ended)
	add_child(jump_timer)
	
	print("Snork mutant initialized: ", name)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if is_jumping:
		# Во время прыжка игнорируем обычное движение
		_handle_jump(delta)
		return
	
	super._physics_process(delta)


func _chase(delta):
	super._chase(delta)
	
	# Проверяем, можно ли прыгнуть на сталкера
	if can_jump and target_stalker and is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < jump_range and dist > 3.0:
			_try_jump_on_stalker()


func _try_jump_on_stalker():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	print("Snork: прыгаю на сталкера ", target_stalker.name)
	
	# Запоминаем позицию цели
	jump_target = target_stalker.global_position
	
	# Переключаемся в состояние прыжка
	is_jumping = true
	can_jump = false
	
	# Запускаем таймер перезарядки прыжка
	jump_timer.wait_time = jump_cooldown
	jump_timer.start()


func _handle_jump(delta):
	# Простая физика прыжка
	var direction = (jump_target - global_position).normalized()
	velocity = direction * jump_force
	
	# Добавляем вертикальную компоненту для "прыжка"
	velocity.y = jump_force * 0.5
	
	move_and_slide()
	
	# Проверяем, приземлились ли
	if global_position.distance_to(jump_target) < 2.0 or is_on_floor():
		_land_on_target()


func _land_on_target():
	print("Snork: приземлился!")
	
	is_jumping = false
	velocity = Vector3.ZERO
	
	# Наносим увеличенный урон цели, если она рядом
	if target_stalker and is_instance_valid(target_stalker):
		if global_position.distance_to(target_stalker.global_position) < 3.0:
			if target_stalker.has_method("take_damage"):
				target_stalker.take_damage(damage * leap_damage_multiplier)
				attacked_stalker.emit(target_stalker)
				print("Snork: нанёс урон в прыжке!")
	
	# Переходим в атаку, если цель рядом
	if target_stalker and is_instance_valid(target_stalker):
		if global_position.distance_to(target_stalker.global_position) < 2.0:
			current_state = State.ATTACK
		else:
			current_state = State.CHASE
	else:
		current_state = State.PATROL


func _on_jump_cooldown_ended():
	can_jump = true


func _attack(delta):
	# Снорки атакуют быстро и отпрыгивают
	super._attack(delta)
	
	# После атаки можем отпрыгнуть назад
	if current_state == State.ATTACK and target_stalker and is_instance_valid(target_stalker):
		if randf() < 0.3:  # 30% шанс отпрыгнуть после атаки
			_jump_away()


func _jump_away():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	# Прыгаем в сторону от цели
	var away_direction = (global_position - target_stalker.global_position).normalized()
	jump_target = global_position + away_direction * 5.0
	is_jumping = true
	can_jump = false
	
	jump_timer.wait_time = jump_cooldown
	jump_timer.start()