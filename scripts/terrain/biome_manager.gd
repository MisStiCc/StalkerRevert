extends Node
class_name BiomeManager

## Определение биомов/типов местности
## На основе высоты и шума

var terrain_noise: FastNoiseLite

enum TerrainType {
	PLAIN, FOREST, SWAMP, HILL, WATER, ROAD, VILLAGE, RUINS
}

# Параметры типов
var terrain_params: Dictionary = {}

# Высота воды
var water_level: float = 2.0


func _init():
	terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = randi() + 1000
	terrain_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	terrain_noise.frequency = 0.008
	
	_init_terrain_params()


func _init_terrain_params():
	terrain_params = {
		TerrainType.PLAIN: {
			"speed": 1.0, "danger": 1.0, "cover": 0.0,
			"color": Color(0.4, 0.6, 0.3)
		},
		TerrainType.FOREST: {
			"speed": 0.7, "danger": 0.7, "cover": 0.8,
			"color": Color(0.2, 0.4, 0.2)
		},
		TerrainType.SWAMP: {
			"speed": 0.4, "danger": 2.0, "cover": 0.3,
			"color": Color(0.3, 0.35, 0.25)
		},
		TerrainType.HILL: {
			"speed": 0.8, "danger": 1.2, "cover": 0.2,
			"color": Color(0.5, 0.45, 0.35)
		},
		TerrainType.WATER: {
			"speed": 0.1, "danger": 2.5, "cover": 0.0,
			"color": Color(0.2, 0.4, 0.6)
		},
		TerrainType.ROAD: {
			"speed": 1.3, "danger": 1.5, "cover": 0.0,
			"color": Color(0.5, 0.45, 0.4)
		},
		TerrainType.VILLAGE: {
			"speed": 0.9, "danger": 1.3, "cover": 0.5,
			"color": Color(0.45, 0.4, 0.35)
		},
		TerrainType.RUINS: {
			"speed": 0.6, "danger": 1.8, "cover": 0.6,
			"color": Color(0.4, 0.35, 0.3)
		}
	}


func set_seed(seed_val: int):
	terrain_noise.seed = seed_val + 1000


func get_terrain_type_at(x: float, z: float, height: float) -> TerrainType:
	"""Определить тип местности по координатам и высоте"""
	var terrain_n = terrain_noise.get_noise_2d(x, z)
	
	# Вода имеет приоритет
	if height < water_level:
		return TerrainType.WATER
	
	# Болото
	if terrain_n < -0.3 and height < 3.0:
		return TerrainType.SWAMP
	
	# Холмы
	if height > 6.0:
		return TerrainType.HILL
	
	# Дороги
	if terrain_n > 0.5:
		return TerrainType.ROAD
	
	# Леса
	if terrain_n > 0.1:
		return TerrainType.FOREST
	
	# Руины
	if terrain_n < -0.1 and terrain_n > -0.3:
		return TerrainType.RUINS
	
	# Деревни
	if terrain_n > -0.1 and terrain_n < 0.1:
		return TerrainType.VILLAGE
	
	# Равнина по умолчанию
	return TerrainType.PLAIN


func get_speed_multiplier(terrain_type: TerrainType) -> float:
	return terrain_params.get(terrain_type, {}).get("speed", 1.0)


func get_danger(terrain_type: TerrainType) -> float:
	return terrain_params.get(terrain_type, {}).get("danger", 1.0)


func get_cover(terrain_type: TerrainType) -> float:
	return terrain_params.get(terrain_type, {}).get("cover", 0.0)


func get_color(terrain_type: TerrainType) -> Color:
	return terrain_params.get(terrain_type, {}).get("color", Color.GREEN)


func get_terrain_name(terrain_type: TerrainType) -> String:
	match terrain_type:
		TerrainType.PLAIN: return "Равнина"
		TerrainType.FOREST: return "Лес"
		TerrainType.SWAMP: return "Болото"
		TerrainType.HILL: return "Холм"
		TerrainType.WATER: return "Вода"
		TerrainType.ROAD: return "Дорога"
		TerrainType.VILLAGE: return "Деревня"
		TerrainType.RUINS: return "Руины"
		_: return "Неизвестно"


func set_water_level(level: float):
	water_level = level
