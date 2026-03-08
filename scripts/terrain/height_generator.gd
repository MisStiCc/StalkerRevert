extends Node
class_name HeightGenerator

## Генерация высот ландшафта
## Использует шумы для создания рельефа

var noise: FastNoiseLite

# Параметры
@export var height_scale: float = 10.0
@export var noise_scale: float = 0.02
@export var octaves: int = 6
@export var fractal_gain: float = 0.5


func _init():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_scale
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_gain = fractal_gain


func set_seed(seed_val: int):
	noise.seed = seed_val


func get_height(x: float, z: float) -> float:
	"""Получить высоту в точке (x, z)"""
	var height = noise.get_noise_2d(x, z) * height_scale
	height += noise.get_noise_2d(x * 2, z * 2) * (height_scale * 0.3)
	height += noise.get_noise_2d(x * 4, z * 4) * (height_scale * 0.1)
	height = clamp(height, -height_scale * 0.5, height_scale)
	return height


func get_height_with_offset(x: float, z: float, offset: float, scale: float) -> float:
	"""Получить высоту с вариацией"""
	var old_freq = noise.frequency
	noise.frequency = scale
	var h = get_height(x + offset, z + offset)
	noise.frequency = old_freq
	return h


func get_height_derivative(x: float, z: float, step: float = 0.1) -> Vector2:
	"""Получить производную (наклон) в точке"""
	var hx = get_height(x + step, z) - get_height(x - step, z)
	var hz = get_height(x, z + step) - get_height(x, z - step)
	return Vector2(hx, hz) / (2.0 * step)


func get_slope(x: float, z: float) -> float:
	"""Получить крутизну склона (0-1)"""
	var deriv = get_height_derivative(x, z)
	return min(deriv.length(), 1.0)


func is_steep(x: float, z: float, threshold: float = 0.5) -> bool:
	"""Проверить является ли место крутым"""
	return get_slope(x, z) > threshold
