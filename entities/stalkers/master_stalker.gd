extends BaseStalker
class_name MasterStalker

func _ready_hook():
    stalker_type = GameEnums.StalkerType.MASTER
    behavior_type = GameEnums.StalkerBehavior.AGGRESSIVE
    max_health = 250.0
    move_speed = 6.0
    damage = 25.0
    vision_range = 30.0
    
    if visuals:
        var material = StandardMaterial3D.new()
        material.albedo_color = Color(0.8, 0.2, 0.8)
        material.metallic = 0.8
        material.roughness = 0.1
        material.emission_enabled = true
        material.emission = Color(0.8, 0.2, 0.8)
        visuals.material_override = material
    
    if label:
        label.text = "MASTER"
        label.modulate = Color(0.8, 0.2, 0.8)