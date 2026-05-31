extends CharacterBody3D

const BASE_WALK_SPEED = 4.5
const BASE_SPRINT_SPEED = 7.0
const BASE_CROUCH_SPEED = 2.0
var WALK_SPEED := 4.5
var SPRINT_SPEED := 7.0
var CROUCH_SPEED := 2.0
const SENSITIVITY = 0.003
const HEAD_BOB_SPEED = 8.0
const HEAD_BOB_AMOUNT = 0.03
const LERP_SPEED = 10.0
const CROUCH_DEPTH = 0.5
const JUMP_VELOCITY = 5.0

var gravity = 9.8
var mouse_captured = false
var speed = WALK_SPEED
var head_bob_timer = 0.0
var standing_height = 1.7
var crouching = false

# Drop intro
var dropping := false
var drop_start_y := 25.0
var drop_camera_tilt := 0.0
var drop_landed := false
var drop_land_timer := 0.0
var drop_elapsed := 0.0
const DROP_LAND_SHAKE_DUR := 0.4
const DROP_LAND_SHAKE_INT := 0.06
const DROP_TIMEOUT := 2.0

# Health
var MAX_HEALTH := 75.0
var current_health := MAX_HEALTH
var health_regen_rate := 1.0  # HP/sec
var health_regen_delay := 3.0  # seconds after last hit before regen starts
var last_damage_time := -999.0
var health_bar: ProgressBar
var health_bar_fill: StyleBoxFlat
var health_bar_bg_panel: Panel
var health_label: Label
var health_hit_overlay: ColorRect
var health_hit_alpha := 0.0
var health_pulse_timer := 0.0

# Death / fall
const DEATH_Y_THRESHOLD := -8.0
const DEATH_FADE_IN_DUR := 1.5
const DEATH_HOLD_DUR := 1.0
const DEATH_FADE_OUT_DUR := 1.0
var is_dead := false
var death_timer := 0.0
var death_phase := 0  # 0=red_flash, 1=shake+fade, 2=hold, 3=fade_out, 4=respawn
var death_overlay: ColorRect
var death_label: Label
var death_sublabel: Label
var death_red_flash: ColorRect
var death_vignette: ColorRect
var death_shake_dur := 0.5
var death_shake_timer := 0.0
var spawn_pos := Vector3(2.5, 0.5, 2.5)

# Evacuation success
var is_evacuating := false
var evac_image: TextureRect
var evac_label: Label

# Trap hit feedback
var trap_hit_alpha := 0.0
var trap_hit_overlay: ColorRect
var trap_hit_shake_dur := 0.3
var trap_hit_shake_timer := 0.0

# Teleport flash feedback
var teleport_flash_alpha := 0.0
var teleport_flash_overlay: ColorRect

# Pause menu — handled by scene PauseMenu node
var pause_menu_ref: Node

# Audio
var audio_mgr: Node = AudioManager

# Ultimate ability
var ultimate_cooldown = 0.0
var ultimate_duration = 0.0
var ultimate_active = false
var ultimate_light: OmniLight3D
var original_camera_pos: Vector3
const ULTIMATE_COOLDOWN_MAX = 3.0
const ULTIMATE_SHAKE_DUR = 0.35
const ULTIMATE_LIFETIME = 3.0
const ULTIMATE_LAUNCH_FORCE = 30.0
const ULTIMATE_SPAWN_FWD = 1.0
# Ultimate UI
var ultimate_cd_label: Label
var ultimate_cd_panel: Panel
# Night vision
var nightvision_active := false
var nightvision_overlay: ColorRect
var nightvision_label: Label
var nightvision_transition_speed := 3.0
var nightvision_current := 0.0
# Night vision battery
var nv_battery := 100.0
const NV_BATTERY_MAX := 100.0
const NV_DRAIN_RATE := 8.0  # %/sec when active
const NV_REGEN_RATE := 15.0  # %/sec when off
var nv_battery_bar: ProgressBar
var nv_battery_label: Label
var nv_battery_bg: Panel

var GOLD_COLOR = Color(1.0, 0.8, 0.2)
var GOLD_EMISSION = Color(1.0, 0.55, 0.0)
var TRAIL_COLOR_START = Color(1.0, 0.7, 0.1, 0.7)
var TRAIL_COLOR_END = Color(1.0, 0.4, 0.0, 0.0)

@onready var head = $Camera3D
@onready var standing_collision = $CollisionShape
@onready var ray_cast = $RayCast3D if has_node("RayCast3D") else null
@onready var flashlight = $Camera3D/Flashlight if has_node("Camera3D/Flashlight") else null

# Zoom
var zoom_fov := 75.0
const ZOOM_FOV_MIN := 20.0
const ZOOM_FOV_MAX := 90.0
const ZOOM_STEP := 5.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true
	floor_snap_length = 0.3
	head.fov = zoom_fov
	# Apply difficulty
	MAX_HEALTH = DifficultyManager.player_max_health
	current_health = MAX_HEALTH
	var sm = DifficultyManager.player_speed_mult
	WALK_SPEED = BASE_WALK_SPEED * sm
	SPRINT_SPEED = BASE_SPRINT_SPEED * sm
	CROUCH_SPEED = BASE_CROUCH_SPEED * sm
	_setup_ultimate()
	_setup_death_overlay.call_deferred()
	_setup_evac_overlay.call_deferred()
	_setup_nightvision.call_deferred()
	_setup_nightvision_battery_ui.call_deferred()
	_setup_health_ui.call_deferred()
	_setup_trap_hit_overlay.call_deferred()
	_setup_teleport_flash.call_deferred()
	_setup_ultimate_ui.call_deferred()
	dropping = false
	drop_landed = true

func _setup_death_overlay():
	# Create on the scene root so it layers above everything, not just the player
	var scene_root = get_tree().current_scene
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	scene_root.add_child(canvas)

	# Red flash overlay — bright red that fades out
	death_red_flash = ColorRect.new()
	death_red_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_red_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	death_red_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(death_red_flash)

	# Vignette overlay — dark edges effect
	death_vignette = ColorRect.new()
	death_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_vignette.material = _create_vignette_material()
	death_vignette.color = Color(1, 1, 1, 0.0)
	canvas.add_child(death_vignette)

	# Fullscreen black overlay — fades from transparent to opaque
	death_overlay = ColorRect.new()
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.color = Color(0, 0, 0, 0)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(death_overlay)

	# Death message
	death_label = Label.new()
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 48)
	death_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0))
	death_label.text = "你坠落了"
	death_label.set_anchors_preset(Control.PRESET_CENTER)
	death_label.position.y -= 30
	death_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(death_label)

	death_sublabel = Label.new()
	death_sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_sublabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_sublabel.add_theme_font_size_override("font_size", 18)
	death_sublabel.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0))
	death_sublabel.text = "正在重新苏醒..."
	death_sublabel.set_anchors_preset(Control.PRESET_CENTER)
	death_sublabel.position.y += 30
	death_sublabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(death_sublabel)

func _create_vignette_material() -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = SCREEN_UV;
	float dist = distance(uv, vec2(0.5));
	float vignette = smoothstep(0.3, 0.85, dist);
	COLOR = vec4(0.1, 0.0, 0.0, vignette * COLOR.a);
}
"""
	var shader = Shader.new()
	shader.code = code
	mat.shader = shader
	return mat

func _setup_evac_overlay():
	var scene_root = get_tree().current_scene
	var canvas = CanvasLayer.new()
	canvas.layer = 101
	scene_root.add_child(canvas)

	# Full screen escape image
	evac_image = TextureRect.new()
	var evac_path = ProjectSettings.globalize_path("res://escape_image.png")
	var evac_img = Image.load_from_file(evac_path)
	if evac_img:
		evac_image.texture = ImageTexture.create_from_image(evac_img)
	else:
		push_warning("Failed to load escape_image.png from " + evac_path)
	evac_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	evac_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	evac_image.modulate.a = 0.0
	evac_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(evac_image)

	# Escape text at bottom
	evac_label = Label.new()
	evac_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evac_label.add_theme_font_size_override("font_size", 42)
	evac_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	evac_label.text = "恭喜逃出来了"
	evac_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	evac_label.position.y -= 60
	evac_label.modulate.a = 0.0
	evac_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(evac_label)

func _setup_nightvision():
	var scene_root = get_tree().current_scene
	var canvas = CanvasLayer.new()
	canvas.layer = 99
	scene_root.add_child(canvas)

	# Shader overlay
	nightvision_overlay = ColorRect.new()
	nightvision_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	nightvision_overlay.color = Color(0, 0, 0, 0)
	nightvision_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_mat = ShaderMaterial.new()
	var nv_shader = load("res://night_vision.gdshader")
	shader_mat.shader = nv_shader
	shader_mat.set_shader_parameter("intensity", 0.0)
	nightvision_overlay.material = shader_mat
	canvas.add_child(nightvision_overlay)

	# Status indicator
	nightvision_label = Label.new()
	nightvision_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nightvision_label.add_theme_font_size_override("font_size", 14)
	nightvision_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0, 0.0))
	nightvision_label.text = "夜视仪 ON"
	nightvision_label.position = Vector2(20, 20)
	nightvision_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(nightvision_label)

func _setup_nightvision_battery_ui():
	var scene_root = get_tree().current_scene
	var canvas = CanvasLayer.new()
	canvas.layer = 98
	scene_root.add_child(canvas)

	# Battery bar background — below nightvision label
	nv_battery_bg = Panel.new()
	nv_battery_bg.anchor_left = 0.0
	nv_battery_bg.anchor_right = 0.0
	nv_battery_bg.anchor_top = 0.0
	nv_battery_bg.anchor_bottom = 0.0
	nv_battery_bg.offset_left = 20
	nv_battery_bg.offset_right = 170
	nv_battery_bg.offset_top = 42
	nv_battery_bg.offset_bottom = 56
	nv_battery_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.05, 0.7)
	bg_style.border_color = Color(0.0, 0.8, 0.2, 0.4)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(2)
	nv_battery_bg.add_theme_stylebox_override("panel", bg_style)
	canvas.add_child(nv_battery_bg)

	# Battery bar
	nv_battery_bar = ProgressBar.new()
	nv_battery_bar.anchor_left = 0.0
	nv_battery_bar.anchor_right = 1.0
	nv_battery_bar.anchor_top = 0.0
	nv_battery_bar.anchor_bottom = 1.0
	nv_battery_bar.offset_left = 2
	nv_battery_bar.offset_right = -2
	nv_battery_bar.offset_top = 2
	nv_battery_bar.offset_bottom = -2
	nv_battery_bar.min_value = 0
	nv_battery_bar.max_value = NV_BATTERY_MAX
	nv_battery_bar.value = nv_battery
	nv_battery_bar.show_percentage = false
	nv_battery_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bar_bg.set_corner_radius_all(1)
	nv_battery_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.0, 0.9, 0.2, 0.8)
	bar_fill.set_corner_radius_all(1)
	nv_battery_bar.add_theme_stylebox_override("fill", bar_fill)

	nv_battery_bg.add_child(nv_battery_bar)

	# Battery text
	nv_battery_label = Label.new()
	nv_battery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv_battery_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nv_battery_label.add_theme_font_size_override("font_size", 10)
	nv_battery_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
	nv_battery_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	nv_battery_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nv_battery_bar.add_child(nv_battery_label)

func _update_nv_battery_ui():
	if not nv_battery_bar:
		return
	nv_battery_bar.value = nv_battery
	nv_battery_label.text = "夜视仪 %d%%" % int(nv_battery)
	# Color: green → orange → red
	var ratio = nv_battery / NV_BATTERY_MAX
	var fill = nv_battery_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		if ratio > 0.5:
			fill.bg_color = Color(0.0, 0.9, 0.2, 0.8)
		elif ratio > 0.2:
			fill.bg_color = Color(0.9, 0.6, 0.0, 0.8)
		else:
			var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
			fill.bg_color = Color(0.9, 0.15, 0.05, 0.6 + pulse * 0.4)

func _setup_health_ui():
	var scene_root = get_tree().current_scene
	var canvas = CanvasLayer.new()
	canvas.layer = 50
	scene_root.add_child(canvas)

	# Health bar background
	health_bar_bg_panel = Panel.new()
	health_bar_bg_panel.anchor_left = 0.0
	health_bar_bg_panel.anchor_right = 0.0
	health_bar_bg_panel.anchor_top = 1.0
	health_bar_bg_panel.anchor_bottom = 1.0
	health_bar_bg_panel.offset_left = 30
	health_bar_bg_panel.offset_right = 290
	health_bar_bg_panel.offset_top = -50
	health_bar_bg_panel.offset_bottom = -28
	health_bar_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	bg_style.border_color = Color(0.25, 0.25, 0.25, 0.6)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	health_bar_bg_panel.add_theme_stylebox_override("panel", bg_style)
	canvas.add_child(health_bar_bg_panel)

	# Health bar
	health_bar = ProgressBar.new()
	health_bar.anchor_left = 0.0
	health_bar.anchor_right = 1.0
	health_bar.anchor_top = 0.0
	health_bar.anchor_bottom = 1.0
	health_bar.offset_left = 2
	health_bar.offset_right = -2
	health_bar.offset_top = 2
	health_bar.offset_bottom = -2
	health_bar.min_value = 0
	health_bar.max_value = MAX_HEALTH
	health_bar.value = current_health
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background (empty part)
	var bg_fill = StyleBoxFlat.new()
	bg_fill.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	bg_fill.set_corner_radius_all(2)
	health_bar.add_theme_stylebox_override("background", bg_fill)

	# Foreground (filled part)
	health_bar_fill = StyleBoxFlat.new()
	health_bar_fill.bg_color = Color(0.7, 0.1, 0.1, 0.9)
	health_bar_fill.set_corner_radius_all(2)
	health_bar.add_theme_stylebox_override("fill", health_bar_fill)

	health_bar_bg_panel.add_child(health_bar)

	# HP text label
	health_label = Label.new()
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 12)
	health_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.9))
	health_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_child(health_label)

	# Damage flash overlay
	health_hit_overlay = ColorRect.new()
	health_hit_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	health_hit_overlay.color = Color(0.6, 0.0, 0.0, 0.0)
	health_hit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(health_hit_overlay)

func _setup_trap_hit_overlay():
	var scene_root = get_tree().current_scene
	var canvas = CanvasLayer.new()
	canvas.layer = 95
	scene_root.add_child(canvas)

	trap_hit_overlay = ColorRect.new()
	trap_hit_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	trap_hit_overlay.color = Color(0.9, 0.1, 0.0, 0.0)
	trap_hit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(trap_hit_overlay)

func trigger_trap_hit():
	trap_hit_alpha = 0.5
	trap_hit_shake_timer = trap_hit_shake_dur
	health_hit_alpha = 0.25
	audio_mgr.play_trap()

func _setup_teleport_flash():
	var scene_root = get_tree().current_scene
	var canvas = CanvasLayer.new()
	canvas.layer = 96
	scene_root.add_child(canvas)

	teleport_flash_overlay = ColorRect.new()
	teleport_flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	teleport_flash_overlay.color = Color(0.3, 0.0, 0.6, 0.0)
	teleport_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(teleport_flash_overlay)

func trigger_teleport_flash():
	teleport_flash_alpha = 0.7

func _setup_ultimate_ui():
	var scene_root = get_tree().current_scene
	var canvas = CanvasLayer.new()
	canvas.layer = 80
	scene_root.add_child(canvas)

	# Big countdown panel — center-bottom of screen
	ultimate_cd_panel = Panel.new()
	ultimate_cd_panel.anchor_left = 0.5
	ultimate_cd_panel.anchor_right = 0.5
	ultimate_cd_panel.anchor_top = 1.0
	ultimate_cd_panel.anchor_bottom = 1.0
	ultimate_cd_panel.offset_left = -80
	ultimate_cd_panel.offset_right = 80
	ultimate_cd_panel.offset_top = -100
	ultimate_cd_panel.offset_bottom = -40
	ultimate_cd_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.08, 0.0, 0.85)
	bg_style.border_color = Color(1.0, 0.7, 0.1, 0.9)
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(6)
	ultimate_cd_panel.add_theme_stylebox_override("panel", bg_style)
	canvas.add_child(ultimate_cd_panel)

	ultimate_cd_label = Label.new()
	ultimate_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ultimate_cd_label.add_theme_font_size_override("font_size", 48)
	ultimate_cd_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	ultimate_cd_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	ultimate_cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_cd_panel.add_child(ultimate_cd_label)

func _update_ultimate_ui():
	if not ultimate_cd_label or not ultimate_cd_panel:
		return
	if ultimate_cooldown > 0.0:
		ultimate_cd_panel.visible = true
		ultimate_cd_label.text = "%.1f" % ultimate_cooldown
		# Pulse color while on cooldown
		var pulse = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
		ultimate_cd_label.add_theme_color_override("font_color", Color(1.0, 0.5 + pulse * 0.35, 0.1 + pulse * 0.1, 1.0))
	elif ultimate_active:
		ultimate_cd_panel.visible = true
		ultimate_cd_label.text = "!"
		ultimate_cd_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1, 1.0))
	else:
		ultimate_cd_panel.visible = true
		ultimate_cd_label.text = "Q"
		ultimate_cd_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))

func _toggle_scene_pause():
	if not pause_menu_ref:
		pause_menu_ref = get_tree().current_scene.get_node_or_null("PauseMenu")
	if not pause_menu_ref:
		return
	if get_tree().paused:
		pause_menu_ref.hide_pause()
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true
	else:
		get_tree().paused = true
		pause_menu_ref.show_pause()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_captured = false

func _update_health_bar():
	if not health_bar:
		return
	health_bar.value = current_health
	health_label.text = "%d / %d" % [int(current_health), int(MAX_HEALTH)]

	# Color gradient: red -> orange -> dark red based on health
	var ratio = current_health / MAX_HEALTH
	if ratio > 0.6:
		health_bar_fill.bg_color = Color(0.65, 0.12, 0.1, 0.9)
	elif ratio > 0.3:
		health_bar_fill.bg_color = Color(0.8, 0.4, 0.05, 0.9)
	else:
		# Pulse when critical
		var pulse = (sin(health_pulse_timer * 6.0) + 1.0) * 0.5
		health_bar_fill.bg_color = Color(0.9, 0.05, 0.0, 0.7 + pulse * 0.3)

func _trigger_death():
	if is_dead:
		return
	is_dead = true
	death_timer = 0.0
	death_phase = 0
	death_shake_timer = death_shake_dur
	death_label.text = "你死了"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false
	audio_mgr.play_death()
	_spawn_death_particles()

func _spawn_death_particles():
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 40
	particles.lifetime = 1.5
	particles.preprocess = 0.1
	particles.global_position = head.global_position

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -3.0, 0)
	mat.scale_min = 0.08
	mat.scale_max = 0.25
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.0))
	mat.scale_curve = scale_curve
	mat.color = Color(0.6, 0.0, 0.0)

	var grad = Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.8, 0.05, 0.0, 0.9),
		Color(0.4, 0.0, 0.0, 0.6),
		Color(0.15, 0.0, 0.0, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var ramp = GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp

	particles.process_material = mat

	# Use a small cube as particle mesh
	var mesh_inst = MeshInstance3D.new()
	var cube = BoxMesh.new()
	cube.size = Vector3(0.06, 0.06, 0.06)
	mesh_inst.mesh = cube
	var mesh_mat = StandardMaterial3D.new()
	mesh_mat.emission_enabled = true
	mesh_mat.emission = Color(0.8, 0.0, 0.0)
	mesh_mat.emission_energy_multiplier = 2.0
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mesh_mat
	particles.draw_pass_1 = mesh_inst.mesh
	particles.material_override = mesh_mat

	get_tree().current_scene.add_child(particles)

	# Auto-cleanup
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)
	particles.add_child(timer)
	timer.start()

func _spawn_evac_particles():
	# Golden/green particle burst at player position
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.amount = 60
	particles.lifetime = 2.0
	particles.preprocess = 0.1
	particles.global_position = global_position + Vector3(0, 1.0, 0)

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.5
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, -1.5, 0)
	mat.scale_min = 0.06
	mat.scale_max = 0.2
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	mat.scale_curve = scale_curve

	var grad = Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 0.9, 0.2, 1.0),
		Color(0.2, 1.0, 0.4, 0.7),
		Color(0.1, 0.8, 0.3, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	var ramp = GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp

	particles.process_material = mat

	var mesh_inst = MeshInstance3D.new()
	var cube = BoxMesh.new()
	cube.size = Vector3(0.05, 0.05, 0.05)
	mesh_inst.mesh = cube
	var mesh_mat = StandardMaterial3D.new()
	mesh_mat.emission_enabled = true
	mesh_mat.emission = Color(0.5, 1.0, 0.3)
	mesh_mat.emission_energy_multiplier = 3.0
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mesh_mat
	particles.draw_pass_1 = mesh_inst.mesh
	particles.material_override = mesh_mat

	get_tree().current_scene.add_child(particles)

	var timer = Timer.new()
	timer.wait_time = 2.5
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)
	particles.add_child(timer)
	timer.start()

func trigger_evacuation():
	if is_evacuating or is_dead:
		return
	is_evacuating = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false
	if evac_image:
		evac_image.modulate.a = 1.0
	if evac_label:
		evac_label.modulate.a = 0.0

func finish_escape():
	if evac_image:
		evac_image.modulate.a = 0.0
	if evac_label:
		evac_label.modulate.a = 1.0
		var timer = get_tree().create_timer(3.0)
		timer.timeout.connect(func():
			if is_instance_valid(evac_label):
				evac_label.modulate.a = 0.0
		)
	is_evacuating = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func take_damage(amount: float):
	if is_dead:
		return
	current_health = maxf(current_health - amount, 0.0)
	last_damage_time = Time.get_ticks_msec() / 1000.0
	health_hit_alpha = 0.35
	_update_health_bar()
	if current_health <= 0.0:
		death_label.text = "你死了"
		_trigger_death()

func heal(amount: float):
	if is_dead:
		return
	current_health = minf(current_health + amount, MAX_HEALTH)
	_update_health_bar()

func _process(delta):
	# Cooldown tick
	if ultimate_cooldown > 0.0:
		ultimate_cooldown -= delta
	_update_ultimate_ui()

	# Camera shake during ultimate
	if ultimate_active:
		ultimate_duration -= delta
		var t = 1.0 - (ultimate_duration / ULTIMATE_SHAKE_DUR)
		var shake = 0.1 * (1.0 - t)
		head.position = original_camera_pos + Vector3(
			randf_range(-shake, shake),
			randf_range(-shake, shake),
			randf_range(-shake, shake)
		)

		# Fade flash light with shake
		ultimate_light.light_energy = lerp(15.0, 0.0, t)

		if ultimate_duration <= 0.0:
			ultimate_active = false
			ultimate_light.light_energy = 0.0
			head.position = original_camera_pos

	# Death overlay animation
	if is_dead:
		death_timer += delta
		match death_phase:
			0:  # Red flash — instant bright red, fades quickly
				var t = clampf(death_timer / 0.3, 0.0, 1.0)
				death_red_flash.color = Color(0.8, 0.0, 0.0, 0.7 * (1.0 - t))
				death_vignette.color = Color(1, 1, 1, t * 0.8)
				head.position = Vector3(
					randf_range(-0.04, 0.04),
					standing_height + randf_range(-0.03, 0.03),
					randf_range(-0.04, 0.04)
				)
				if death_timer >= 0.3:
					death_phase = 1
					death_timer = 0.0
			1:  # Fade in — screen goes dark with vignette
				death_red_flash.color = Color(0.8, 0.0, 0.0, 0.0)
				var t = clampf(death_timer / DEATH_FADE_IN_DUR, 0.0, 1.0)
				var eased = t * t
				death_overlay.color = Color(0, 0, 0, eased * 0.95)
				death_label.modulate.a = eased
				death_sublabel.modulate.a = eased * 0.6
				death_vignette.color = Color(1, 1, 1, 0.8 * (1.0 - eased * 0.5))
				var shake = 0.03 * (1.0 - t)
				head.position = Vector3(
					randf_range(-shake, shake),
					standing_height + randf_range(-shake * 0.5, shake * 0.5),
					randf_range(-shake, shake)
				)
				if death_timer >= DEATH_FADE_IN_DUR:
					death_phase = 2
					death_timer = 0.0
			2:  # Hold — full darkness
				if death_timer >= DEATH_HOLD_DUR:
					death_phase = 3
					death_timer = 0.0
			3:  # Fade out — reveal respawned scene
				var t = clampf(death_timer / DEATH_FADE_OUT_DUR, 0.0, 1.0)
				var eased = 1.0 - (1.0 - t) * (1.0 - t)
				death_overlay.color = Color(0, 0, 0, 0.95 * (1.0 - eased))
				death_label.modulate.a = 1.0 - eased
				death_sublabel.modulate.a = 0.6 * (1.0 - eased)
				death_vignette.color = Color(1, 1, 1, 0.4 * (1.0 - eased))
				if death_timer >= DEATH_FADE_OUT_DUR:
					death_phase = 4
					death_timer = 0.0
					_respawn()
			4:  # Clean up
				death_overlay.color = Color(0, 0, 0, 0)
				death_label.modulate.a = 0.0
				death_sublabel.modulate.a = 0.0
				death_vignette.color = Color(1, 1, 1, 0.0)
				death_red_flash.color = Color(0.8, 0.0, 0.0, 0.0)
				is_dead = false
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				mouse_captured = true


	# Night vision transition
	var nv_target = 1.0 if nightvision_active else 0.0
	nightvision_current = move_toward(nightvision_current, nv_target, delta * nightvision_transition_speed)
	if nightvision_overlay and nightvision_overlay.material:
		nightvision_overlay.material.set_shader_parameter("intensity", nightvision_current)
	if nightvision_label:
		nightvision_label.modulate.a = nightvision_current

	# Night vision battery drain/regen
	if nightvision_active:
		nv_battery = maxf(nv_battery - NV_DRAIN_RATE * delta, 0.0)
		if nv_battery <= 0.0:
			nightvision_active = false
	else:
		nv_battery = minf(nv_battery + NV_REGEN_RATE * delta, NV_BATTERY_MAX)
	_update_nv_battery_ui()

	# Health regen
	if not is_dead and current_health < MAX_HEALTH:
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_damage_time >= health_regen_delay:
			current_health = minf(current_health + health_regen_rate * delta, MAX_HEALTH)
			_update_health_bar()

	# Health bar pulse timer (for low-health effect)
	health_pulse_timer += delta
	if health_bar and current_health / MAX_HEALTH <= 0.3:
		_update_health_bar()

	# Damage flash fade
	if health_hit_alpha > 0.0:
		health_hit_alpha = move_toward(health_hit_alpha, 0.0, delta * 1.5)
		if health_hit_overlay:
			health_hit_overlay.color = Color(0.6, 0.0, 0.0, health_hit_alpha)

	# Trap hit feedback
	if trap_hit_alpha > 0.0:
		trap_hit_alpha = move_toward(trap_hit_alpha, 0.0, delta * 2.0)
		if trap_hit_overlay:
			trap_hit_overlay.color = Color(0.9, 0.1, 0.0, trap_hit_alpha)
	if trap_hit_shake_timer > 0.0:
		trap_hit_shake_timer -= delta
		var t = trap_hit_shake_timer / trap_hit_shake_dur
		var shake = 0.05 * t
		head.position = Vector3(
			randf_range(-shake, shake),
			standing_height + randf_range(-shake * 0.5, shake * 0.5),
			randf_range(-shake, shake)
		)
		if trap_hit_shake_timer <= 0.0:
			head.position = Vector3(0, standing_height, 0)

		# Teleport flash fade
		if teleport_flash_alpha > 0.0:
			teleport_flash_alpha = move_toward(teleport_flash_alpha, 0.0, delta * 2.5)
			if teleport_flash_overlay:
				teleport_flash_overlay.color = Color(0.3, 0.0, 0.6, teleport_flash_alpha)

func _respawn():
	global_position = spawn_pos
	velocity = Vector3.ZERO
	head.rotation.x = 0.0
	head.position = Vector3(0, standing_height, 0)
	dropping = false
	drop_landed = true
	current_health = MAX_HEALTH
	_update_health_bar()

func _start_drop():
	dropping = true
	drop_landed = false
	drop_land_timer = 0.0
	drop_elapsed = 0.0
	global_position.y = drop_start_y
	velocity = Vector3.ZERO
	head.rotation.x = deg_to_rad(-60)

var _cached_fist_mat: StandardMaterial3D
var _cached_fist_core_mat: StandardMaterial3D
var _cached_particle_mat: ParticleProcessMaterial
var _cached_color_ramp: GradientTexture1D

func _get_fist_material() -> StandardMaterial3D:
	if not _cached_fist_mat:
		_cached_fist_mat = StandardMaterial3D.new()
		_cached_fist_mat.albedo_color = GOLD_COLOR
		_cached_fist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cached_fist_mat.emission_enabled = true
		_cached_fist_mat.emission = GOLD_EMISSION
		_cached_fist_mat.emission_energy_multiplier = 3.0
		_cached_fist_mat.metallic = 0.8
		_cached_fist_mat.roughness = 0.2
	return _cached_fist_mat

func _get_fist_core_material() -> StandardMaterial3D:
	if not _cached_fist_core_mat:
		_cached_fist_core_mat = StandardMaterial3D.new()
		_cached_fist_core_mat.albedo_color = Color(1.0, 0.95, 0.7)
		_cached_fist_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cached_fist_core_mat.albedo_color.a = 0.6
		_cached_fist_core_mat.emission_enabled = true
		_cached_fist_core_mat.emission = Color(1.0, 0.9, 0.4)
		_cached_fist_core_mat.emission_energy_multiplier = 8.0
		_cached_fist_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _cached_fist_core_mat

func _get_particle_process_material() -> ParticleProcessMaterial:
	if not _cached_particle_mat:
		_cached_particle_mat = ParticleProcessMaterial.new()
		_cached_particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		_cached_particle_mat.emission_sphere_radius = 0.06
		_cached_particle_mat.direction = Vector3(0, 0, 1)
		_cached_particle_mat.spread = 25.0
		_cached_particle_mat.initial_velocity_min = 0.3
		_cached_particle_mat.initial_velocity_max = 1.0
		_cached_particle_mat.gravity = Vector3(0, -1.0, 0)
		_cached_particle_mat.scale_min = 0.4
		_cached_particle_mat.scale_max = 1.2
		var scale_curve = Curve.new()
		scale_curve.add_point(Vector2(0.0, 1.0))
		scale_curve.add_point(Vector2(1.0, 0.0))
		_cached_particle_mat.scale_curve = scale_curve
		if not _cached_color_ramp:
			var grad = Gradient.new()
			grad.colors = PackedColorArray([TRAIL_COLOR_START, TRAIL_COLOR_END])
			grad.offsets = PackedFloat32Array([0.0, 1.0])
			_cached_color_ramp = GradientTexture1D.new()
			_cached_color_ramp.gradient = grad
		_cached_particle_mat.color_ramp = _cached_color_ramp
	return _cached_particle_mat

func _create_fist_body() -> RigidBody3D:
	var body = RigidBody3D.new()
	body.gravity_scale = 0.0
	body.collision_layer = 2
	body.collision_mask = 1

	# Fist mesh
	var fist = MeshInstance3D.new()
	var hand_mesh = BoxMesh.new()
	hand_mesh.size = Vector3(0.22, 0.18, 0.14)
	fist.mesh = hand_mesh
	fist.material_override = _get_fist_material()
	body.add_child(fist)

	# Inner glow core
	var core = MeshInstance3D.new()
	var core_mesh = BoxMesh.new()
	core_mesh.size = Vector3(0.14, 0.11, 0.09)
	core.mesh = core_mesh
	core.material_override = _get_fist_core_material()
	body.add_child(core)

	# Collision shape
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.22, 0.18, 0.14)
	col.shape = box
	body.add_child(col)

	# Auto-cleanup timer
	var timer = Timer.new()
	timer.wait_time = ULTIMATE_LIFETIME
	timer.one_shot = true
	timer.timeout.connect(_on_fist_timeout.bind(body))
	body.add_child(timer)
	timer.start()

	return body


func _setup_ultimate():
	ultimate_light = OmniLight3D.new()
	ultimate_light.light_color = Color(1.0, 0.8, 0.3)
	ultimate_light.light_energy = 0.0
	ultimate_light.omni_range = 20.0
	head.add_child(ultimate_light)

func _input(event):
	if is_dead or is_evacuating:
		return

	if event is InputEventMouseMotion and mouse_captured:
		rotate_y(-event.relative.x * SENSITIVITY)
		head.rotate_x(-event.relative.y * SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Scroll wheel zoom
	if event is InputEventMouseButton and mouse_captured:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_fov = maxf(ZOOM_FOV_MIN, zoom_fov - ZOOM_STEP)
			head.fov = zoom_fov
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_fov = minf(ZOOM_FOV_MAX, zoom_fov + ZOOM_STEP)
			head.fov = zoom_fov

	if event.is_action_pressed("ui_cancel"):
		_toggle_scene_pause()

	if event.is_action_pressed("toggle_flashlight") and flashlight:
		flashlight.visible = not flashlight.visible
		audio_mgr.play_flashlight(flashlight.visible)

	if event.is_action_pressed("toggle_nightvision"):
		if not nightvision_active and nv_battery <= 0.0:
			pass  # Can't activate with empty battery
		else:
			nightvision_active = not nightvision_active

	if event.is_action_pressed("ultimate") and ultimate_cooldown <= 0.0 and not ultimate_active:
		_activate_ultimate()

	# Debug: press H to take 20 damage, press J to heal 20
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_H:
			take_damage(20.0)
		elif event.physical_keycode == KEY_J:
			heal(20.0)

func _activate_ultimate():
	ultimate_active = true
	ultimate_duration = ULTIMATE_SHAKE_DUR
	ultimate_cooldown = ULTIMATE_COOLDOWN_MAX
	original_camera_pos = head.position

	# Light flash
	ultimate_light.light_energy = 15.0

	# Launch single fist forward in camera direction
	var forward = -head.global_transform.basis.z
	_launch_fist(forward)

	# Knockback nearby monsters
	_knockback_monsters()

const ULTIMATE_KNOCKBACK_RANGE := 12.0
const ULTIMATE_KNOCKBACK_FORCE := 20.0
const ULTIMATE_STUN_DUR := 2.0

func _knockback_monsters():
	var gen = get_tree().current_scene
	if not gen or not gen.has_method("get") or not gen.get("monster"):
		return
	var monster = gen.monster
	if not monster or not is_instance_valid(monster) or monster.dead or not monster.visible:
		return
	var dist = global_position.distance_to(monster.global_position)
	if dist > ULTIMATE_KNOCKBACK_RANGE:
		return
	# Push away from player
	var away = (monster.global_position - global_position)
	away.y = 0
	if away.length() < 0.1:
		away = -head.global_transform.basis.z
		away.y = 0
	away = away.normalized()
	monster.velocity = away * ULTIMATE_KNOCKBACK_FORCE + Vector3.UP * 5.0
	monster.chasing = false
	# Resume chase after stun
	var m = monster
	var timer = get_tree().create_timer(ULTIMATE_STUN_DUR)
	timer.timeout.connect(func():
		if is_instance_valid(m) and not m.dead:
			m.chasing = true
			m.repath_timer = 0.0
	)

func _launch_fist(direction: Vector3):
	var body = _create_fist_body()
	get_tree().current_scene.add_child(body)

	# Spawn position: in front of camera
	var spawn_pos_local = head.global_position
	spawn_pos_local += -head.global_transform.basis.z * ULTIMATE_SPAWN_FWD
	body.global_position = spawn_pos_local

	# Rotate fist to face launch direction
	body.look_at(spawn_pos_local + direction, Vector3.UP)

	# Launch straight forward — fast projectile
	body.linear_velocity = direction * ULTIMATE_LAUNCH_FORCE

func _on_fist_timeout(body: RigidBody3D):
	if is_instance_valid(body):
		body.queue_free()

func _physics_process(delta):
	if is_dead or is_evacuating:
		return

	if dropping:
		_drop_physics(delta)
		return

	# Fall death check
	if global_position.y < DEATH_Y_THRESHOLD:
		_trigger_death()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor() and not crouching:
		velocity.y = JUMP_VELOCITY

	# Crouch toggle
	if Input.is_action_pressed("crouch"):
		if not crouching:
			crouching = true
			if not ultimate_active:
				head.position.y = standing_height - CROUCH_DEPTH
	elif crouching:
		var can_stand = true
		if ray_cast:
			can_stand = not ray_cast.is_colliding()
		if can_stand:
			crouching = false
			if not ultimate_active:
				head.position.y = standing_height

	# Sprint
	if Input.is_action_pressed("sprint") and not crouching and is_on_floor():
		speed = SPRINT_SPEED
	elif crouching:
		speed = CROUCH_SPEED
	else:
		speed = WALK_SPEED

	# Movement
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	input_dir = input_dir.normalized()
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_moving = direction and is_on_floor()
	if is_moving:
		head_bob_timer += delta * HEAD_BOB_SPEED * (speed / WALK_SPEED)
		if not ultimate_active:
			head.position.x = sin(head_bob_timer * 0.5) * HEAD_BOB_AMOUNT
			head.position.y = (standing_height - (CROUCH_DEPTH if crouching else 0.0)) + cos(head_bob_timer) * HEAD_BOB_AMOUNT
	else:
		head_bob_timer = 0.0
		if not ultimate_active:
			head.position.x = 0.0
			head.position.y = lerp(head.position.y, standing_height - (CROUCH_DEPTH if crouching else 0.0), delta * LERP_SPEED)

	if direction:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * LERP_SPEED)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * LERP_SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta * LERP_SPEED)
		velocity.z = move_toward(velocity.z, 0, speed * delta * LERP_SPEED)

	move_and_slide()

func _drop_physics(delta):
	velocity.y -= gravity * delta
	move_and_slide()

	drop_elapsed += delta

	# Force end drop if timeout (e.g. ceiling blocking the fall)
	if drop_elapsed >= DROP_TIMEOUT and not drop_landed:
		drop_landed = true
		drop_land_timer = DROP_LAND_SHAKE_DUR
		global_position.y = 0.5
		velocity = Vector3.ZERO

	if is_on_floor() and not drop_landed:
		# Just landed
		drop_landed = true
		drop_land_timer = DROP_LAND_SHAKE_DUR

	if drop_landed:
		drop_land_timer -= delta
		# Camera shake on landing
		var t = drop_land_timer / DROP_LAND_SHAKE_DUR
		var shake = DROP_LAND_SHAKE_INT * t
		head.position = Vector3(
			randf_range(-shake, shake),
			standing_height + randf_range(-shake * 0.5, shake * 0.5),
			randf_range(-shake, shake)
		)
		# Tilt camera back to level
		head.rotation.x = lerp(head.rotation.x, 0.0, delta * 4.0)

		if drop_land_timer <= 0.0:
			# Drop complete
			dropping = false
			head.position = Vector3(0, standing_height, 0)
			head.rotation.x = 0.0
			velocity = Vector3.ZERO
	else:
		# Still falling — tilt camera to look down more as falling accelerates
		var fall_speed = absf(velocity.y)
		var look_down = lerp(-60.0, -30.0, clampf(fall_speed / 30.0, 0.0, 1.0))
		head.rotation.x = deg_to_rad(look_down)
		# Slight wind tilt
		head.rotation.z = sin(Time.get_ticks_msec() * 0.003) * 0.02
