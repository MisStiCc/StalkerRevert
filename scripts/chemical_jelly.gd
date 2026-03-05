extends BaseAnomaly

## Холодец - светящееся зелёное желе
## Замедляет сталкеров при нахождении в зоне

@export var slow_factor: float = 0.3  # Коэффициент замедления (0.3 = 30% скорости)
@export var slow_duration: float = 3.0  # Длительность замедления в секундах

var slow_timers: Dictionary = {}  # Хранит время замедления для каждого сталкера

func _ready():
	anomaly_name = "Холодец"
	damage_per_second = 0.0  # Холодец не наносит урон напрямую
	color = Color(0, 1, 0, 1)  # Ярко-зелёный
	radius = 5.0  # Радиус 5 метров
	
	super._ready()
	_update_visuals()

func _on_body_entered(body: Node3D):
	"""Когда сталкер входит в зону"""
	if body.has_method("take_damage") and body.has_method("slow_down") and not body in stalkers_in_zone:
		stalkers_in_zone.append(body)
		stalker_entered.emit(body)
		
		# Применяем замедление
		if body.has_method("slow_down"):
			body.slow_down(slow_factor, slow_duration)
			slow_timers[body] = slow_duration

func _on_body_exited(body: Node3D):
	"""Когда сталкер выходит из зоны"""
	if body in stalkers_in_zone:
		stalkers_in_zone.erase(body)
		stalker_exited.emit(body)
		
		# Снимаем замедление
		if body.has_method("slow_down"):
			body.slow_down(1.0, 0.0)  # 1.0 = нормальная скорость, 0.0 = немедленно
			slow_timers.erase(body)

func _apply_damage():
	"""Холодец не наносит урон напрямую"""
	pass

func _update_visuals():
	"""Обновление визуального представления - светящееся желе"""
	# Создаём визуальный эффект для желе
	_create_jelly_visuals()

func _create_jelly_visuals():
	"""Создаёт визуальный эффект светящегося желе"""
	# Создаём коллайдер
	var collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = radius
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Создаём визуальный эффект - светящаяся сфера
	var visual = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	visual.mesh = sphere
	
	# Настраиваем материал для светящегося эффекта
	var material = StandardMaterial3D.new()
	material.emission = color
	material.emission_energy = 2.0
	material.transparency = 0.5  # Полупрозрачный
	visual.material_override = material
	
	# Добавляем эффект пульсации
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector3(1.1, 1.1, 1.1), 1.0)
	tween.tween_property(visual, "scale", Vector3(1.0, 1.0, 1.0), 1.0)
	tween.tween_property(visual, "scale", Vector3(1.05, 1.05, 1.05), 0.5)
	tween.tween_property(visual, "scale", Vector3(1.0, 1.0, 1.0), 0.5)
	
	# Добавляем вращение
	tween.tween_property(visual, "rotation_y", PI, 2.0)
	tween.tween_property(visual, "rotation_y", 0.0, 2.0)
	
	add_child(visual)
	
	# Добавляем свет
	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.0
	light.distance = radius * 2
	light.shadow_enabled = true
	add_child(light)
