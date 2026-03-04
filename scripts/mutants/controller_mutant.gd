extends "res://scripts/mutants/base_mutant.gd"

var controlled_stalker = null

func _ready():
    super._ready()
    health = 80
    speed = 80
    damage = 0  # не кусает, а контролирует
    armor = 10
    detection_radius = 450
    biomass_cost = 100
    
    # Контроллеры медленнее атакуют
    attack_cooldown = 3.0

func _try_attack():
    if current_state == State.ATTACK and target_stalker and is_instance_valid(target_stalker):
        var dist = global_position.distance_to(target_stalker.global_position)
        if dist < 100.0:
            # Пытаемся взять под контроль
            if target_stalker.has_method("take_control"):
                target_stalker.take_control(self)
                controlled_stalker = target_stalker
                attacked_stalker.emit(target_stalker)