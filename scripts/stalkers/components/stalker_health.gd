extends Node
class_name StalkerHealth

## Управление здоровьем сталкера
## Регенерация, получение урона, смерть

signal health_changed(current: float, max_health: float)
signal died
signal damaged(amount: float, source: Node)

var owner_stalker: CharacterBody3D

# Параметры здоровья
var max_health: float = 80.0
var current_health: float = 80.0
var armor: float = 0.0
var is_alive: bool = true

# Регенерация
var regen_rate: float = 0.0  # ХП в секунду
var regen_delay: float = 5.0  # Задержка перед регенерацией
var time_since_damage: float = 0.0

# Состояние
var is_invulnerable: bool = false
var invulnerability_time: float = 0.0


func _init(stalker: CharacterBody3D):
	owner_stalker = stalker


func _ready():
	# Загружаем параметры из сталкера
	if owner_stalker.has_property("max_health"):
		max_health = owner_stalker.max_health
	if owner_stalker.has_property("armor"):
		armor = owner_stalker.armor
	
	current_health = max_health


func _physics_process(delta: float):
	if not is_alive:
		return
	
	# Обработка неуязвимости
	if is_invulnerable:
		invulnerability_time -= delta
		if invulnerability_time <= 0:
			is_invulnerable = false
			invulnerability_time = 0.0
	
	# Регенерация здоровья
	_update_regeneration(delta)


func _update_regeneration(delta: float):
	if regen_rate <= 0:
		return
	
	time_since_damage += delta
	
	if time_since_damage >= regen_delay:
		var heal = regen_rate * delta
		heal = min(heal, max_health - current_health)
		if heal > 0:
			current_health += heal
			health_changed.emit(current_health, max_health)


# ==================== ПУБЛИЧНОЕ API ====================

func take_damage(amount: float, source: Node = null) -> float:
	"""Нанести урон сталкеру. Возвращает фактический урон"""
	if not is_alive or is_invulnerable:
		return 0.0
	
	# Сброс регенерации
	time_since_damage = 0.0
	
	# Расчёт фактического урона
	var actual_damage = max(1.0, amount - armor)
	current_health -= actual_damage
	
	# Сигнал
	damaged.emit(actual_damage, source)
	health_changed.emit(current_health, max_health)
	
	# Проверка на смерть
	if current_health <= 0:
		die()
	
	return actual_damage


func heal(amount: float) -> float:
	"""Лечение сталкера. Возвращает фактическое количество"""
	if not is_alive:
		return 0.0
	
	var actual_heal = min(amount, max_health - current_health)
	current_health += actual_heal
	health_changed.emit(current_health, max_health)
	
	return actual_heal


func die():
	"""Убить сталкера"""
	if not is_alive:
		return
	
	is_alive = false
	current_health = 0.0
	health_changed.emit(0.0, max_health)
	died.emit()
	
	# Вызываем метод смерти на сталкере
	if owner_stalker.has_method("die"):
		owner_stalker.die()


func set_max_health(value: float):
	max_health = max(1.0, value)
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)


func set_armor(value: float):
	armor = max(0.0, value)


func set_regen_rate(rate: float):
	regen_rate = max(0.0, rate)


func set_regen_delay(delay: float):
	regen_delay = max(0.0, delay)


func set_invulnerable(duration: float):
	is_invulnerable = true
	invulnerability_time = duration


func get_health() -> float:
	return current_health


func get_max_health() -> float:
	return max_health


func get_health_percent() -> float:
	return current_health / max_health if max_health > 0 else 0.0


func get_damage() -> float:
	"""Получить урон сталкера"""
	if owner_stalker.has_property("damage"):
		return owner_stalker.damage
	return 10.0


func is_healthy() -> bool:
	return get_health_percent() > 0.5


func is_critical() -> bool:
	return get_health_percent() < 0.25


func is_full_health() -> bool:
	return current_health >= max_health
