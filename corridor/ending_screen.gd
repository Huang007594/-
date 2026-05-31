extends CanvasLayer

signal return_to_main_menu

var ending_label: Label
var bg: ColorRect
var menu_btn: Button

func _ready():
	layer = 154
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	ending_label = Label.new()
	ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ending_label.add_theme_font_size_override("font_size", 48)
	ending_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	ending_label.text = "你成功逃离了"
	ending_label.set_anchors_preset(Control.PRESET_CENTER)
	ending_label.position.y -= 40
	ending_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ending_label)

	menu_btn = Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.add_theme_font_size_override("font_size", 22)
	menu_btn.anchor_left = 0.5
	menu_btn.anchor_right = 0.5
	menu_btn.anchor_top = 0.55
	menu_btn.anchor_bottom = 0.55
	menu_btn.offset_left = -120
	menu_btn.offset_right = 120
	menu_btn.offset_top = -25
	menu_btn.offset_bottom = 25
	menu_btn.pressed.connect(_on_menu_btn)
	menu_btn.visible = false
	add_child(menu_btn)

	hide()

func show_ending():
	# Stop all music
	if AudioManager:
		if AudioManager.music_snd:
			AudioManager.music_snd.stop()
		if AudioManager.drone_snd:
			AudioManager.drone_snd.stop()
	show()
	# Show button after a short delay
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if is_instance_valid(menu_btn):
			menu_btn.visible = true
	)

func _on_menu_btn():
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://splash_screen.tscn")
