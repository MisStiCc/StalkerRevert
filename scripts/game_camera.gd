# scripts/game_camera.gd
extends Camera3D

@export var move_speed: float = 20.0
@export var look_speed: float = 0.002

var mouse_captured: bool = false
var rotation_x: float = 0.0
var rotation_y: float = 0.0

func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    mouse_captured = true

func _input(event):
    if event is InputEventMouseMotion and mouse_captured:
        rotation_y -= event.relative.x * look_speed
        rotation_x -= event.relative.y * look_speed
        rotation_x = clamp(rotation_x, -1.4, 1.4)
        
        rotation.y = rotation_y
        rotation.x = rotation_x
    
    if event.is_action_pressed("ui_cancel"):
        if mouse_captured:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
            mouse_captured = false
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            mouse_captured = true

func _process(delta):
    var input_dir = Vector3.ZERO
    
    if Input.is_key_pressed(KEY_W):
        input_dir -= transform.basis.z
    if Input.is_key_pressed(KEY_S):
        input_dir += transform.basis.z
    if Input.is_key_pressed(KEY_A):
        input_dir -= transform.basis.x
    if Input.is_key_pressed(KEY_D):
        input_dir += transform.basis.x
    if Input.is_key_pressed(KEY_SPACE):
        input_dir += Vector3.UP
    if Input.is_key_pressed(KEY_SHIFT):
        input_dir -= Vector3.UP
    
    if input_dir.length() > 0:
        input_dir = input_dir.normalized()
        global_position += input_dir * move_speed * delta