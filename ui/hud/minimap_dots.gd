# ui/hud/minimap_dots.gd
extends Control
class_name MinimapDots

## Слой живых объектов поверх SVG-карты: сталкеры, мутанты, монолит.
## Мировые координаты (XZ от монолита в центре) проецируются на квадрат карты.

# Метры от монолита до края карты (спавн-кольцо 90-150м + запас)
const WORLD_HALF: float = 160.0
# Перерисовка точек (чаще незачем, точки и так двигаются медленно)
const UPDATE_INTERVAL: float = 0.2

var _t: float = 0.0


func _process(delta):
	_t += delta
	if _t >= UPDATE_INTERVAL:
		_t = 0.0
		queue_redraw()


func world_to_map(world_pos: Vector3) -> Vector2:
	"""Мировая позиция -> пиксели карты (масштаб по текущему размеру контрола)"""
	var half = size / 2.0
	var p = Vector2(world_pos.x, world_pos.z) / WORLD_HALF * half + half
	return p.clamp(Vector2.ZERO, size)


func _draw():
	# Монолит - янтарная точка в центре
	draw_circle(size / 2.0, 3.0, Color(1.0, 0.75, 0.2))

	# Мутанты - зелёные точки
	for m in get_tree().get_nodes_in_group("mutants"):
		if not is_instance_valid(m):
			continue
		draw_circle(world_to_map(m.global_position), 2.5, Color(0.32, 1.0, 0.54))

	# Сталкеры - красные точки
	for s in get_tree().get_nodes_in_group("stalkers"):
		if not is_instance_valid(s):
			continue
		draw_circle(world_to_map(s.global_position), 3.5, Color(1.0, 0.27, 0.27))
