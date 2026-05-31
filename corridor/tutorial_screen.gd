extends CanvasLayer

var _bg: ColorRect

func _ready():
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.0, 0.0, 0.0, 0.92)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Title
	var title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	title.text = "操作教学"
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.08
	title.anchor_bottom = 0.08
	title.offset_left = -200
	title.offset_right = 200
	title.offset_top = -20
	title.offset_bottom = 20
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(title)

	# Divider
	var divider = ColorRect.new()
	divider.anchor_left = 0.3
	divider.anchor_right = 0.7
	divider.anchor_top = 0.15
	divider.anchor_bottom = 0.15
	divider.offset_top = 0
	divider.offset_bottom = 2
	divider.color = Color(0.6, 0.15, 0.15, 0.6)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(divider)

	var controls := [
		["W A S D", "移动"],
		["Shift", "冲刺"],
		["Ctrl", "蹲下"],
		["Space", "跳跃"],
		["鼠标移动", "视角转动"],
		["鼠标滚轮", "缩放视角"],
		["F", "手电筒开关"],
		["N", "夜视仪开关"],
		["Q", "终极技能"],
		["ESC", "暂停菜单"],
	]

	var start_y := 0.2
	var spacing := 0.06

	for i in controls.size():
		var key_label = Label.new()
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key_label.add_theme_font_size_override("font_size", 20)
		key_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		key_label.text = controls[i][0]
		key_label.anchor_left = 0.3
		key_label.anchor_right = 0.48
		key_label.anchor_top = start_y + i * spacing
		key_label.anchor_bottom = start_y + i * spacing
		key_label.offset_top = -15
		key_label.offset_bottom = 15
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg.add_child(key_label)

		var desc_label = Label.new()
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc_label.add_theme_font_size_override("font_size", 20)
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		desc_label.text = controls[i][1]
		desc_label.anchor_left = 0.52
		desc_label.anchor_right = 0.7
		desc_label.anchor_top = start_y + i * spacing
		desc_label.anchor_bottom = start_y + i * spacing
		desc_label.offset_top = -15
		desc_label.offset_bottom = 15
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg.add_child(desc_label)

	# Tip text
	var tip = Label.new()
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 16)
	tip.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	tip.text = "找到出口即可逃离，注意迷宫会定期重构！"
	tip.anchor_left = 0.5
	tip.anchor_right = 0.5
	tip.anchor_top = 0.85
	tip.anchor_bottom = 0.85
	tip.offset_left = -300
	tip.offset_right = 300
	tip.offset_top = -15
	tip.offset_bottom = 15
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(tip)

	# Start button
	var start_btn = Button.new()
	start_btn.text = "开始游戏"
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.anchor_left = 0.5
	start_btn.anchor_right = 0.5
	start_btn.anchor_top = 0.92
	start_btn.anchor_bottom = 0.92
	start_btn.offset_left = -100
	start_btn.offset_right = 100
	start_btn.offset_top = -25
	start_btn.offset_bottom = 25
	start_btn.pressed.connect(_on_start)
	_bg.add_child(start_btn)

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_start():
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Tell the player mouse is captured
	var player = get_tree().current_scene.get_node_or_null("Player")
	if player:
		player.mouse_captured = true
	queue_free()
