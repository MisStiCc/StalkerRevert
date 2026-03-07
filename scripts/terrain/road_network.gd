extends Node
class_name RoadNetwork

## Генерация дорожной сети
## Создаёт дороги между точками интереса

var road_points: Array[Vector3] = []
var road_segments: Array = []  # [start, end, width]

# Параметры
@export var road_width: float = 4.0
@export var min_road_length: float = 20.0
@export var max_road_length: float = 100.0

# Связанные объекты (деревни, аномалии, монолит)
var waypoints: Array[Vector3] = []


func _ready():
	add_to_group("road_network")


func add_waypoint(pos: Vector3):
	"""Добавить точку для соединения дорогами"""
	if not pos in waypoints:
		waypoints.append(pos)


func generate_roads():
	"""Сгенерировать дорожную сеть между точками"""
	road_points.clear()
	road_segments.clear()
	
	if waypoints.size() < 2:
		return
	
	# Сортируем точки (сначала монолит)
	waypoints.sort_custom(func(a, b):
		# Монолит всегда первый
		var a_is_monolith = a.distance_to(Vector3.ZERO) < 10
		var b_is_monolith = b.distance_to(Vector3.ZERO) < 10
		if a_is_monolith and not b_is_monolith:
			return true
		return a.distance_to(Vector3.ZERO) < b.distance_to(Vector3.ZERO)
	)
	
	# Создаём дороги
	for i in range(waypoints.size() - 1):
		var start = waypoints[i]
		var end = waypoints[i + 1]
		
		# Проверяем длину
		var dist = start.distance_to(end)
		if dist >= min_road_length and dist <= max_road_length:
			_add_road_segment(start, end)
	
	# Соединяем кольцом
	if waypoints.size() > 2:
		var last = waypoints.back()
		var first = waypoints.front()
		var dist = last.distance_to(first)
		if dist >= min_road_length and dist <= max_road_length:
			_add_road_segment(last, first)


func _add_road_segment(start: Vector3, end: Vector3):
	road_segments.append([start, end, road_width])
	
	# Добавляем промежуточные точки
	var dist = start.distance_to(end)
	var steps = int(dist / 10.0)
	
	for i in range(steps + 1):
		var t = float(i) / steps
		var point = start.lerp(end, t)
		road_points.append(point)


func get_nearest_road_point(pos: Vector3) -> Vector3:
	"""Получить ближайшую точку дороги"""
	if road_points.is_empty():
		return pos
	
	var nearest = road_points[0]
	var min_dist = pos.distance_to(nearest)
	
	for point in road_points:
		var dist = pos.distance_to(point)
		if dist < min_dist:
			min_dist = dist
			nearest = point
	
	return nearest


func is_near_road(pos: Vector3, threshold: float = 5.0) -> bool:
	"""Проверить рядом ли дорога"""
	for segment in road_segments:
		var start = segment[0]
		var end = segment[1]
		var width = segment[2]
		
		# Расстояние до отрезка
		var nearest = _closest_point_on_segment(pos, start, end)
		if pos.distance_to(nearest) < width + threshold:
			return true
	
	return false


func _closest_point_on_segment(point: Vector3, start: Vector3, end: Vector3) -> Vector3:
	var dir = (end - start).normalized()
	var length = start.distance_to(end)
	var to_point = point - start
	var projection = to_point.dot(dir)
	projection = clamp(projection, 0, length)
	return start + dir * projection


func get_road_color() -> Color:
	return Color(0.5, 0.45, 0.4)


func clear():
	road_points.clear()
	road_segments.clear()
	waypoints.clear()
