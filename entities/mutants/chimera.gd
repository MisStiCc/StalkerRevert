# entities/mutants/chimera.gd
extends BaseMutant
class_name ChimeraMutant

@export var is_night_only: bool = false
@export var leap_distance: float = 15.0
@export var leap_damage: float = 50.0
@export var secondary_head_damage: float = 10.0

var can_leap: bool = true
var leap_timer: Timer
var is_leaping: bool = false
var leap_target: Vector3
var leap_time: float = 0.0
var _leap_from: Vector3 = Vector3.ZERO
var _leap_vx: float = 0.0
var _leap_vy: float = 0.0
var _leap_vz: float = 0.0
var _leap_t_total: float = 0.0

func _ready():
	health = 250.0
	max_health = 250.0
	speed = 10.0
	damage = 30.0
	armor = 25.0
	biomass_cost = 200.0
	mutant_type = "chimera"
	
	super._ready()
	_setup_skeletal_anim()
	
	leap_timer = Timer.new()
	leap_timer.one_shot = true
	leap_timer.wait_time = 4.0
	leap_timer.timeout.connect(_on_leap_cooldown_ended)
	add_child(leap_timer)
	
	_setup_label()
	# "Chimera mutant initialized"  # (лог отключён)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if is_leaping:
		_handle_leap(delta)
		return
	
	super._physics_process(delta)
	_update_skeletal_anim(delta)


func _find_new_target():
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	var nearest = null
	var nearest_dist = INF
	
	for s in stalkers:
		if is_instance_valid(s):
			var dist = global_position.distance_to(s.global_position)
			if dist < detection_radius * 2 and dist < nearest_dist:
				nearest_dist = dist
				nearest = s
	
	if nearest:
		target_stalker = nearest
		current_state = State.CHASE


func _patrol(delta):
	_find_new_target()
	super._patrol(delta)


func _chase(_delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		_find_new_target()
		if not target_stalker:
			current_state = State.PATROL
			return
	
	# Поводок: прыжки за жертвой через всю карту запрещены
	if _spawn_position.distance_to(global_position) > leash_radius:
		target_stalker = null
		current_state = State.PATROL
		# "Химера: добыча увела от территории, возврат"  # (лог отключён)
		return
	
	# Застрял у дома - прыжок прямо через препятствие (кинематика проходит сквозь)
	if can_leap and not is_leaping and _stuck_time > 1.5:
		var stuck_dist: float = global_position.distance_to(target_stalker.global_position)
		if stuck_dist > 3.0 and stuck_dist < 30.0:
			_start_leap()
			return
	
	var direction = (target_stalker.global_position - global_position).normalized()
	velocity = direction * speed
	
	if can_leap and not is_leaping:
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < leap_distance and dist > 5.0:
			_start_leap()
	
	if global_position.distance_to(target_stalker.global_position) < 2.5:
		current_state = State.ATTACK


func _start_leap():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	# "Chimera: прыгаю!"  # (лог отключён)
	is_leaping = true
	can_leap = false
	leap_target = target_stalker.global_position
	leap_time = 0.0
	
	# КИНЕМАТИЧЕСКИЙ прыжок на попадание: позиция - функция времени.
	# Низкая дуга: T короткий, пик = g*T^2/8; посадка ровно на цель в момент T.
	var to_target = leap_target - global_position
	var flat_dist = Vector2(to_target.x, to_target.z).length()
	_leap_t_total = max(flat_dist / (speed * 2.0), 0.35)
	_leap_from = global_position
	_leap_vx = to_target.x / _leap_t_total
	_leap_vz = to_target.z / _leap_t_total
	_leap_vy = (to_target.y - global_position.y) / _leap_t_total + 0.5 * gravity * _leap_t_total
	velocity = Vector3.ZERO
	
	leap_timer.start()


func _handle_leap(delta):
	leap_time += delta
	var t = min(leap_time, _leap_t_total)
	
	# Кинематика параболы - физика в полёте не участвует,
	# траекторию никто не перезапишет:
	# x(t) = x0 + vx*t; y(t) = y0 + vy0*t - g*t^2/2
	var pos = _leap_from
	pos.x += _leap_vx * t
	pos.z += _leap_vz * t
	pos.y += _leap_vy * t - 0.5 * gravity * t * t
	global_position = pos
	velocity = Vector3.ZERO
	
	# Нос по дуге: вверх на взлёте, вниз на падении
	var model := get_node_or_null("Model")
	if model:
		var vy: float = _leap_vy - gravity * t
		model.rotation.x = clampf(vy * 0.05, -0.35, 0.35)
	
	if leap_time >= _leap_t_total:
		global_position.y = max(global_position.y, leap_target.y)
		_land()


func _land():
	# "Chimera: приземлился!"  # (лог отключён)
	is_leaping = false
	
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < 5.0:
				stalker.take_damage(leap_damage, self)
				attacked_stalker.emit(stalker)
	
	_find_new_target()


func _on_leap_cooldown_ended():
	can_leap = true


func _attack(_delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 3.0:
		current_state = State.CHASE
		return
	
	if attack_timer.is_stopped():
		target_stalker.take_damage(damage, self)
		
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(target_stalker):
			target_stalker.take_damage(secondary_head_damage, self)
			attacked_stalker.emit(target_stalker)
		
		attack_timer.start()
		# "Chimera атакует!"  # (лог отключён)


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 3.5, 0)  # Выше, потому что химера большая
	label.font_size = 28
	label.outline_size = 2
	label.outline_modulate = Color.BLACK
	label.modulate = Color(0.8, 0.2, 0.8)  # фиолетовый
	label.text = "🦎 ХИМЕРА"
	add_child(label)

# ==================== ПРОЦЕДУРНЫЙ ГАЛОП ПО КОСТЯМ ====================

var _skeleton: Skeleton3D
var _leg_roots: Array = []   # [{bone:int, phase:float}]
var _wing_roots: Array = []  # [{bone:int, phase:float}]
var _head_root: int = -1
var _rest_rot: Dictionary = {}  # bone -> Quaternion (поза покоя)
var _gallop_phase: float = 0.0


func _setup_skeletal_anim():
	"""Автопоиск ног/головы/крыльев по геометрии поз покоя (кости безымянные)"""
	var model := get_node_or_null("Model")
	if model == null:
		return
	var skels = model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	_skeleton = skels[0]
	var bone_count := _skeleton.get_bone_count()
	var kids := {}
	for j in range(bone_count):
		var p := _skeleton.get_bone_parent(j)
		if p >= 0:
			kids[p] = int(kids.get(p, 0)) + 1
	var leaves: Array[int] = []
	for i in range(bone_count):
		if int(kids.get(i, 0)) == 0:
			leaves.append(i)
	# Ступни: концевые ниже 0.35м
	var feet: Array[int] = []
	var head_leaves: Array[int] = []
	var wing_leaves: Array[int] = []
	for l in leaves:
		var gp: Vector3 = _skeleton.get_bone_global_rest(l).origin
		if gp.y < 0.35:
			feet.append(l)
		elif gp.y > 0.9 and gp.z < 0.0:
			head_leaves.append(l)
		elif gp.y > 0.6 and gp.z > 0.4:
			wing_leaves.append(l)
	# Корень ноги: подняться от ступни до первой крупной развилки
	var leg_roots := {}
	for f in feet:
		var b := f
		var guard := 0
		while b >= 0 and guard < 14:
			var par := _skeleton.get_bone_parent(b)
			if par < 0:
				break
			if int(kids.get(par, 0)) > 2 and b != f:
				break
			b = par
			guard += 1
		leg_roots[b] = true
	# Схлопнуть предков: оставляем самые глубокие корни (лапа, не бедро)
	var roots_arr: Array = leg_roots.keys()
	var pruned := {}
	for a in roots_arr:
		var is_ancestor := false
		for b in roots_arr:
			if a == b:
				continue
			var p := _skeleton.get_bone_parent(b)
			var guard := 0
			while p >= 0 and guard < 40:
				if p == a:
					is_ancestor = true
					break
				p = _skeleton.get_bone_parent(p)
				guard += 1
			if is_ancestor:
				break
		if not is_ancestor:
			pruned[a] = true
	# Если всё ещё больше 4 - берём 4 с самыми низкими концевыми костями
	if pruned.size() > 4:
		var scored := []
		for a in pruned:
			var leaf_sum := 0.0
			var leaf_n := 0
			for j in range(bone_count):
				var p := _skeleton.get_bone_parent(j)
				var walk := j
				var guard := 0
				var under := false
				while walk >= 0 and guard < 40:
					if walk == a:
						under = true
						break
					walk = _skeleton.get_bone_parent(walk)
					guard += 1
				if under and int(kids.get(j, 0)) == 0:
					leaf_sum += _skeleton.get_bone_global_rest(j).origin.y
					leaf_n += 1
			scored.append({"bone": a, "y": leaf_sum / maxf(leaf_n, 1.0)})
		scored.sort_custom(func(a, b): return a["y"] < b["y"])
		pruned.clear()
		for i in range(mini(4, scored.size())):
			pruned[scored[i]["bone"]] = true
	for b in pruned:
		var gp: Vector3 = _skeleton.get_bone_global_rest(b).origin
		var phase := 0.0
		if gp.z < 0.0:
			phase += PI
		if gp.x > 0.0:
			phase += PI * 0.5
		_leg_roots.append({"bone": b, "phase": phase})
	# Голова: корень самой высокой передней цепочки
	var head_best_y := 0.0
	for l in head_leaves:
		var gp: Vector3 = _skeleton.get_bone_global_rest(l).origin
		if gp.y > head_best_y:
			head_best_y = gp.y
			var b := l
			var guard := 0
			while b >= 0 and guard < 14:
				var par := _skeleton.get_bone_parent(b)
				if par < 0 or int(kids.get(par, 0)) > 2:
					break
				b = par
				guard += 1
			_head_root = b
	# Крылья: задние верхние цепочки
	var wing_roots := {}
	for l in wing_leaves:
		var b := l
		var guard := 0
		while b >= 0 and guard < 14:
			var par := _skeleton.get_bone_parent(b)
			if par < 0:
				break
			if int(kids.get(par, 0)) > 2 and b != l:
				break
			b = par
			guard += 1
		wing_roots[b] = true
	var wi := 0.0
	for b in wing_roots:
		_wing_roots.append({"bone": b, "phase": wi})
		wi += 1.3
	# Поз покоя для всех анимируемых костей
	for entry in _leg_roots + _wing_roots:
		var b: int = int(entry["bone"])
		_rest_rot[b] = _skeleton.get_bone_pose_rotation(b)
	if _head_root >= 0:
		_rest_rot[_head_root] = _skeleton.get_bone_pose_rotation(_head_root)
	print("Галоп: ног=", _leg_roots.size(), ", крыльев=", _wing_roots.size(), ", голова=", _head_root >= 0)


func _update_skeletal_anim(delta: float):
	"""Галоп: ноги по диагональным фазам, взмахи крыльев, покачивание головы"""
	if _skeleton == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var gait: float = clampf(speed / 6.0, 0.0, 1.5)
	_gallop_phase += delta * maxf(speed, 1.0) * 2.2
	for entry in _leg_roots:
		var b: int = int(entry["bone"])
		var swing: float = sin(_gallop_phase + float(entry["phase"])) * 0.5 * gait
		_skeleton.set_bone_pose_rotation(b, _rest_rot[b] * Quaternion(Vector3(1, 0, 0), swing))
	for entry in _wing_roots:
		var b: int = int(entry["bone"])
		var flap: float = sin(_gallop_phase * 0.7 + float(entry["phase"])) * (0.25 + 0.2 * gait)
		_skeleton.set_bone_pose_rotation(b, _rest_rot[b] * Quaternion(Vector3(0, 0, 1), flap))
	if _head_root >= 0:
		var sway: float = sin(_gallop_phase * 0.5) * 0.08 * (0.5 + gait)
		_skeleton.set_bone_pose_rotation(_head_root, _rest_rot[_head_root] * Quaternion(Vector3(0, 1, 0), sway))
