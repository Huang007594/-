extends Node3D

# ── Maze config ──
const CELL_SIZE := 5.0
const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 0.3
var MAZE_COLS := 15
var MAZE_ROWS := 15
const RENDER_MARGIN := 5  # increased from 3 for better visibility

# Map transition
var CHANGE_INTERVAL := 30.0
var change_timer := 0.0
var change_count := 0
var exit_cell := Vector2i(MAZE_COLS - 1, MAZE_ROWS - 1)
var maze_changed := false

# Maze data
var grid := []
var visited_cells := {}
var player: Node3D
var last_player_cell := Vector2i(-99, -99)
var rng := RandomNumberGenerator.new()

# Visual nodes
var wall_nodes := {}
var floor_nodes := {}
var detail_nodes := []

# Monster
var monster: CharacterBody3D
var monster_node: Node3D

# Traps
var trap_nodes := []
var trap_cells := {}

# Teleport nodes (hard mode only, invisible)
var teleport_nodes := []
const TELEPORT_DENSITY := 0.08  # ~8% of cells get a teleport node

var _t_was_pressed := false
var audio_mgr: Node
var TRAP_DENSITY := 0.25  # ~25% of cells get a trap

# Countdown UI
var countdown_canvas: CanvasLayer
var countdown_label: Label
var warning_label: Label
var restructure_flash: ColorRect
var restructure_text: Label
var flash_timer := 0.0
const FLASH_DUR := 1.2
var restructure_feedback_active := false

# Colors
var wall_colors := [
	Color(0.35, 0.33, 0.3),
	Color(0.4, 0.35, 0.28),
	Color(0.3, 0.32, 0.35),
	Color(0.38, 0.3, 0.25),
]
var floor_colors := [
	Color(0.2, 0.2, 0.21),
	Color(0.18, 0.19, 0.2),
	Color(0.22, 0.21, 0.19),
]

func _ready():
	rng.randomize()
	player = get_node("Player")
	# Apply difficulty settings
	MAZE_COLS = DifficultyManager.maze_cols
	MAZE_ROWS = DifficultyManager.maze_rows
	CHANGE_INTERVAL = DifficultyManager.change_interval
	TRAP_DENSITY = DifficultyManager.trap_density
	exit_cell = Vector2i(MAZE_COLS - 1, MAZE_ROWS - 1)
	_generate_maze()
	_build_maze_visual()
	_spawn_traps()
	_spawn_teleports()
	_reveal_around_start()
	_update_visibility()
	if DifficultyManager.has_monster:
		_spawn_monster()
	# Setup audio
	audio_mgr = AudioManager
	# Connect audio to player
	if player.has_method("set"):
		player.set("audio_mgr", audio_mgr)
	# Connect audio to monster
	if monster and is_instance_valid(monster):
		monster.set("audio_mgr", audio_mgr)
	# Setup countdown UI
	_setup_countdown_ui.call_deferred()
	# Show tutorial overlay
	_show_tutorial.call_deferred()

func _setup_countdown_ui():
	var scene_root = get_tree().current_scene
	countdown_canvas = CanvasLayer.new()
	countdown_canvas.layer = 80
	scene_root.add_child(countdown_canvas)

	# Countdown label — top right
	countdown_label = Label.new()
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	countdown_label.add_theme_font_size_override("font_size", 18)
	countdown_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.85))
	countdown_label.anchor_left = 1.0
	countdown_label.anchor_right = 1.0
	countdown_label.offset_left = -220
	countdown_label.offset_right = -30
	countdown_label.offset_top = 20
	countdown_label.offset_bottom = 50
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_canvas.add_child(countdown_label)

	# Warning label — center screen, hidden by default
	warning_label = Label.new()
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 24)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1, 0.0))
	warning_label.text = "警告：迷宫结构即将重构"
	warning_label.anchor_left = 0.5
	warning_label.anchor_right = 0.5
	warning_label.anchor_top = 0.5
	warning_label.anchor_bottom = 0.5
	warning_label.offset_left = -200
	warning_label.offset_right = 200
	warning_label.offset_top = -40
	warning_label.offset_bottom = 10
	warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_canvas.add_child(warning_label)

	# Restructure flash overlay
	restructure_flash = ColorRect.new()
	restructure_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	restructure_flash.color = Color(0.8, 0.15, 0.05, 0.0)
	restructure_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_canvas.add_child(restructure_flash)

	# Restructure text — center
	restructure_text = Label.new()
	restructure_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restructure_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	restructure_text.add_theme_font_size_override("font_size", 32)
	restructure_text.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1, 0.0))
	restructure_text.text = "迷宫已重构"
	restructure_text.anchor_left = 0.5
	restructure_text.anchor_right = 0.5
	restructure_text.anchor_top = 0.5
	restructure_text.anchor_bottom = 0.5
	restructure_text.offset_left = -150
	restructure_text.offset_right = 150
	restructure_text.offset_top = -20
	restructure_text.offset_bottom = 30
	restructure_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_canvas.add_child(restructure_text)

func _show_tutorial():
	var tutorial_res = load("res://tutorial_screen.tscn")
	if tutorial_res:
		var tutorial = tutorial_res.instantiate()
		add_child(tutorial)

func _process(delta):
	# Map change timer
	change_timer += delta
	if change_timer >= CHANGE_INTERVAL:
		change_timer = 0.0
		_trigger_map_change()

	# Countdown UI
	var remaining = CHANGE_INTERVAL - change_timer
	if countdown_label:
		countdown_label.text = "迷宫重构倒计时 %ds" % int(ceil(remaining))
		# Color shift: white → orange → red as time runs out
		if remaining <= 10.0:
			countdown_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1, 0.95))
			countdown_label.add_theme_font_size_override("font_size", 22)
		elif remaining <= 20.0:
			countdown_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1, 0.9))
			countdown_label.add_theme_font_size_override("font_size", 20)
		else:
			countdown_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.85))
			countdown_label.add_theme_font_size_override("font_size", 18)

	# Warning at 10s — flash
	if warning_label:
		if remaining <= 10.0 and remaining > 0.0:
			var pulse = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
			warning_label.modulate.a = 0.5 + pulse * 0.5
		else:
			warning_label.modulate.a = 0.0

	# Restructure flash feedback
	if restructure_feedback_active:
		flash_timer -= delta
		var t = clampf(flash_timer / FLASH_DUR, 0.0, 1.0)
		# Flash: peak at start then fade
		var flash_alpha = t * t * 0.4
		restructure_flash.color = Color(0.8, 0.15, 0.05, flash_alpha)
		restructure_text.modulate.a = t * 0.9
		if flash_timer <= 0.0:
			restructure_feedback_active = false
			restructure_flash.color = Color(0.8, 0.15, 0.05, 0.0)
			restructure_text.modulate.a = 0.0

	# Update visible cells
	var px = int(floor(player.global_position.x / CELL_SIZE))
	var pz = int(floor(player.global_position.z / CELL_SIZE))
	var cell = Vector2i(clampi(px, 0, MAZE_COLS-1), clampi(pz, 0, MAZE_ROWS-1))
	if cell != last_player_cell:
		last_player_cell = cell
		visited_cells[cell] = true
		# Reveal neighboring cells too
		for dr in range(-2, 3):
			for dc in range(-2, 3):
				var nc = Vector2i(cell.x + dc, cell.y + dr)
				if nc.x >= 0 and nc.x < MAZE_COLS and nc.y >= 0 and nc.y < MAZE_ROWS:
					visited_cells[nc] = true
		_update_visibility()

		# Teleport cooldown tick
		for area in teleport_nodes:
			if is_instance_valid(area):
				var cd = area.get_meta("cooldown")
				if cd > 0.0:
					area.set_meta("cooldown", maxf(cd - delta, 0.0))

	# Check exit
	if cell == exit_cell:
		_on_exit_reached()

	# Debug: press T to force spawn monster (once per press)
	if Input.is_key_pressed(KEY_T) and not _t_was_pressed:
		_t_was_pressed = true
		_trigger_monster()
	elif not Input.is_key_pressed(KEY_T):
		_t_was_pressed = false

# ══════════════════════════════════════════════════════════════
# MAZE GENERATION
# ══════════════════════════════════════════════════════════════

func _generate_maze():
	grid.clear()
	for r in range(MAZE_ROWS):
		var row := []
		for c in range(MAZE_COLS):
			row.append([true, true, true, true])
		grid.append(row)

	var stack := [Vector2i(0, 0)]
	var carved := {}
	carved[Vector2i(0, 0)] = true

	while stack.size() > 0:
		var cur = stack[-1]
		var neighbors := _get_unvisited_neighbors(cur, carved)
		if neighbors.size() == 0:
			stack.pop_back()
		else:
			var next = neighbors[rng.randi() % neighbors.size()]
			_remove_wall(cur, next)
			carved[next] = true
			stack.append(next)

	_add_loops(0.35)

func _get_unvisited_neighbors(cell: Vector2i, carved: Dictionary) -> Array:
	var result := []
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for d in dirs:
		var n = cell + d
		if n.x >= 0 and n.x < MAZE_COLS and n.y >= 0 and n.y < MAZE_ROWS:
			if not carved.has(n):
				result.append(n)
	return result

func _remove_wall(a: Vector2i, b: Vector2i):
	var dx = b.x - a.x
	var dy = b.y - a.y
	if dx == 1:
		grid[a.y][a.x][1] = false; grid[b.y][b.x][3] = false
	elif dx == -1:
		grid[a.y][a.x][3] = false; grid[b.y][b.x][1] = false
	elif dy == 1:
		grid[a.y][a.x][2] = false; grid[b.y][b.x][0] = false
	elif dy == -1:
		grid[a.y][a.x][0] = false; grid[b.y][b.x][2] = false

func _add_loops(chance: float):
	for r in range(MAZE_ROWS):
		for c in range(MAZE_COLS):
			if rng.randf() < chance:
				var wall_idx = rng.randi() % 4
				var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
				var neighbor = Vector2i(c, r) + dirs[wall_idx]
				if neighbor.x >= 0 and neighbor.x < MAZE_COLS and neighbor.y >= 0 and neighbor.y < MAZE_ROWS:
					grid[r][c][wall_idx] = false
					grid[neighbor.y][neighbor.x][(wall_idx + 2) % 4] = false

# ══════════════════════════════════════════════════════════════
# MAP CHANGE
# ══════════════════════════════════════════════════════════════

func _trigger_map_change():
	change_count += 1
	_clear_visuals()
	_generate_maze()
	_build_maze_visual()
	_spawn_traps()
	_spawn_teleports()
	# Reveal only around start after map change
	visited_cells.clear()
	_reveal_around_start()
	_update_visibility()
	maze_changed = true
	_reset_monster()
	if audio_mgr:
		audio_mgr.play_map_change()
	# Restructure visual feedback
	restructure_feedback_active = true
	flash_timer = FLASH_DUR

func _reveal_around_start():
	# Only reveal a small area around the starting cell (0, 0)
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var nc = Vector2i(dc, dr)
			if nc.x >= 0 and nc.x < MAZE_COLS and nc.y >= 0 and nc.y < MAZE_ROWS:
				visited_cells[nc] = true
	maze_changed = false

func _clear_visuals():
	for key in wall_nodes:
		wall_nodes[key].queue_free()
	for key in floor_nodes:
		floor_nodes[key].queue_free()
	for node in detail_nodes:
		if is_instance_valid(node):
			node.queue_free()
	for node in trap_nodes:
		if is_instance_valid(node):
			node.queue_free()
	wall_nodes.clear()
	floor_nodes.clear()
	detail_nodes.clear()
	trap_nodes.clear()
	trap_cells.clear()
	for node in teleport_nodes:
		if is_instance_valid(node):
			node.queue_free()
	teleport_nodes.clear()

func _on_exit_reached():
	player.trigger_evacuation()
	# Wait for evacuation animation to finish, then show ending
	var timer = get_tree().create_timer(3.5)
	timer.timeout.connect(_on_evac_finished)

func _on_evac_finished():
	player.finish_escape()
	var ending = get_node_or_null("EndingScreen")
	if ending and ending.has_method("show_ending"):
		ending.show_ending()

# ══════════════════════════════════════════════════════════════
# BUILD VISUALS - using MeshInstance3D + StaticBody3D for reliable collision
# ══════════════════════════════════════════════════════════════

func _make_wall(pos: Vector3, size: Vector3, col: Color) -> Node3D:
	# Create a StaticBody3D with a box collision shape for reliable collision
	var body = StaticBody3D.new()
	body.position = pos

	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	col_shape.shape = box_shape
	body.add_child(col_shape)

	# Visual mesh
	var mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	mesh.material_override = mat
	body.add_child(mesh)

	add_child(body)
	return body

func _make_floor(pos: Vector3, size: Vector3, col: Color) -> Node3D:
	var body = StaticBody3D.new()
	body.position = pos

	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	col_shape.shape = box_shape
	body.add_child(col_shape)

	var mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	mesh.material_override = mat
	body.add_child(mesh)

	add_child(body)
	return body

func _make_decoration(pos: Vector3, size: Vector3, col: Color) -> Node3D:
	# Decorations without collision (debris, pipes, etc.)
	var mesh = MeshInstance3D.new()
	mesh.position = pos
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	mesh.material_override = mat
	add_child(mesh)
	return mesh

func _make_exit_beam():
	var beam_x = exit_cell.x * CELL_SIZE
	var beam_z = exit_cell.y * CELL_SIZE
	var beam_height = WALL_HEIGHT - 0.2

	# Tall glowing cylinder — visible from far away
	var beam = MeshInstance3D.new()
	beam.position = Vector3(beam_x, beam_height / 2.0, beam_z)
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.5
	cyl.height = beam_height
	beam.mesh = cyl
	var beam_mat = StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.1, 1.0, 0.3, 0.5)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(0.1, 1.0, 0.3)
	beam_mat.emission_energy_multiplier = 4.0
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = beam_mat
	add_child(beam)
	detail_nodes.append(beam)

	# Outer glow ring at base
	var ring = MeshInstance3D.new()
	ring.position = Vector3(beam_x, 0.06, beam_z)
	var torus = CylinderMesh.new()
	torus.top_radius = 1.2
	torus.bottom_radius = 1.2
	torus.height = 0.04
	ring.mesh = torus
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.1, 1.0, 0.3, 0.4)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.1, 1.0, 0.3)
	ring_mat.emission_energy_multiplier = 3.0
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	add_child(ring)
	detail_nodes.append(ring)

	# Strong green spotlight pointing up through beam
	var spot = SpotLight3D.new()
	spot.position = Vector3(beam_x, 0.3, beam_z)
	spot.rotation.x = deg_to_rad(180)
	spot.light_color = Color(0.2, 1.0, 0.4)
	spot.light_energy = 5.0
	spot.spot_range = 12.0
	spot.spot_angle = 35.0
	spot.spot_angle_attenuation = 2.0
	add_child(spot)
	detail_nodes.append(spot)

	# Top glow light — illuminates ceiling area
	var top_light = OmniLight3D.new()
	top_light.position = Vector3(beam_x, WALL_HEIGHT - 0.5, beam_z)
	top_light.light_color = Color(0.2, 1.0, 0.3)
	top_light.light_energy = 3.0
	top_light.omni_range = 12.0
	add_child(top_light)
	detail_nodes.append(top_light)

func _make_light(pos: Vector3, energy: float = 1.5, light_range: float = 10.0, color: Color = Color(1, 0.85, 0.6)) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.position = pos
	l.light_energy = energy
	l.light_color = color
	l.omni_range = light_range
	add_child(l)
	return l

func _build_maze_visual():
	var half_cell = CELL_SIZE / 2.0
	var wall_len = CELL_SIZE + WALL_THICKNESS

	for r in range(MAZE_ROWS):
		for c in range(MAZE_COLS):
			var cx = c * CELL_SIZE
			var cz = r * CELL_SIZE
			var cell = grid[r][c]

			# Floor
			var floor_key = "%d_%d" % [c, r]
			var fc = floor_colors[rng.randi() % floor_colors.size()]
			floor_nodes[floor_key] = _make_floor(Vector3(cx, 0, cz), Vector3(CELL_SIZE, 0.1, CELL_SIZE), fc)

			# North wall
			if cell[0]:
				var key = "n_%d_%d" % [c, r]
				var wc = wall_colors[rng.randi() % wall_colors.size()]
				wall_nodes[key] = _make_wall(Vector3(cx, WALL_HEIGHT / 2.0, cz - half_cell), Vector3(wall_len, WALL_HEIGHT, WALL_THICKNESS), wc)

			# East wall
			if cell[1]:
				var key = "e_%d_%d" % [c, r]
				var wc = wall_colors[rng.randi() % wall_colors.size()]
				wall_nodes[key] = _make_wall(Vector3(cx + half_cell, WALL_HEIGHT / 2.0, cz), Vector3(WALL_THICKNESS, WALL_HEIGHT, wall_len), wc)

			# South wall (last row only)
			if r == MAZE_ROWS - 1 and cell[2]:
				var key = "s_%d_%d" % [c, r]
				wall_nodes[key] = _make_wall(Vector3(cx, WALL_HEIGHT / 2.0, cz + half_cell), Vector3(wall_len, WALL_HEIGHT, WALL_THICKNESS), Color(0.32, 0.3, 0.27))

			# West wall (last col only)
			if c == MAZE_COLS - 1 and cell[3]:
				var key = "w_%d_%d" % [c, r]
				wall_nodes[key] = _make_wall(Vector3(cx - half_cell, WALL_HEIGHT / 2.0, cz), Vector3(WALL_THICKNESS, WALL_HEIGHT, wall_len), Color(0.32, 0.3, 0.27))

	# Boundary walls
	_add_boundary_walls()

	# Ceiling
	for r in range(MAZE_ROWS):
		for c in range(MAZE_COLS):
			_make_floor(Vector3(c * CELL_SIZE, WALL_HEIGHT, r * CELL_SIZE), Vector3(CELL_SIZE, 0.1, CELL_SIZE), Color(0.12, 0.11, 0.1))

	# Start marker
	detail_nodes.append(_make_decoration(Vector3(0, 0.06, 0), Vector3(2.0, 0.12, 2.0), Color(0.6, 0.15, 0.1)))

	# Exit marker
	detail_nodes.append(_make_decoration(Vector3(exit_cell.x * CELL_SIZE, 0.06, exit_cell.y * CELL_SIZE), Vector3(2.0, 0.12, 2.0), Color(0.1, 0.6, 0.15)))

	# Exit light
	detail_nodes.append(_make_light(Vector3(exit_cell.x * CELL_SIZE, 2.0, exit_cell.y * CELL_SIZE), 2.0, 8.0, Color(0.2, 1.0, 0.3)))

	# Exit beam — visible from far away
	_make_exit_beam()

	_add_maze_details()

func _add_boundary_walls():
	var total_w = MAZE_COLS * CELL_SIZE
	var total_h = MAZE_ROWS * CELL_SIZE
	var half_cell = CELL_SIZE / 2.0
	var wall_len = CELL_SIZE + WALL_THICKNESS

	for c in range(MAZE_COLS):
		if grid[0][c][0]:
			wall_nodes["bn_%d" % c] = _make_wall(Vector3(c * CELL_SIZE, WALL_HEIGHT / 2.0, -half_cell), Vector3(wall_len, WALL_HEIGHT, WALL_THICKNESS), Color(0.3, 0.28, 0.25))
	for c in range(MAZE_COLS):
		if grid[MAZE_ROWS - 1][c][2]:
			wall_nodes["bs_%d" % c] = _make_wall(Vector3(c * CELL_SIZE, WALL_HEIGHT / 2.0, total_h - half_cell), Vector3(wall_len, WALL_HEIGHT, WALL_THICKNESS), Color(0.3, 0.28, 0.25))
	for r in range(MAZE_ROWS):
		if grid[r][0][3]:
			wall_nodes["bw_%d" % r] = _make_wall(Vector3(-half_cell, WALL_HEIGHT / 2.0, r * CELL_SIZE), Vector3(WALL_THICKNESS, WALL_HEIGHT, wall_len), Color(0.3, 0.28, 0.25))
	for r in range(MAZE_ROWS):
		if grid[r][MAZE_COLS - 1][1]:
			wall_nodes["be_%d" % r] = _make_wall(Vector3(total_w - half_cell, WALL_HEIGHT / 2.0, r * CELL_SIZE), Vector3(WALL_THICKNESS, WALL_HEIGHT, wall_len), Color(0.3, 0.28, 0.25))

func _add_maze_details():
	var hc = CELL_SIZE / 2.0
	for r in range(MAZE_ROWS):
		for c in range(MAZE_COLS):
			var cx = c * CELL_SIZE
			var cz = r * CELL_SIZE

			# Random lights
			if rng.randf() < 0.25:
				detail_nodes.append(_make_light(Vector3(cx + rng.randf_range(-1.5, 1.5), WALL_HEIGHT - 0.3, cz + rng.randf_range(-1.5, 1.5)), rng.randf_range(0.5, 1.8), rng.randf_range(5, 9)))

			# Random debris (no collision)
			if rng.randf() < 0.15:
				var dx = cx + rng.randf_range(-1.5, 1.5)
				var dz = cz + rng.randf_range(-1.5, 1.5)
				var ds = rng.randf_range(0.1, 0.35)
				detail_nodes.append(_make_decoration(Vector3(dx, ds / 2 + 0.05, dz), Vector3(ds, ds * 0.6, ds * rng.randf_range(0.5, 2)), Color(0.25, 0.22, 0.18)))

			# Pipes on walls
			if rng.randf() < 0.12:
				var side = -1 if rng.randf() < 0.5 else 1
				var pipe_x = cx + side * (hc - 0.15)
				detail_nodes.append(_make_decoration(Vector3(pipe_x, rng.randf_range(0.5, 2.0), cz), Vector3(0.06, 0.06, CELL_SIZE * 0.8), Color(0.4, 0.25, 0.15)))

# ══════════════════════════════════════════════════════════════
# TRAPS & MONSTER
# ══════════════════════════════════════════════════════════════

func _spawn_traps():
	trap_nodes.clear()
	trap_cells.clear()
	for r in range(MAZE_ROWS):
		for c in range(MAZE_COLS):
			# Don't place traps on start cell or exit cell
			if c == 0 and r == 0:
				continue
			if c == exit_cell.x and r == exit_cell.y:
				continue
			if rng.randf() < TRAP_DENSITY:
				var cell = Vector2i(c, r)
				_create_trap(cell)

func _create_trap(cell: Vector2i):
	var cx = cell.x * CELL_SIZE
	var cz = cell.y * CELL_SIZE

	# Visual — bright red glowing circle on the floor
	var trap_mesh = MeshInstance3D.new()
	trap_mesh.position = Vector3(cx, 0.08, cz)
	var circle = CylinderMesh.new()
	circle.top_radius = 0.8
	circle.bottom_radius = 0.8
	circle.height = 0.05
	trap_mesh.mesh = circle
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.1, 0.05, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.1, 0.05)
	mat.emission_energy_multiplier = 1.5
	trap_mesh.material_override = mat
	add_child(trap_mesh)

	# Red light above trap
	var trap_light = OmniLight3D.new()
	trap_light.position = Vector3(cx, 0.5, cz)
	trap_light.light_color = Color(1.0, 0.15, 0.1)
	trap_light.light_energy = 0.6
	trap_light.omni_range = 3.0
	add_child(trap_light)

	# Area3D detection
	var area = Area3D.new()
	area.position = Vector3(cx, 0.5, cz)
	area.collision_layer = 0
	area.collision_mask = 2  # detect player on layer 2
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.2, 1.0, 1.2)
	col_shape.shape = box
	area.add_child(col_shape)
	# Store cell reference for identification
	area.set_meta("trap_cell", cell)
	area.set_meta("triggered", false)
	area.set_meta("trap_mesh", trap_mesh)
	area.body_entered.connect(_on_trap_body_entered.bind(area))
	add_child(area)

	trap_nodes.append(trap_mesh)
	trap_nodes.append(trap_light)
	trap_nodes.append(area)
	trap_cells[cell] = true

func _on_trap_body_entered(body: Node3D, area: Area3D):
	if body != player:
		return
	if area.get_meta("triggered"):
		return
	area.set_meta("triggered", true)

	# Fade out trap visual
	var trap_mesh = area.get_meta("trap_mesh")
	if trap_mesh and is_instance_valid(trap_mesh):
		var mat = trap_mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(0.4, 0.08, 0.06, 0.2)
			mat.emission_energy_multiplier = 0.0

	# Trigger monster!
	_trigger_monster()
	# Screen feedback
	if player.has_method("trigger_trap_hit"):
		player.trigger_trap_hit()

func _trigger_monster():
	if not DifficultyManager.has_monster:
		return
	if monster and is_instance_valid(monster):
		# Spawn monster near the player — try same cell first, then adjacent
		var player_cell = last_player_cell
		var spawn_cell = _find_adjacent_cell(player_cell)
		monster.global_position = Vector3(spawn_cell.x * CELL_SIZE + CELL_SIZE * 0.5, 0.0, spawn_cell.y * CELL_SIZE + CELL_SIZE * 0.5)
		monster.visible = true
		monster.init(self, player)
		# Chase immediately — the trap already confirmed proximity
		monster.start_chase()

# ══════════════════════════════════════════════════════════════
# TELEPORT NODES (hard mode, invisible)
# ══════════════════════════════════════════════════════════════

func _spawn_teleports():
	for node in teleport_nodes:
		if is_instance_valid(node):
			node.queue_free()
	teleport_nodes.clear()
	if DifficultyManager.current_difficulty != DifficultyManager.Difficulty.HARD:
		return
	for r in range(MAZE_ROWS):
		for c in range(MAZE_COLS):
			if c == 0 and r == 0:
				continue
			if c == exit_cell.x and r == exit_cell.y:
				continue
			if trap_cells.has(Vector2i(c, r)):
				continue
			if rng.randf() < TELEPORT_DENSITY:
				_create_teleport_node(Vector2i(c, r))

func _create_teleport_node(cell: Vector2i):
	var cx = cell.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz = cell.y * CELL_SIZE + CELL_SIZE * 0.5

	# Invisible Area3D — no visual, no light
	var area = Area3D.new()
	area.position = Vector3(cx, 0.5, cz)
	area.collision_layer = 0
	area.collision_mask = 2
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2.0, 1.5, 2.0)
	col_shape.shape = box
	area.add_child(col_shape)
	area.set_meta("cooldown", 0.0)
	area.body_entered.connect(_on_teleport_body_entered.bind(area))
	add_child(area)
	teleport_nodes.append(area)

func _on_teleport_body_entered(body: Node3D, area: Area3D):
	if body != player:
		return
	# Cooldown to prevent instant re-teleport
	var cd = area.get_meta("cooldown")
	if cd > 0.0:
		return
	area.set_meta("cooldown", 3.0)

	# Pick a random cell that isn't start/exit/occupied by trap
	var attempts = 0
	var target_cell := Vector2i(MAZE_COLS / 2, MAZE_ROWS / 2)
	while attempts < 30:
		target_cell = Vector2i(rng.randi() % MAZE_COLS, rng.randi() % MAZE_ROWS)
		if target_cell == Vector2i(0, 0):
			attempts += 1
			continue
		if target_cell == exit_cell:
			attempts += 1
			continue
		break
	var target_pos = Vector3(target_cell.x * CELL_SIZE + CELL_SIZE * 0.5, 0.5, target_cell.y * CELL_SIZE + CELL_SIZE * 0.5)
	player.global_position = target_pos
	player.velocity = Vector3.ZERO
	# Screen feedback
	if player.has_method("trigger_teleport_flash"):
		player.trigger_teleport_flash()

func _find_nearby_cell(target: Vector2i) -> Vector2i:
	# Find a cell 3-5 steps away from the target
	var dirs = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var best_cell = target
	var best_dist = 0.0
	for r in range(MAZE_ROWS):
		for c in range(MAZE_COLS):
			var cell = Vector2i(c, r)
			var dist = abs(c - target.x) + abs(r - target.y)
			if dist >= 3 and dist <= 5 and dist > best_dist:
				if trap_cells.has(cell) or _cell_has_passage(cell, target):
					best_dist = dist
					best_cell = cell
	if best_dist == 0.0:
		return _find_far_cell()
	return best_cell

func _find_adjacent_cell(target: Vector2i) -> Vector2i:
	# Find a cell 1-2 steps away, with no wall between it and the player cell
	var grid_data = grid
	var dirs = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var candidates: Array[Vector2i] = []
	for r in range(MAZE_ROWS):
		for c in range(MAZE_COLS):
			var cell = Vector2i(c, r)
			var dist = abs(c - target.x) + abs(r - target.y)
			if dist >= 1 and dist <= 2:
				candidates.append(cell)
	if candidates.size() == 0:
		return target
	# Prefer cells that are reachable (no wall blocking)
	var reachable: Array[Vector2i] = []
	for cell in candidates:
		# Check if there's a passage from target towards cell
		var dx = cell.x - target.x
		var dy = cell.y - target.y
		var can_reach = false
		if dx == 1 and not grid_data[target.y][target.x][1]:
			can_reach = true
		elif dx == -1 and not grid_data[target.y][target.x][3]:
			can_reach = true
		elif dy == 1 and not grid_data[target.y][target.x][2]:
			can_reach = true
		elif dy == -1 and not grid_data[target.y][target.x][0]:
			can_reach = true
		if can_reach:
			reachable.append(cell)
	if reachable.size() > 0:
		return reachable[randi() % reachable.size()]
	return candidates[randi() % candidates.size()]

func _cell_has_passage(from: Vector2i, to: Vector2i) -> bool:
	# Simple check: just return true, A* will handle actual pathfinding
	return true

func _spawn_monster():
	var monster_script = load("res://monster.gd")
	monster = CharacterBody3D.new()
	monster.set_script(monster_script)
	monster.name = "Monster"
	add_child(monster)

	# Random type each spawn
	var types = [0, 1, 2]  # STALKER, SPRINTER, AMBUSHER
	monster.set_monster_type(types[randi() % types.size()])

	# Apply difficulty multipliers after type sets base values
	_apply_monster_difficulty()

	# Place monster at far end of maze, visible and chasing
	monster.global_position = Vector3((MAZE_COLS - 2) * CELL_SIZE + CELL_SIZE * 0.5, 0.0, (MAZE_ROWS - 2) * CELL_SIZE + CELL_SIZE * 0.5)
	monster.visible = true
	monster.init(self, player)
	monster.start_chase()

func _reset_monster():
	if not DifficultyManager.has_monster:
		return
	if monster and is_instance_valid(monster):
		monster.dead = false
		# Re-randomize type on map change
		var types = [0, 1, 2]
		monster.set_monster_type(types[randi() % types.size()])
		_apply_monster_difficulty()
		monster.global_position = Vector3((MAZE_COLS - 2) * CELL_SIZE + CELL_SIZE * 0.5, 0.0, (MAZE_ROWS - 2) * CELL_SIZE + CELL_SIZE * 0.5)
		monster.visible = true
		monster.init(self, player)
		monster.start_chase()

func _apply_monster_difficulty():
	if not monster or not is_instance_valid(monster):
		return
	monster.patrol_speed *= DifficultyManager.monster_speed_mult
	monster.chase_speed *= DifficultyManager.monster_speed_mult
	monster.alert_speed *= DifficultyManager.monster_speed_mult
	monster.search_speed *= DifficultyManager.monster_speed_mult
	monster.berserk_speed *= DifficultyManager.monster_speed_mult
	monster.stalker_speed *= DifficultyManager.monster_speed_mult
	monster.attack_damage *= DifficultyManager.monster_damage_mult
	monster.vision_range *= DifficultyManager.monster_vision_mult
	monster.hearing_range_sprint *= DifficultyManager.monster_vision_mult
	monster.hearing_range_walk *= DifficultyManager.monster_vision_mult

func _find_far_cell() -> Vector2i:
	var best_cell := Vector2i(MAZE_COLS / 2, MAZE_ROWS / 2)
	var best_dist := 0.0
	for r in range(MAZE_ROWS):
		for c in range(MAZE_COLS):
			var dist = abs(c) + abs(r)  # distance from start (0,0)
			if dist > best_dist:
				best_dist = dist
				best_cell = Vector2i(c, r)
	return best_cell

# ══════════════════════════════════════════════════════════════
# VISIBILITY
# ══════════════════════════════════════════════════════════════

func _update_visibility():
	var pc = last_player_cell
	for r in range(MAZE_ROWS):
		for c in range(MAZE_COLS):
			var cell = Vector2i(c, r)
			var dist = abs(c - pc.x) + abs(r - pc.y)
			var visible = dist <= RENDER_MARGIN or visited_cells.has(cell)
			var floor_key = "%d_%d" % [c, r]
			if floor_nodes.has(floor_key):
				floor_nodes[floor_key].visible = visible
			for prefix in ["n_", "e_", "s_", "w_"]:
				var key = "%s%d_%d" % [prefix, c, r]
				if wall_nodes.has(key):
					wall_nodes[key].visible = visible

	# Boundary walls
	for c in range(MAZE_COLS):
		var vis = abs(c - pc.x) + abs(0 - pc.y) <= RENDER_MARGIN or visited_cells.has(Vector2i(c, 0))
		if wall_nodes.has("bn_%d" % c): wall_nodes["bn_%d" % c].visible = vis
	for c in range(MAZE_COLS):
		var vis = abs(c - pc.x) + abs((MAZE_ROWS-1) - pc.y) <= RENDER_MARGIN or visited_cells.has(Vector2i(c, MAZE_ROWS-1))
		if wall_nodes.has("bs_%d" % c): wall_nodes["bs_%d" % c].visible = vis
	for r in range(MAZE_ROWS):
		var vis = abs(0 - pc.x) + abs(r - pc.y) <= RENDER_MARGIN or visited_cells.has(Vector2i(0, r))
		if wall_nodes.has("bw_%d" % r): wall_nodes["bw_%d" % r].visible = vis
	for r in range(MAZE_ROWS):
		var vis = abs((MAZE_COLS-1) - pc.x) + abs(r - pc.y) <= RENDER_MARGIN or visited_cells.has(Vector2i(MAZE_COLS-1, r))
		if wall_nodes.has("be_%d" % r): wall_nodes["be_%d" % r].visible = vis
