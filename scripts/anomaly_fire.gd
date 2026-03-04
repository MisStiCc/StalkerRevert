class_name AnomalyFire
extends Area3D

## Аномалия "Жарка" - наносит урон огнем сталкерам в зоне действия

# Экспортируемые параметры
@export var damage_per_second: float = 10.0
@export var energy_cost_per_second: float = 2.0
@export var anomaly_name: String = "Жарка"
@export var color: Color = Color(1.0, 0.5, 0.0, 1.0)  # оранжево-красный

# Сигналы
signal stalker_entered(stalker)
signal stalker_exited(stalker)
signal energy_consumed(amount)

# Внутренние переменные
var active: bool = true
var stalkers_in_zone: Array = []
var damage_timer: float = 0.0

func _ready() -> void:
    """Инициализация аномалии"""
    # Подключаем обработчики сигналов
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    
    # Настраиваем визуальное представление
    _setup_visuals()
    
    print("Аномалия '", anomaly_name, "' создана")

func _setup_visuals() -> void:
    """Настройка визуального представления аномалии"""
    # Ищем Sprite3D и устанавливаем цвет
    var sprite = $Sprite3D
    if sprite:
        sprite.modulate = color
    
    # Настраиваем радиус коллизии
    var collision_shape = $CollisionShape3D
    if collision_shape:
        var sphere_shape = collision_shape.shape as SphereShape3D
        if sphere_shape:
            sphere_shape.radius = 2.0  # стандартный радиус

func _process(delta: float) -> void:
    """Основной цикл обновления"""
    if not active:
        return
    
    # Обновляем таймер урона
    damage_timer += delta
    
    # Наносим урон каждую секунду
    if damage_timer >= 1.0:
        damage_timer = 0.0
        _apply_damage()

func _on_body_entered(body: Node) -> void:
    """Обработчик входа тела в зону"""
    if body is Stalker:
        stalkers_in_zone.append(body)
        stalker_entered.emit(body)
        print("Сталкер вошел в зону аномалии: ", body.name)

func _on_body_exited(body: Node) -> void:
    """Обработчик выхода тела из зоны"""
    if body is Stalker:
        var index = stalkers_in_zone.find(body)
        if index != -1:
            stalkers_in_zone.remove_at(index)
            stalker_exited.emit(body)
            print("Сталкер вышел из зоны аномалии: ", body.name)

func _apply_damage() -> void:
    """Применение урона всем сталкерам в зоне"""
    if not active or stalkers_in_zone.is_empty():
        return
    
    # Наносим урон каждому сталкеру
    for stalker in stalkers_in_zone:
        if is_instance_valid(stalker) and stalker.has_method("take_damage"):
            stalker.take_damage(damage_per_second, "fire")
            print("Аномалия '", anomaly_name, "' нанесла ", damage_per_second, " урона сталкеру ", stalker.name)
    
    # Потребляем энергию и эмитируем сигнал
    energy_consumed.emit(energy_cost_per_second)
    print("Аномалия '", anomaly_name, "' потребила ", energy_cost_per_second, " энергии")

func activate() -> void:
    """Активация аномалии"""
    active = true
    print("Аномалия '", anomaly_name, "' активирована")

func deactivate() -> void:
    """Деактивация аномалии"""
    active = false
    stalkers_in_zone.clear()
    print("Аномалия '", anomaly_name, "' деактивирована")