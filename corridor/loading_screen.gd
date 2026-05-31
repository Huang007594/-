extends CanvasLayer

const GAME_SCENE: String = "res://corridor.tscn"

@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var tips_label: Label = $CenterContainer/VBoxContainer/TipsLabel

var is_loading: bool = false
var pulse_timer: float = 0.0

func _ready() -> void:
	# Style the progress bar
	var style_bg := StyleBoxFlat.new()
	style_bg.bg_color = Color(0.12, 0.12, 0.12, 1)
	style_bg.border_color = Color(0.25, 0.25, 0.25, 1)
	style_bg.set_border_width_all(1)
	style_bg.set_corner_radius_all(2)
	style_bg.set_content_margin_all(0)
	progress_bar.add_theme_stylebox_override("background", style_bg)

	var style_fill := StyleBoxFlat.new()
	style_fill.bg_color = Color(0.6, 0.15, 0.15, 1)
	style_fill.set_corner_radius_all(2)
	style_fill.set_content_margin_all(0)
	progress_bar.add_theme_stylebox_override("fill", style_fill)

	ResourceLoader.load_threaded_request(GAME_SCENE)
	is_loading = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	if not is_loading:
		return

	pulse_timer += delta
	status_label.modulate.a = 0.5 + 0.5 * sin(pulse_timer * 3.0)

	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			status_label.text = "准备就绪..."
			is_loading = false
			await get_tree().create_timer(0.3).timeout
			var packed_scene: PackedScene = ResourceLoader.load_threaded_get(GAME_SCENE)
			get_tree().change_scene_to_packed(packed_scene)

		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.value = progress[0] * 100.0
			status_label.text = "加载中... %d%%" % int(progress[0] * 100)

		ResourceLoader.THREAD_LOAD_FAILED:
			status_label.text = "加载失败！"
			is_loading = false
