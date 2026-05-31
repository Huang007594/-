extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/SubtitleLabel
@onready var version_label: Label = $CenterContainer/VBoxContainer/VersionLabel
@onready var prompt_label: Label = $CenterContainer/VBoxContainer/PromptLabel

var bg_texture: TextureRect
var phase: int = 0  # 0=fade_in, 1=wait_input, 2=fade_out
var timer: float = 0.0
var fade_duration: float = 1.5
var prompt_alpha: float = 0.0
var can_input: bool = false

func _ready() -> void:
	# Setup background image
	bg_texture = TextureRect.new()
	var path = ProjectSettings.globalize_path("res://start_bg.png")
	var img = Image.load_from_file(path)
	if img:
		bg_texture.texture = ImageTexture.create_from_image(img)
	else:
		push_warning("Failed to load start_bg.png from " + path)
	bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_texture.modulate.a = 0.0
	add_child(bg_texture)
	move_child(bg_texture, 0)  # behind everything

	# Semi-transparent overlay on top of image
	overlay.color = Color(0, 0, 0, 0.35)

	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	version_label.modulate.a = 0.0
	prompt_label.modulate.a = 0.0
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	timer += delta

	match phase:
		0:  # Fade in
			var t: float = clampf(timer / fade_duration, 0.0, 1.0)
			title_label.modulate.a = t
			subtitle_label.modulate.a = t * 0.7
			version_label.modulate.a = t * 0.5
			if bg_texture:
				bg_texture.modulate.a = t
			if timer >= fade_duration:
				phase = 1
				timer = 0.0
				can_input = true
		1:  # Wait for input — pulse prompt
			prompt_alpha = 0.4 + 0.4 * sin(timer * 2.5)
			prompt_label.modulate.a = prompt_alpha
		2:  # Fade out
			var t: float = clampf(timer / fade_duration, 0.0, 1.0)
			title_label.modulate.a = 1.0 - t
			subtitle_label.modulate.a = (1.0 - t) * 0.7
			version_label.modulate.a = (1.0 - t) * 0.5
			prompt_label.modulate.a = (1.0 - t) * 0.5
			if bg_texture:
				bg_texture.modulate.a = 1.0 - t
			if timer >= fade_duration:
				phase = 3
				get_tree().change_scene_to_file("res://loading_screen.tscn")

func _input(event: InputEvent) -> void:
	if not can_input:
		return
	if event is InputEventKey and event.pressed:
		can_input = false
		phase = 2
		timer = 0.0
	elif event is InputEventMouseButton and event.pressed:
		can_input = false
		phase = 2
		timer = 0.0
