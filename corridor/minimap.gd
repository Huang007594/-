extends CanvasLayer

const GRID_COLS := 11
const GRID_ROWS := 11
const CELL_PX := 10.0
const PADDING := 6.0
const BG_COLOR := Color(0.05, 0.05, 0.08, 0.75)
const WALL_COLOR := Color(0.55, 0.5, 0.42, 0.9)
const FLOOR_VISITED := Color(0.28, 0.27, 0.25, 0.9)
const FLOOR_UNEXPLORED := Color(0.06, 0.06, 0.08, 0.5)
const PLAYER_COLOR := Color(1.0, 0.85, 0.2)
const EXIT_COLOR := Color(0.2, 1.0, 0.3)
const EXIT_GLOW_COLOR := Color(0.2, 1.0, 0.3, 0.3)
const START_COLOR := Color(1.0, 0.3, 0.2)
const WALL_THICKNESS := 1.5
const MONSTER_COLOR := Color(1.0, 0.1, 0.1, 0.9)
const TRAP_COLOR := Color(0.6, 0.1, 0.05, 0.6)

var _generator: Node = null
var _player: Node3D = null
var _control: Control
var _last_rotation := 0.0

func _ready():
	layer = 10
	_generator = get_parent()
	_player = get_parent().get_node("Player")

	var map_size = GRID_COLS * CELL_PX + PADDING * 2

	_control = Control.new()
	_control.custom_minimum_size = Vector2(map_size, map_size)
	_control.position = Vector2(12, 12)
	_control.draw.connect(_draw_minimap)
	add_child(_control)

func _process(_delta):
	if _player:
		_last_rotation = _player.rotation.y
	_control.queue_redraw()

func _draw_minimap():
	if not _generator or not _player:
		return

	var grid: Array = _generator.grid
	var visited: Dictionary = _generator.visited_cells
	var exit_cell: Vector2i = _generator.exit_cell
	var player_pos := _player.global_position
	var player_cell_x := int(floor(player_pos.x / 5.0))
	var player_cell_z := int(floor(player_pos.z / 5.0))

	var total_w := GRID_COLS * CELL_PX + PADDING * 2
	var total_h := GRID_ROWS * CELL_PX + PADDING * 2

	# Background
	_control.draw_rect(Rect2(0, 0, total_w, total_h), BG_COLOR)

	# Border
	_control.draw_rect(Rect2(0, 0, total_w, total_h), Color(0.3, 0.28, 0.25, 0.5), false, 1.0)

	# Cells
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			var x := PADDING + c * CELL_PX
			var y := PADDING + r * CELL_PX
			var cell := Vector2i(c, r)

			if visited.has(cell):
				_control.draw_rect(Rect2(x, y, CELL_PX, CELL_PX), FLOOR_VISITED)
			else:
				_control.draw_rect(Rect2(x, y, CELL_PX, CELL_PX), FLOOR_UNEXPLORED)

	# Start and exit markers
	if visited.has(Vector2i(0, 0)):
		_control.draw_rect(Rect2(PADDING + 1, PADDING + 1, CELL_PX - 2, CELL_PX - 2), START_COLOR)
	if visited.has(exit_cell):
		# Glow behind exit
		_control.draw_rect(
			Rect2(PADDING + exit_cell.x * CELL_PX - 1, PADDING + exit_cell.y * CELL_PX - 1, CELL_PX + 2, CELL_PX + 2),
			EXIT_GLOW_COLOR
		)
		_control.draw_rect(
			Rect2(PADDING + exit_cell.x * CELL_PX + 1, PADDING + exit_cell.y * CELL_PX + 1, CELL_PX - 2, CELL_PX - 2),
			EXIT_COLOR
		)

	# Walls
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			if not visited.has(Vector2i(c, r)):
				continue
			var x := PADDING + c * CELL_PX
			var y := PADDING + r * CELL_PX
			var cell = grid[r][c]

			if cell[0]:  # North
				_control.draw_line(Vector2(x, y), Vector2(x + CELL_PX, y), WALL_COLOR, WALL_THICKNESS)
			if cell[1]:  # East
				_control.draw_line(Vector2(x + CELL_PX, y), Vector2(x + CELL_PX, y + CELL_PX), WALL_COLOR, WALL_THICKNESS)
			if cell[2] and r == GRID_ROWS - 1:  # South (last row)
				_control.draw_line(Vector2(x, y + CELL_PX), Vector2(x + CELL_PX, y + CELL_PX), WALL_COLOR, WALL_THICKNESS)
			if cell[3] and c == GRID_COLS - 1:  # West (last col)
				_control.draw_line(Vector2(x, y), Vector2(x, y + CELL_PX), WALL_COLOR, WALL_THICKNESS)

	# Player position and direction
	var px := PADDING + player_cell_x * CELL_PX + CELL_PX / 2.0
	var py := PADDING + player_cell_z * CELL_PX + CELL_PX / 2.0

	var dir := Vector2(sin(_last_rotation), cos(_last_rotation)).normalized()
	var tip := Vector2(px, py) + dir * CELL_PX * 0.8
	var left_w := dir.rotated(2.5) * CELL_PX * 0.35
	var right_w := dir.rotated(-2.5) * CELL_PX * 0.35

	_control.draw_colored_polygon(
		PackedVector2Array([tip, Vector2(px, py) + left_w, Vector2(px, py) + right_w]),
		PLAYER_COLOR
	)

	# Trap markers on visited cells
	if "trap_cells" in _generator:
		var trap_cells: Dictionary = _generator.trap_cells
		for cell in trap_cells:
			if visited.has(cell) and trap_cells[cell]:
				var tx: float = PADDING + float(cell.x) * CELL_PX + CELL_PX / 2.0
				var ty: float = PADDING + float(cell.y) * CELL_PX + CELL_PX / 2.0
				_control.draw_circle(Vector2(tx, ty), 2.0, TRAP_COLOR)

	# Monster dot (only when visible)
	if "monster" in _generator and _generator.monster and is_instance_valid(_generator.monster):
		var mon = _generator.monster
		if mon.visible and mon.chasing:
			var mon_cell_x := int(floor(mon.global_position.x / 5.0))
			var mon_cell_z := int(floor(mon.global_position.z / 5.0))
			if mon_cell_x >= 0 and mon_cell_x < GRID_COLS and mon_cell_z >= 0 and mon_cell_z < GRID_ROWS:
				var mx: float = PADDING + float(mon_cell_x) * CELL_PX + CELL_PX / 2.0
				var my: float = PADDING + float(mon_cell_z) * CELL_PX + CELL_PX / 2.0
				_control.draw_circle(Vector2(mx, my), 3.0, MONSTER_COLOR)
