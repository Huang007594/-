extends CharacterBody3D

# ── Monster types ──
enum MonsterType { STALKER, SPRINTER, AMBUSHER }
var monster_type: MonsterType = MonsterType.STALKER

# ── States ──
enum State { IDLE, PATROL, ALERT, CHASE, SEARCH, BERSERK, STALKING }
var state := State.IDLE

# ── Speed (overridden per type) ──
var patrol_speed := 3.0
var chase_speed := 6.5
var alert_speed := 4.0
var search_speed := 4.0
var berserk_speed := 9.0
var stalker_speed := 2.5

# ── Detection (overridden per type) ──
var vision_range := 25.0
var hearing_range_sprint := 25.0
var hearing_range_walk := 12.0
var hearing_range_crouch := 5.0
var attack_range := 2.5
var attack_damage := 30.0

# ── Timers ──
const ATTACK_COOLDOWN_MAX := 0.8
var chase_timeout := 25.0
const ALERT_DURATION := 3.0
const SEARCH_DURATION := 25.0
const BERSERK_DURATION := 8.0
const STALK_DURATION := 15.0
const REPATH_INTERVAL := 0.3

# ── State vars ──
var player: Node3D = null
var generator: Node = null
var chasing := false
var chase_elapsed := 0.0
var attack_timer := 0.0
var repath_timer := 0.0
var path: Array[Vector2i] = []
var current_path_idx := 0
var dead := false
var dist_to_player := 0.0
var patrol_rng := RandomNumberGenerator.new()
var _debug_timer := 0.0

# ── Tracking / prediction ──
var last_known_player_pos := Vector3.ZERO
var predicted_player_pos := Vector3.ZERO
var player_velocity_estimate := Vector3.ZERO
var prev_player_pos := Vector3.ZERO
var last_seen_cell := Vector2i(-1, -1)
var search_cells: Array[Vector2i] = []
var search_cell_index := 0
var search_timer := 0.0
var alert_timer := 0.0
var berserk_timer := 0.0
var stalker_timer := 0.0
var stalk_close_timer := 0.0
var damage_taken := 0.0
const BERSERK_THRESHOLD := 50.0
var stalk_distance := 15.0

# ── Visual ──
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var left_eye: MeshInstance3D
var right_eye: MeshInstance3D
var glow_light: OmniLight3D

# ── Audio ──
var audio_mgr: Node
var growl_timer := 0.0
var growl_interval := 5.0

func _ready():
	_setup_visuals()

func set_monster_type(t: MonsterType):
	monster_type = t
	match monster_type:
			MonsterType.STALKER:
				chase_speed = 7.0
				berserk_speed = 9.0
				vision_range = 28.0
				attack_damage = 30.0
			MonsterType.SPRINTER:
				chase_speed = 9.5
				berserk_speed = 11.0
				vision_range = 18.0
				attack_damage = 25.0
				chase_timeout = 15.0
			MonsterType.AMBUSHER:
				chase_speed = 7.5
				berserk_speed = 9.5
				vision_range = 25.0
				attack_damage = 40.0
				stalk_distance = 12.0
	_update_visual_colors()

func _update_visual_colors():
	if not body_mesh:
		return
	var body_mat = body_mesh.material_override as StandardMaterial3D
	if not body_mat:
		return
	match monster_type:
		MonsterType.STALKER:
			body_mat.albedo_color = Color(0.15, 0.08, 0.06)
			body_mat.emission = Color(0.3, 0.05, 0.03)
			if glow_light:
				glow_light.light_color = Color(1.0, 0.2, 0.1)
		MonsterType.SPRINTER:
			body_mat.albedo_color = Color(0.12, 0.12, 0.02)
			body_mat.emission = Color(0.35, 0.3, 0.0)
			if glow_light:
				glow_light.light_color = Color(1.0, 0.9, 0.1)
		MonsterType.AMBUSHER:
			body_mat.albedo_color = Color(0.06, 0.02, 0.14)
			body_mat.emission = Color(0.15, 0.0, 0.4)
			if glow_light:
				glow_light.light_color = Color(0.5, 0.0, 1.0)

func _setup_visuals():
	# Collision shape
	var col_shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	col_shape.shape = capsule
	col_shape.position.y = 0.9
	add_child(col_shape)

	# Body
	body_mesh = MeshInstance3D.new()
	body_mesh.position.y = 0.8
	var body_m = CapsuleMesh.new()
	body_m.radius = 0.25
	body_m.height = 1.2
	body_mesh.mesh = body_m
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.15, 0.08, 0.06)
	body_mat.emission_enabled = true
	body_mat.emission = Color(0.3, 0.05, 0.03)
	body_mat.emission_energy_multiplier = 0.5
	body_mat.roughness = 0.9
	body_mesh.material_override = body_mat
	add_child(body_mesh)

	# Head
	head_mesh = MeshInstance3D.new()
	head_mesh.position.y = 1.7
	var head_m = SphereMesh.new()
	head_m.radius = 0.22
	head_m.height = 0.35
	head_mesh.mesh = head_m
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.1, 0.08, 0.07)
	head_mat.roughness = 0.9
	head_mesh.material_override = head_mat
	add_child(head_mesh)

	# Eyes
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.9, 0.1, 0.05)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.15, 0.05)
	eye_mat.emission_energy_multiplier = 4.0
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	left_eye = MeshInstance3D.new()
	left_eye.position = Vector3(-0.08, 1.72, -0.18)
	var eye_m = SphereMesh.new()
	eye_m.radius = 0.035
	eye_m.height = 0.07
	left_eye.mesh = eye_m
	left_eye.material_override = eye_mat
	add_child(left_eye)

	right_eye = MeshInstance3D.new()
	right_eye.position = Vector3(0.08, 1.72, -0.18)
	right_eye.mesh = SphereMesh.new()
	(right_eye.mesh as SphereMesh).radius = 0.035
	(right_eye.mesh as SphereMesh).height = 0.07
	right_eye.material_override = eye_mat
	add_child(right_eye)

	# Arms
	var arm_mat = StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.06, 0.05, 0.04)
	arm_mat.roughness = 0.95

	left_arm = MeshInstance3D.new()
	left_arm.position = Vector3(-0.35, 0.7, 0)
	var arm_m = CapsuleMesh.new()
	arm_m.radius = 0.06
	arm_m.height = 0.9
	left_arm.mesh = arm_m
	left_arm.material_override = arm_mat
	add_child(left_arm)

	right_arm = MeshInstance3D.new()
	right_arm.position = Vector3(0.35, 0.7, 0)
	right_arm.mesh = CapsuleMesh.new()
	(right_arm.mesh as CapsuleMesh).radius = 0.06
	(right_arm.mesh as CapsuleMesh).height = 0.9
	right_arm.material_override = arm_mat
	add_child(right_arm)

	# Legs
	var leg_mat = StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.07, 0.05, 0.04)
	leg_mat.roughness = 0.95

	var left_leg = MeshInstance3D.new()
	left_leg.position = Vector3(-0.12, 0.15, 0)
	var leg_m = CapsuleMesh.new()
	leg_m.radius = 0.07
	leg_m.height = 0.5
	left_leg.mesh = leg_m
	left_leg.material_override = leg_mat
	add_child(left_leg)

	var right_leg = MeshInstance3D.new()
	right_leg.position = Vector3(0.12, 0.15, 0)
	right_leg.mesh = CapsuleMesh.new()
	(right_leg.mesh as CapsuleMesh).radius = 0.07
	(right_leg.mesh as CapsuleMesh).height = 0.5
	right_leg.material_override = leg_mat
	add_child(right_leg)

	# Glow light
	glow_light = OmniLight3D.new()
	glow_light.light_color = Color(1.0, 0.2, 0.1)
	glow_light.light_energy = 2.0
	glow_light.omni_range = 10.0
	glow_light.position.y = 1.0
	add_child(glow_light)

func init(gen: Node, player_node: Node3D):
	generator = gen
	player = player_node
	patrol_rng.randomize()
	_stop_chase()

# ══════════════════════════════════════════════════════════════
# STATE MACHINE
# ══════════════════════════════════════════════════════════════

func _stop_chase():
	chasing = false
	chase_elapsed = 0.0
	attack_timer = 0.0
	path.clear()
	current_path_idx = 0
	velocity = Vector3.ZERO
	state = State.IDLE
	search_cells.clear()
	search_cell_index = 0
	damage_taken = 0.0

func start_chase():
	_enter_state(State.CHASE)

func start_patrol():
	_enter_state(State.PATROL)

func _enter_state(new_state: State):
	state = new_state
	repath_timer = 0.0
	path.clear()
	current_path_idx = 0

	match state:
		State.PATROL:
			chasing = false
			growl_interval = 8.0
			_pick_patrol_target()

		State.ALERT:
			chasing = false
			alert_timer = 0.0
			last_known_player_pos = player.global_position if player else Vector3.ZERO

		State.CHASE:
			chasing = true
			chase_elapsed = 0.0
			growl_timer = 0.0
			growl_interval = 3.0
			last_known_player_pos = player.global_position if player else Vector3.ZERO
			predicted_player_pos = last_known_player_pos

		State.SEARCH:
			chasing = false
			search_timer = 0.0
			_generate_search_pattern()
			search_cell_index = 0

		State.BERSERK:
			chasing = true
			berserk_timer = 0.0
			growl_interval = 2.0

		State.STALKING:
			chasing = false
			stalker_timer = 0.0
			stalk_close_timer = 0.0
			growl_interval = 10.0
			last_known_player_pos = player.global_position if player else Vector3.ZERO

		State.IDLE:
			chasing = false
			velocity = Vector3.ZERO

# ══════════════════════════════════════════════════════════════
# PLAYER DETECTION
# ══════════════════════════════════════════════════════════════

func _check_line_of_sight() -> bool:
	if not player:
		return false
	var from = global_position + Vector3(0, 1.5, 0)
	var to = player.global_position + Vector3(0, 1.0, 0)
	var dist = from.distance_to(to)
	if dist > vision_range:
		return false
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _get_hearing_range() -> float:
	if not player:
		return hearing_range_walk
	if not player is CharacterBody3D:
		return hearing_range_walk
	var p = player as CharacterBody3D
	if p.crouching:
		return hearing_range_crouch
	if p.speed >= p.SPRINT_SPEED:
		return hearing_range_sprint
	return hearing_range_walk

func _can_hear_player() -> bool:
	if not player:
		return false
	return global_position.distance_to(player.global_position) < _get_hearing_range()

func _is_player_detected() -> bool:
	return _check_line_of_sight() or _can_hear_player()

func _estimate_player_velocity(delta: float):
	if delta > 0 and player:
		player_velocity_estimate = (player.global_position - prev_player_pos) / delta
	if player:
		prev_player_pos = player.global_position

func _predict_player_position() -> Vector3:
	var prediction_time := 1.5
	if monster_type == MonsterType.AMBUSHER:
		prediction_time = 2.5  # ambusher predicts further ahead
	var predicted = player.global_position + player_velocity_estimate * prediction_time
	# Clamp to maze bounds
	var cell_size = generator.CELL_SIZE
	var px = clampi(int(floor(predicted.x / cell_size)), 0, generator.MAZE_COLS - 1)
	var pz = clampi(int(floor(predicted.z / cell_size)), 0, generator.MAZE_ROWS - 1)
	return Vector3(px * cell_size + cell_size * 0.5, 0.0, pz * cell_size + cell_size * 0.5)

# ══════════════════════════════════════════════════════════════
# MAIN LOOP
# ══════════════════════════════════════════════════════════════

func _physics_process(delta):
	if dead or not player or not generator:
		if not player:
			print("[Monster] ERROR: player is null!")
		if not generator:
			print("[Monster] ERROR: generator is null!")
		return

	attack_timer = maxf(attack_timer - delta, 0.0)

	# Debug: print state and position every 2 seconds
	_debug_timer += delta
	if _debug_timer >= 2.0:
		_debug_timer = 0.0
		var dist = global_position.distance_to(player.global_position)
		print("[Monster] state=%s pos=%s dist=%.1f vel=%s" % [State.keys()[state], global_position, dist, velocity])

	# Visibility
	var dist_to_player := global_position.distance_to(player.global_position)
	if chasing or state == State.CHASE or state == State.BERSERK or state == State.SEARCH:
		visible = dist_to_player < generator.CELL_SIZE * generator.RENDER_MARGIN

	# Audio growl
	growl_timer += delta
	if growl_timer >= growl_interval:
		growl_timer = 0.0
		if state == State.CHASE or state == State.BERSERK:
			growl_interval = randf_range(2.0, 5.0)
		elif state == State.STALKING:
			growl_interval = randf_range(8.0, 15.0)
		else:
			growl_interval = randf_range(8.0, 20.0)

	_animate(delta)

	# Player velocity tracking
	_estimate_player_velocity(delta)

	match state:
		State.IDLE:
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			if _is_player_detected():
				if _check_line_of_sight():
					_enter_state(State.CHASE)
				else:
					_enter_state(State.ALERT)

		State.PATROL:
			_patrol_tick(delta)

		State.ALERT:
			_alert_tick(delta)

		State.CHASE:
			_chase_tick(delta)

		State.SEARCH:
			_search_tick(delta)

		State.BERSERK:
			_berserk_tick(delta)

		State.STALKING:
			_stalking_tick(delta)

# ══════════════════════════════════════════════════════════════
# STATE TICKS
# ══════════════════════════════════════════════════════════════

func _patrol_tick(delta):
	_follow_path(delta, patrol_speed)
	# Check for player
	if _check_line_of_sight():
		_enter_state(State.CHASE)
		return
	if _can_hear_player():
		_enter_state(State.ALERT)
		return
	# Pick new patrol target when done
	if path.size() == 0 or current_path_idx >= path.size():
		_pick_patrol_target()

func _alert_tick(delta):
	alert_timer += delta
	# Face toward last known player position
	_face_toward(last_known_player_pos, delta)

	if _check_line_of_sight():
		_enter_state(State.CHASE)
		return

	if alert_timer >= ALERT_DURATION:
		_enter_state(State.SEARCH)
		return

	# Move toward last known position
	repath_timer -= delta
	if repath_timer <= 0.0:
		repath_timer = REPATH_INTERVAL
		_find_path_to_cell(last_known_player_pos)
	_follow_path(delta, alert_speed)

func _chase_tick(delta):
	chase_elapsed += delta

	# Berserk check
	if damage_taken >= BERSERK_THRESHOLD:
		_enter_state(State.BERSERK)
		return

	# Move directly toward player
	var dir = (player.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.5:
		dir = dir.normalized()
		var speed_boost = minf(chase_elapsed * 0.1, 2.5)
		var spd = chase_speed + speed_boost
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	else:
		velocity.x = 0
		velocity.z = 0

	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0

	_face_toward(player.global_position, delta)
	move_and_slide()

	# Attack
	dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player < attack_range and attack_timer <= 0.0:
		_perform_attack()
func _search_tick(delta):
	search_timer += delta

	if _check_line_of_sight():
		_enter_state(State.CHASE)
		return
	if _can_hear_player():
		last_known_player_pos = player.global_position
		_enter_state(State.ALERT)
		return

	if search_timer >= SEARCH_DURATION:
		_enter_state(State.PATROL)
		return

	# Visit search cells
	if search_cells.size() == 0:
		_generate_search_pattern()

	if search_cell_index < search_cells.size():
		var target_cell = search_cells[search_cell_index]
		var cs = generator.CELL_SIZE
		var target_pos = Vector3(target_cell.x * cs + cs * 0.5, 0.0, target_cell.y * cs + cs * 0.5)

		repath_timer -= delta
		if repath_timer <= 0.0:
			repath_timer = REPATH_INTERVAL
			_find_path_to_cell(target_pos)

		_follow_path(delta, search_speed)

		var dist = global_position.distance_to(target_pos)
		if dist < cs * 0.5:
			search_cell_index += 1
	else:
		_enter_state(State.PATROL)

func _berserk_tick(delta):
	berserk_timer += delta

	if berserk_timer >= BERSERK_DURATION:
		damage_taken = 0.0
		_enter_state(State.CHASE)
		return

	# Move directly toward player -- faster during berserk
	var dir = (player.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.5:
		dir = dir.normalized()
		velocity.x = dir.x * berserk_speed
		velocity.z = dir.z * berserk_speed
	else:
		velocity.x = 0
		velocity.z = 0

	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0

	_face_toward(player.global_position, delta)
	move_and_slide()

	# Attack with reduced cooldown during berserk
	dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player < attack_range * 1.2 and attack_timer <= 0.0:
		attack_timer = ATTACK_COOLDOWN_MAX * 0.6
		_perform_attack_berserk()

	# Intense glow during berserk
	if glow_light:
		glow_light.light_energy = 4.0 + sin(Time.get_ticks_msec() * 0.01) * 2.0

func _stalking_tick(delta):
	stalker_timer += delta

	if _check_line_of_sight():
		last_known_player_pos = player.global_position
		chase_elapsed = 0.0

	var dist_to_player = global_position.distance_to(player.global_position)

	if dist_to_player < stalk_distance * 0.6:
		# Back away from player
		var away = (global_position - player.global_position).normalized()
		var retreat_target = global_position + away * generator.CELL_SIZE * 2
		repath_timer -= delta
		if repath_timer <= 0.0:
			repath_timer = REPATH_INTERVAL
			_find_path_to_cell(retreat_target)
		_follow_path(delta, stalker_speed)
	elif dist_to_player > stalk_distance * 1.5:
		# Move closer
		repath_timer -= delta
		if repath_timer <= 0.0:
			repath_timer = REPATH_INTERVAL
			_find_path_to_cell(last_known_player_pos)
		_follow_path(delta, stalker_speed * 1.5)
	else:
		# Idle — face the player
		_face_toward(player.global_position, delta)
		velocity.x = 0
		velocity.z = 0
		move_and_slide()

	# Player got too close for too long → chase
	if dist_to_player < 4.0:
		stalk_close_timer += delta
		if stalk_close_timer > 3.0:
			_enter_state(State.CHASE)
			return
	else:
		stalk_close_timer = maxf(stalk_close_timer - delta, 0.0)

	# After stalk duration
	if stalker_timer >= STALK_DURATION:
		if _check_line_of_sight() and dist_to_player < 10.0:
			_enter_state(State.CHASE)
		else:
			_enter_state(State.PATROL)

# ══════════════════════════════════════════════════════════════
# PATHFINDING (A* on maze grid)
# ══════════════════════════════════════════════════════════════

func _find_path_to_cell(target_pos: Vector3):
	var cell_size = generator.CELL_SIZE
	var mx = int(floor(global_position.x / cell_size))
	var mz = int(floor(global_position.z / cell_size))
	var tx = int(floor(target_pos.x / cell_size))
	var tz = int(floor(target_pos.z / cell_size))
	var cols = generator.MAZE_COLS
	var rows = generator.MAZE_ROWS
	mx = clampi(mx, 0, cols - 1)
	mz = clampi(mz, 0, rows - 1)
	tx = clampi(tx, 0, cols - 1)
	tz = clampi(tz, 0, rows - 1)
	_find_path(Vector2i(mx, mz), Vector2i(tx, tz))

func _find_path(start: Vector2i, goal: Vector2i):
	if not generator:
		return
	var grid = generator.grid
	var cols = generator.MAZE_COLS
	var rows = generator.MAZE_ROWS

	if start == goal:
		path.clear()
		return

	var open_set: Array[Vector2i] = [start]
	var came_from := {}
	var g_score := {start: 0.0}
	var f_score := {start: _heuristic(start, goal)}

	while open_set.size() > 0:
		var current = open_set[0]
		var current_f = f_score.get(current, INF)
		for i in range(1, open_set.size()):
			var f = f_score.get(open_set[i], INF)
			if f < current_f:
				current_f = f
				current = open_set[i]

		if current == goal:
			path.clear()
			var node = goal
			while came_from.has(node):
				path.push_front(node)
				node = came_from[node]
			current_path_idx = 0
			return

		open_set.erase(current)

		var dirs = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		for d_idx in range(4):
			if not grid[current.y][current.x][d_idx]:
				var neighbor = current + dirs[d_idx]
				if neighbor.x < 0 or neighbor.x >= cols or neighbor.y < 0 or neighbor.y >= rows:
					continue
				var tentative_g = g_score.get(current, INF) + 1.0
				if tentative_g < g_score.get(neighbor, INF):
					came_from[neighbor] = current
					g_score[neighbor] = tentative_g
					f_score[neighbor] = tentative_g + _heuristic(neighbor, goal)
					if neighbor not in open_set:
						open_set.append(neighbor)

	path.clear()

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)

# ══════════════════════════════════════════════════════════════
# PATH FOLLOWING
# ══════════════════════════════════════════════════════════════

func _pick_patrol_target():
	if not generator:
		return
	var cols = generator.MAZE_COLS
	var rows = generator.MAZE_ROWS
	var cell_size = generator.CELL_SIZE
	var mx = int(floor(global_position.x / cell_size))
	var mz = int(floor(global_position.z / cell_size))
	mx = clampi(mx, 0, cols - 1)
	mz = clampi(mz, 0, rows - 1)
	var start = Vector2i(mx, mz)
	var attempts = 0
	var target = start
	while target == start and attempts < 20:
		target = Vector2i(patrol_rng.randi() % cols, patrol_rng.randi() % rows)
		attempts += 1
	_find_path(start, target)

func _follow_path(delta, speed: float):
	if path.size() == 0 or current_path_idx >= path.size():
		if state == State.CHASE:
			_find_path_to_cell(last_known_player_pos)
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		if player:
			_face_toward(player.global_position, delta)
		return

	var cell_size = generator.CELL_SIZE
	var grid = generator.grid
	var cols = generator.MAZE_COLS
	var rows = generator.MAZE_ROWS

	var target_cell = path[current_path_idx]
	var target_pos = Vector3(
		target_cell.x * cell_size + cell_size * 0.5,
		global_position.y,
		target_cell.y * cell_size + cell_size * 0.5
	)

	# Current cell
	var mx = int(floor(global_position.x / cell_size))
	var mz = int(floor(global_position.z / cell_size))
	mx = clampi(mx, 0, cols - 1)
	mz = clampi(mz, 0, rows - 1)

	# Reached waypoint?
	var to_target = target_pos - global_position
	to_target.y = 0
	if to_target.length() < 0.6:
		current_path_idx += 1
		if current_path_idx >= path.size():
			velocity.x = 0
			velocity.z = 0
			return
		target_cell = path[current_path_idx]
		target_pos = Vector3(
			target_cell.x * cell_size + cell_size * 0.5,
			global_position.y,
			target_cell.y * cell_size + cell_size * 0.5
		)
		to_target = target_pos - global_position
		to_target.y = 0

	if to_target.length() < 0.05:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	# Constrain to grid axes — align to corridor center before crossing
	var dx = absf(to_target.x)
	var dz = absf(to_target.z)
	var move_axis_x := false

	if dx > dz:
		var corridor_z = mz * cell_size + cell_size * 0.5
		var z_off = global_position.z - corridor_z
		if absf(z_off) > 0.15:
			velocity.z = signf(z_off) * -1.0 * speed
			velocity.x = 0
			move_and_slide()
			_face_toward(target_pos, delta)
			return
		move_axis_x = true
	else:
		var corridor_x = mx * cell_size + cell_size * 0.5
		var x_off = global_position.x - corridor_x
		if absf(x_off) > 0.15:
			velocity.x = signf(x_off) * -1.0 * speed
			velocity.z = 0
			move_and_slide()
			_face_toward(target_pos, delta)
			return
		move_axis_x = false

	# Check wall clearance
	var cell = grid[mz][mx]
	if move_axis_x:
		velocity.z = 0
		if to_target.x > 0 and not cell[1]:
			velocity.x = speed
		elif to_target.x < 0 and not cell[3]:
			velocity.x = -speed
		else:
			velocity.x = 0
	else:
		velocity.x = 0
		if to_target.z > 0 and not cell[2]:
			velocity.z = speed
		elif to_target.z < 0 and not cell[0]:
			velocity.z = -speed
		else:
			velocity.z = 0

	_face_toward(target_pos, delta)
	move_and_slide()

func _face_toward(target: Vector3, delta: float):
	var dir = target - global_position
	dir.y = 0
	if dir.length() > 0.1:
		var target_angle = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * 5.0)

# ══════════════════════════════════════════════════════════════
# SEARCH PATTERN
# ══════════════════════════════════════════════════════════════

func _generate_search_pattern():
	search_cells.clear()
	var cell_size = generator.CELL_SIZE
	var center_x = int(floor(last_known_player_pos.x / cell_size))
	var center_z = int(floor(last_known_player_pos.z / cell_size))
	var center = Vector2i(
		clampi(center_x, 0, generator.MAZE_COLS - 1),
		clampi(center_z, 0, generator.MAZE_ROWS - 1)
	)
	# Spiral outward from last known cell
	for radius in range(1, 5):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if abs(dx) == radius or abs(dz) == radius:
					var cell = Vector2i(center.x + dx, center.y + dz)
					if cell.x >= 0 and cell.x < generator.MAZE_COLS and cell.y >= 0 and cell.y < generator.MAZE_ROWS:
						search_cells.append(cell)
	# Prioritize cells closer to where the player is now
	var player_cell = Vector2i(
		clampi(int(floor(player.global_position.x / cell_size)), 0, generator.MAZE_COLS - 1),
		clampi(int(floor(player.global_position.z / cell_size)), 0, generator.MAZE_ROWS - 1)
	)
	search_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _heuristic(a, player_cell) < _heuristic(b, player_cell)
	)

# ══════════════════════════════════════════════════════════════
# ATTACK
# ══════════════════════════════════════════════════════════════

func _perform_attack():
	if not player or attack_timer > 0.0:
		return
	attack_timer = ATTACK_COOLDOWN_MAX
	if audio_mgr:
		audio_mgr.play_hit()
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)
	# Push player back
	if player is CharacterBody3D:
		var push_dir = (player.global_position - global_position).normalized()
		push_dir.y = 0
		(player as CharacterBody3D).velocity += push_dir * 8.0 + Vector3.UP * 2.0

func _perform_attack_berserk():
	if not player:
		return
	attack_timer = ATTACK_COOLDOWN_MAX * 0.6
	if audio_mgr:
		audio_mgr.play_hit()
	if player.has_method("take_damage"):
		player.take_damage(attack_damage * 1.5)
	if player is CharacterBody3D:
		var push_dir = (player.global_position - global_position).normalized()
		push_dir.y = 0
		(player as CharacterBody3D).velocity += push_dir * 12.0 + Vector3.UP * 3.0

# ══════════════════════════════════════════════════════════════
# DAMAGE & DEATH
# ══════════════════════════════════════════════════════════════

func take_damage(amount: float):
	if dead:
		return
	damage_taken += amount
	# Flash red
	if body_mesh and body_mesh.material_override:
		var mat = body_mesh.material_override as StandardMaterial3D
		var orig_color = mat.albedo_color
		mat.albedo_color = Color(1, 0, 0)
		var t = create_tween()
		t.tween_property(mat, "albedo_color", orig_color, 0.3)
	# Alert if idle/patrol
	if state == State.IDLE or state == State.PATROL:
		_enter_state(State.ALERT)

func die():
	dead = true
	velocity = Vector3.ZERO

# ══════════════════════════════════════════════════════════════
# ANIMATION
# ══════════════════════════════════════════════════════════════

func _animate(_delta):
	var t = Time.get_ticks_msec() * 0.003
	# Body bob
	if body_mesh:
		body_mesh.position.y = 0.8 + sin(t) * 0.05
	if head_mesh:
		head_mesh.position.y = 1.7 + sin(t) * 0.05
	# Arm swing — faster during chase
	var arm_speed_mult = 1.0
	if state == State.CHASE or state == State.BERSERK:
		arm_speed_mult = 2.0
	if left_arm:
		left_arm.rotation.x = sin(t * 2.0 * arm_speed_mult) * 0.4
		left_arm.position.y = 0.7 + sin(t) * 0.05
	if right_arm:
		right_arm.rotation.x = sin(t * 2.0 * arm_speed_mult + PI) * 0.4
		right_arm.position.y = 0.7 + sin(t) * 0.05
	# Eye flicker — more intense during chase
	var flicker_threshold = -0.8
	if state == State.CHASE:
		flicker_threshold = -0.5
	elif state == State.BERSERK:
		flicker_threshold = 0.0  # eyes always on
	if left_eye:
		left_eye.visible = sin(t * 8.0) > flicker_threshold
	if right_eye:
		right_eye.visible = sin(t * 8.0) > flicker_threshold
	# Glow pulse
	if glow_light and state != State.BERSERK:
		glow_light.light_energy = 1.5 + sin(t * 1.5) * 0.5
