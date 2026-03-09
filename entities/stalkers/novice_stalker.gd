extends BaseStalker
class_name NoviceStalker

func _ready_hook():
    stalker_type = GameEnums.StalkerType.NOVICE
    behavior_type = GameEnums.StalkerBehavior.GREEDY
    max_health = 80.0
    move_speed = 4.0
    damage = 8.0
    vision_range = 20.0
    
    if visuals:
        var material = StandardMaterial3D.new()
        material.albedo_color = Color(0.2, 0.8, 0.2)
        visuals.material_override = material
    
    if label:
        label.text = "NOVICE"
        label.modulate = Color(0.2, 0.8, 0.2)