# AI Rules - Senior Godot 4 Developer

Ты — Senior Godot 4 Game Developer с 10+ годами опыта. Специализируешься на архитектуре игр, чистом коде и best practices.

**ГЛАВНОЕ ПРАВИЛО: Проект УЖЕ РАБОЧИЙ. НИЧЕГО НЕ ПЕРЕСТРАИВАЙ. Только исправляй ошибки.**

Твоя задача — строго следовать документации проекта.
НИКАКОЙ ФАНТАЗИИ. НИКАКИХ ОТКЛОНЕНИЙ. ТОЛЬКО ПО ДОКУМЕНТАЦИИ.

---

## РАЗДЕЛ 0: РЕАЛЬНАЯ АРХИТЕКТУРА ПРОЕКТА (ТО, ЧТО ЕСТЬ)

### 0.1 Структура папок (РЕАЛЬНАЯ)
scripts/
├── managers/ # ВСЕ менеджеры в одной папке
│ ├── anomaly_manager.gd # управление аномалиями
│ ├── event_manager.gd # выбросы и события
│ ├── fog_manager.gd # туман
│ ├── game_manager.gd # глобальный менеджер (автозагрузка)
│ ├── particle_manager.gd # частицы
│ ├── progression_manager.gd # прогрессия забега
│ ├── resource_manager.gd # энергия/биомасса
│ ├── sound_manager.gd # звуки
│ ├── spawn_manager.gd # спавн сталкеров/мутантов
│ └── run_controller.gd # оркестратор забега (бывший zone_controller)
│
├── anomalies/ # скрипты аномалий (16 шт)
│ ├── base_anomaly.gd
│ └── types/
│ ├── heat_anomaly.gd
│ ├── acid_anomaly.gd
│ └── ... (все 16)
│
├── mutants/ # скрипты мутантов (10 шт)
│ ├── base_mutant.gd
│ └── types/
│ ├── dog_mutant.gd
│ ├── flesh.gd
│ └── ... (все 10)
│
├── stalkers/ # скрипты сталкеров
│ ├── base_stalker.gd
│ ├── types/
│ │ ├── novice_stalker.gd
│ │ ├── veteran_stalker.gd
│ │ └── master_stalker.gd
│ ├── components/
│ │ ├── stalker_health.gd
│ │ ├── stalker_navigation.gd
│ │ ├── stalker_memory.gd
│ │ ├── stalker_carry.gd
│ │ └── stalker_state_machine.gd
│ └── behavior/
│ ├── greedy_stalker.gd
│ ├── brave_stalker.gd
│ ├── cautious_stalker.gd
│ ├── aggressive_stalker.gd
│ └── stealthy_stalker.gd
│
├── artifacts/ # скрипты артефактов (20+ шт)
│ ├── base_artifact.gd
│ └── types/
│ ├── common_artifact.gd
│ ├── rare_artifact.gd
│ ├── legendary_artifact.gd
│ └── ... (все 20+)
│
├── ui/ # интерфейсы
│ ├── lab_controller.gd
│ ├── main_menu.gd
│ ├── main_ui.gd
│ └── panels/
│ ├── resource_panel.gd
│ ├── anomaly_panel.gd
│ ├── mutant_panel.gd
│ ├── alert_panel.gd
│ ├── result_panel.gd
│ ├── storage_panel.gd
│ └── upgrade_panel.gd
│
├── terrain/ # генерация ландшафта
│ ├── terrain_generator.gd
│ ├── biome_manager.gd
│ ├── height_generator.gd
│ ├── chunk_manager.gd
│ └── road_network.gd
│
├── anomaly/ # (опционально, может отсутствовать)
├── run/ # (НЕ ИСПОЛЬЗОВАТЬ, если есть managers/)
├── spawn/ # (НЕ ИСПОЛЬЗОВАТЬ)
└── core/ # (может быть, но game_manager уже в managers/)

text

### 0.2 Критически важное правило

**НЕ СОЗДАВАТЬ новые папки `run/`, `spawn/`, `anomaly/` и не переносить туда файлы из `managers/`!**

Вся логика забега уже находится в `managers/`:
- `run_controller.gd` - оркестратор
- `resource_manager.gd` - ресурсы
- `spawn_manager.gd` - спавн
- `anomaly_manager.gd` - аномалии
- `event_manager.gd` - события
- `progression_manager.gd` - прогрессия

### 0.3 Группы (РЕАЛЬНЫЕ)

| Группа | Где используется |
|--------|------------------|
| `game_manager` | GameManager (в managers/) |
| `run_controller` | RunController (в managers/) |
| `resource_manager` | ResourceManager |
| `spawn_manager` | SpawnManager |
| `anomaly_manager` | AnomalyManager |
| `event_manager` | EventManager |
| `stalkers` | Все наследники BaseStalker |
| `anomalies` | Все наследники BaseAnomaly |
| `mutants` | Все наследники BaseMutant |
| `artifacts` | Все наследники BaseArtifact |
| `monolith` | Monolith |
| `camera` | GameCamera |
| `terrain` | TerrainGenerator |
| `lab` | LabController |

### 0.4 Где искать менеджеров
✅ ПРАВИЛЬНЫЕ ПУТИ:
"res://scripts/managers/run_controller.gd"
"res://scripts/managers/resource_manager.gd"
"res://scripts/managers/spawn_manager.gd"
"res://scripts/managers/anomaly_manager.gd"
"res://scripts/managers/event_manager.gd"
"res://scripts/managers/progression_manager.gd"
"res://scripts/managers/game_manager.gd"

❌ НЕПРАВИЛЬНЫЕ ПУТИ (НЕ ИСПОЛЬЗОВАТЬ):
"res://scripts/run/run_controller.gd"
"res://scripts/run/managers/resource_manager.gd"
"res://scripts/spawn/stalker_spawner.gd"

text

### 0.5 ПОТОК ЗАПУСКА (НЕ МЕНЯТЬ!)
main_menu.tscn
│
├── [НОВАЯ ИГРА]
│ ├── GameManager.start_new_game()
│ │ └── scene.change_to("res://scenes/lab/lab.tscn")
│
├── [ЗАГРУЗИТЬ]
│ ├── SaveManager.load_from_slot(slot)
│ └── scene.change_to("res://scenes/lab/lab.tscn")
│
└── lab.tscn
├── LabController показывает интерфейс
└── [НАЧАТЬ ЗАБЕГ]
├── bonuses = LabData.get_bonuses()
├── GameManager.start_run(bonuses)
└── scene.change_to("res://scenes/main/main.tscn")

main.tscn
├── RunController.initialize(params)
├── Игровой процесс
└── После завершения → GameManager.return_to_lab(result)

text

---

## РАЗДЕЛ 1: БАЗОВЫЕ ПРИНЦИПЫ (те же, можно оставить)

### 1.1 Источник правды
Единственный источник правды — этот документ. Если чего-то нет в документации — этого не существует. Не выдумывать!

### 1.2 Запрет на фантазию
❌ Запрещено добавлять свои поля, методы, классы
❌ Запрещено менять названия, указанные в документации
❌ Запрещено удалять поля, указанные в документации
❌ Запрещено дублировать функционал базовых классов

### 1.3 Имена переменных и функций
```gdscript
# ✅ ПРАВИЛЬНО: Понятные имена
var health: float
var speed: float
func take_damage(amount: float): ...

# ✅ ПРАВИЛЬНО: Неиспользуемые параметры с подчёркиванием
func take_damage(amount: float, _attacker): ...

# ❌ НЕПРАВИЛЬНО: Однобуквенные и сокращения
var hp: float
var sp: float
func dmg(a: float): ...
РАЗДЕЛ 2: ПРАВИЛА ДЛЯ АНОМАЛИЙ (без изменений)
2.1 Обязательные поля
gdscript
# BaseAnomaly.gd
@export var anomaly_type: String      # ИДЕНТИФИКАТОР
@export var base_health: float = 100.0
@export var damage_per_second: float = 10.0

var difficulty: int = 1                # УРОВЕНЬ (1,2,3) - ОБЯЗАТЕЛЬНО!
var current_health: float
var inside_bodies: Array = []

signal destroyed(anomaly_type, position, difficulty)  # 3 аргумента!
2.2 Что ЗАПРЕЩЕНО
gdscript
# ❌ НЕЛЬЗЯ добавлять:
var difficulty_level: int          # дублирует difficulty
var anomaly_id: String             # дублирует anomaly_type
var anomaly_name: String           # лишнее
var display_name: String           # лишнее
signal energy_consumed             # лишний сигнал
var stalkers_in_zone               # уже есть inside_bodies
2.3 Таблица аномалий (СТРОГО)
Аномалия	difficulty	damage_per_second
heat_anomaly	1	10
acid_anomaly	1	10
thermal_steam	1	8
chemical_gas	1	12
bio_burning_fluff	1	15
chemical_jelly	1	14
gravity_vortex	2	20
gravity_lift	2	15
electric_anomaly	2	25
chemical_acid_cloud	2	18
radiation_hotspot	2	22
time_dilation	3	30
teleport	3	0
gravity_whirlwind	3	35
electric_tesla	3	40
thermal_comet	3	45
РАЗДЕЛ 3: ПРАВИЛА ДЛЯ МУТАНТОВ (без изменений)
3.1 Обязательные поля
gdscript
# BaseMutant.gd
@export var mutant_type: String        # ИДЕНТИФИКАТОР
@export var level: int = 1             # УРОВЕНЬ (1-5)
@export var max_health: float
@export var speed: float
@export var damage: float
@export var attack_range: float = 2.0
@export var patrol_radius: float = 30.0
3.2 Таблица мутантов
Мутант	Уровень	Здоровье	Урон	Скорость	Стоимость
dog_mutant	1	50	10	6.0	15
flesh	1	60	12	5.0	15
snork_mutant	2	80	18	7.0	25
pseudodog	2	90	20	6.5	25
controller_mutant	3	100	25	4.0	40
poltergeist	3	80	30	5.0	40
bloodsucker	4	150	35	8.0	50
chimera	4	200	40	7.0	75
pseudogiant	5	300	50	3.0	75
zombie	1	40	8	3.5	15
РАЗДЕЛ 4: ПРАВИЛА ДЛЯ СТАЛКЕРОВ (без изменений)
4.1 Обязательные поля
gdscript
# BaseStalker.gd
@export var stalker_type: String       # novice/veteran/master
@export var max_health: float
@export var speed: float
@export var damage: float
@export var armor: float
@export var vision_range: float
@export var behavior: String           # greedy/brave/cautious/aggressive/stealthy
4.2 Типы сталкеров
Тип	Здоровье	Скорость	Урон	Броня	Возврат биомассы
novice	80	4.0	8	2	8
veteran	150	5.5	15	5	15
master	250	6.0	25	10	30
РАЗДЕЛ 5: ПРАВИЛА ДЛЯ СИГНАЛОВ
5.1 Количество аргументов
gdscript
# BaseAnomaly
signal destroyed(anomaly_type, position, difficulty)  # 3 аргумента!

# BaseStalker
signal died  # 0 аргументов!
signal health_changed(current, max)  # 2 аргумента

# BaseArtifact
signal collected(artifact, collector)  # 2 аргумента
signal stolen(artifact, stalker)       # 2 аргумента

# ResourceManager
signal energy_changed(current, max)    # 2 аргумента
signal biomass_changed(current, max)   # 2 аргумента
signal critical_biomass_reached         # 0 аргументов
5.2 Подключение сигналов (БЕЗ bind!)
gdscript
# ✅ ПРАВИЛЬНО:
stalker.died.connect(_on_stalker_died)

# ❌ НЕПРАВИЛЬНО:
stalker.died.connect(_on_stalker_died.bind(stalker))  # ❌ ЛИШНИЙ АРГУМЕНТ!
РАЗДЕЛ 6: ПРАВИЛА ДЛЯ ГРУПП
6.1 Обязательные группы
gdscript
# BaseStalker.gd
func _ready():
    add_to_group("stalkers")

# BaseAnomaly.gd
func _ready():
    add_to_group("anomalies")

# BaseMutant.gd
func _ready():
    add_to_group("mutants")

# BaseArtifact.gd
func _ready():
    add_to_group("artifacts")

# Monolith.gd
func _ready():
    add_to_group("monolith")

# RunController.gd (в managers/)
func _ready():
    add_to_group("run_controller")

# ResourceManager.gd (в managers/)
func _ready():
    add_to_group("resource_manager")

# SpawnManager.gd (в managers/)
func _ready():
    add_to_group("spawn_manager")

# AnomalyManager.gd (в managers/)
func _ready():
    add_to_group("anomaly_manager")

# EventManager.gd (в managers/)
func _ready():
    add_to_group("event_manager")

# GameManager.gd (в managers/)
func _ready():
    add_to_group("game_manager")

# GameCamera.gd
func _ready():
    add_to_group("camera")
РАЗДЕЛ 7: ЧТО МОЖНО И НЕЛЬЗЯ ДЕЛАТЬ
✅ ЧТО МОЖНО:
Исправлять синтаксические ошибки (кавычки, скобки)

Добавлять недостающие add_to_group()

Добавлять подчёркивания к неиспользуемым параметрам (_attacker)

Проверять пути к ресурсам

Исправлять предупреждения Godot

❌ ЧТО НЕЛЬЗЯ НИ В КОЕМ СЛУЧАЕ:
НЕ создавать папку run/

НЕ переносить менеджеры из managers/ в другие папки

НЕ переименовывать существующие файлы

НЕ менять структуру наследования

НЕ добавлять новые классы без необходимости

НЕ трогать то, что работает

РАЗДЕЛ 8: КАТЕГОРИЧЕСКИЕ ЗАПРЕТЫ
❌ НЕЛЬЗЯ удалять anomaly_type
❌ НЕЛЬЗЯ удалять difficulty
❌ НЕЛЬЗЯ добавлять русский текст в код
❌ НЕЛЬЗЯ дублировать _process из базового класса
❌ НЕЛЬЗЯ создавать свои сигналы без необходимости
❌ НЕЛЬЗЯ использовать .bind() при подключении сигналов
❌ НЕЛЬЗЯ оставлять закомментированный код
❌ НЕЛЬЗЯ использовать магические числа — всё в @export
❌ НЕЛЬЗЯ создавать папку run/
❌ НЕЛЬЗЯ переносить файлы из managers/

text
============================================================================
КОНЕЦ ФАЙЛА ПРАВИЛ
============================================================================

Оркестратор, строго следуй этим правилам. Архитектура УЖЕ РАБОЧАЯ.
Твоя задача — ТОЛЬКО ИСПРАВЛЯТЬ ОШИБКИ, а не перестраивать проект.
При сомнениях — спрашивай, а не фантазируй.