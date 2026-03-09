extends BaseStalker
class_name VeteranStalker

func _ready_hook():
    stalker_type = GameEnums.StalkerType.VETERAN
    behavior_type = GameEnums.StalkerBehavior.BRAVE
    max_health = 150.0
    move_speed = 5.5
    damage = 15.0
    vision_range = 25.0
    
    if visuals:
        var material = StandardMaterial3D.new()
        material.albedo_color = Color(0.2, 0.4, 1.0)
        material.metallic = 0.7
        material.roughness = 0.2
        visuals.material_override = material
    
    if label:
        label.text = "VETERAN"
        label.modulate = Color(0.2, 0.4, 1.0)