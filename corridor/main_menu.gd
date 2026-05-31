extends Control

var menu_buttons: VBoxContainer
var settings_panel: VBoxContainer

func _ready() -> void:
	menu_buttons = get_node_or_null("CenterBox/MenuButtons")

	var start_btn := menu_buttons.get_node_or_null("StartButton")
	var settings_btn := menu_buttons.get_node_or_null("SettingsButton")
	var quit_btn := menu_buttons.get_node_or_null("QuitButton")

	if start_btn:
		start_btn.grab_focus()
		start_btn.pressed.connect(_on_start)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit)

	for btn in [start_btn, settings_btn, quit_btn]:
		if btn:
			btn.pressed.connect(func(): AudioManager.play_select())
			btn.focus_entered.connect(func(): AudioManager.play_gear())

	_setup_settings_panel()

func _setup_settings_panel():
	settings_panel = VBoxContainer.new()
	settings_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_panel.add_theme_constant_override("separation", 18)
	settings_panel.visible = false

	var title := Label.new()
	title.text = "游戏设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	settings_panel.add_child(title)

	var diff_label := Label.new()
	diff_label.text = "难度选择"
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.add_theme_font_size_override("font_size", 22)
	diff_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	settings_panel.add_child(diff_label)

	var easy_btn := Button.new()
	easy_btn.text = "简单 — 无怪物，走得快"
	easy_btn.add_theme_font_size_override("font_size", 24)
	easy_btn.custom_minimum_size = Vector2(400, 55)
	easy_btn.pressed.connect(func(): _select_difficulty(DifficultyManager.Difficulty.EASY))
	settings_panel.add_child(easy_btn)

	var medium_btn := Button.new()
	medium_btn.text = "中等 — 有怪物，平衡体验"
	medium_btn.add_theme_font_size_override("font_size", 24)
	medium_btn.custom_minimum_size = Vector2(400, 55)
	medium_btn.pressed.connect(func(): _select_difficulty(DifficultyManager.Difficulty.MEDIUM))
	settings_panel.add_child(medium_btn)

	var hard_btn := Button.new()
	hard_btn.text = "困难 — 怪物追击，走得慢"
	hard_btn.add_theme_font_size_override("font_size", 24)
	hard_btn.custom_minimum_size = Vector2(400, 55)
	hard_btn.pressed.connect(func(): _select_difficulty(DifficultyManager.Difficulty.HARD))
	settings_panel.add_child(hard_btn)

	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.custom_minimum_size = Vector2(300, 50)
	back_btn.pressed.connect(_on_settings_back)
	settings_panel.add_child(back_btn)

	for btn in [easy_btn, medium_btn, hard_btn, back_btn]:
		btn.pressed.connect(func(): AudioManager.play_select())
		btn.focus_entered.connect(func(): AudioManager.play_gear())

	menu_buttons.get_parent().add_child(settings_panel)

func _on_start() -> void:
	# Default medium difficulty, go straight to game
	DifficultyManager.apply_difficulty(DifficultyManager.Difficulty.MEDIUM)
	get_tree().change_scene_to_file("res://loading_screen.tscn")

func _on_settings() -> void:
	menu_buttons.visible = false
	settings_panel.visible = true
	var first_btn = settings_panel.get_child(2)
	if first_btn is Button:
		first_btn.grab_focus()

func _select_difficulty(diff: int) -> void:
	DifficultyManager.apply_difficulty(diff)
	get_tree().change_scene_to_file("res://loading_screen.tscn")

func _on_settings_back() -> void:
	settings_panel.visible = false
	menu_buttons.visible = true
	var settings_btn = menu_buttons.get_node_or_null("SettingsButton")
	if settings_btn:
		settings_btn.grab_focus()

func _on_quit() -> void:
	get_tree().quit()
