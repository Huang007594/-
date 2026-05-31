extends CanvasLayer

var _bg: ColorRect

func _ready():
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0, 0, 0, 0.75)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Title
	var title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	title.text = "暂停"
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.3
	title.anchor_bottom = 0.3
	title.offset_left = -100
	title.offset_right = 100
	title.offset_top = -30
	title.offset_bottom = 30
	_bg.add_child(title)

	# Continue button
	var continue_btn = Button.new()
	continue_btn.text = "继续游戏"
	continue_btn.anchor_left = 0.5
	continue_btn.anchor_right = 0.5
	continue_btn.anchor_top = 0.45
	continue_btn.anchor_bottom = 0.45
	continue_btn.offset_left = -100
	continue_btn.offset_right = 100
	continue_btn.offset_top = -20
	continue_btn.offset_bottom = 20
	continue_btn.add_theme_font_size_override("font_size", 18)
	continue_btn.pressed.connect(_on_resume)
	continue_btn.pressed.connect(func(): AudioManager.play_select())
	continue_btn.focus_entered.connect(func(): AudioManager.play_slide())
	_bg.add_child(continue_btn)

	# Return to menu button
	var menu_btn = Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.anchor_left = 0.5
	menu_btn.anchor_right = 0.5
	menu_btn.anchor_top = 0.55
	menu_btn.anchor_bottom = 0.55
	menu_btn.offset_left = -100
	menu_btn.offset_right = 100
	menu_btn.offset_top = -20
	menu_btn.offset_bottom = 20
	menu_btn.add_theme_font_size_override("font_size", 18)
	menu_btn.pressed.connect(_on_quit)
	menu_btn.pressed.connect(func(): AudioManager.play_select())
	menu_btn.focus_entered.connect(func(): AudioManager.play_slide())
	_bg.add_child(menu_btn)

	_bg.visible = false

func show_pause():
	_bg.visible = true

func hide_pause():
	_bg.visible = false

func _on_resume():
	var player = get_tree().current_scene.get_node_or_null("Player")
	if player:
		player._toggle_scene_pause()

func _on_quit():
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://splash_screen.tscn")
