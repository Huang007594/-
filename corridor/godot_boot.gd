extends CanvasLayer

# Phases: 0=black_hold, 1=logo_fade_in, 2=logo_hold, 3=text_fade_in, 4=all_hold, 5=fade_out
var phase: int = 0
var timer: float = 0.0

const BLACK_HOLD: float = 0.4
const LOGO_FADE_IN: float = 0.8
const LOGO_HOLD: float = 1.0
const TEXT_FADE_IN: float = 0.6
const ALL_HOLD: float = 0.8
const FADE_OUT: float = 0.7

var logo_control: Control
var text_label: Label

class GodotLogo:
	extends Control

	func _draw() -> void:
		var blue := Color(0.38, 0.45, 0.85)
		var white := Color(1, 1, 1)
		var pupil := Color(0.1, 0.1, 0.15)
		var cx := size.x * 0.5
		var cy := size.y * 0.45
		var s := minf(size.x, size.y) * 0.42  # scale factor

		# Left ear
		draw_polygon(
			PackedVector2Array([
				Vector2(cx - s * 0.55, cy - s * 0.1),
				Vector2(cx - s * 0.35, cy - s * 0.7),
				Vector2(cx - s * 0.15, cy - s * 0.1),
			]),
			PackedColorArray([blue])
		)

		# Right ear
		draw_polygon(
			PackedVector2Array([
				Vector2(cx + s * 0.55, cy - s * 0.1),
				Vector2(cx + s * 0.35, cy - s * 0.7),
				Vector2(cx + s * 0.15, cy - s * 0.1),
			]),
			PackedColorArray([blue])
		)

		# Head (rounded-ish with ellipse)
		draw_rect(Rect2(cx - s * 0.55, cy - s * 0.15, s * 1.1, s * 0.75), blue)

		# Left eye (white)
		draw_circle(Vector2(cx - s * 0.25, cy + s * 0.1), s * 0.16, white)
		# Right eye (white)
		draw_circle(Vector2(cx + s * 0.25, cy + s * 0.1), s * 0.16, white)

		# Left pupil
		draw_circle(Vector2(cx - s * 0.25, cy + s * 0.1), s * 0.07, pupil)
		# Right pupil
		draw_circle(Vector2(cx + s * 0.25, cy + s * 0.1), s * 0.07, pupil)

		# Body
		draw_rect(Rect2(cx - s * 0.45, cy + s * 0.45, s * 0.9, s * 0.6), blue)

		# Left foot
		draw_rect(Rect2(cx - s * 0.42, cy + s * 0.9, s * 0.28, s * 0.25), blue)
		# Right foot
		draw_rect(Rect2(cx + s * 0.14, cy + s * 0.9, s * 0.28, s * 0.25), blue)

func _ready() -> void:
	# Logo container
	logo_control = GodotLogo.new()
	logo_control.anchor_left = 0.5
	logo_control.anchor_top = 0.5
	logo_control.anchor_right = 0.5
	logo_control.anchor_bottom = 0.5
	logo_control.offset_left = -150
	logo_control.offset_top = -180
	logo_control.offset_right = 150
	logo_control.offset_bottom = 120
	logo_control.modulate.a = 0.0
	logo_control.pivot_offset = Vector2(150, 180)
	add_child(logo_control)

	# Text
	text_label = Label.new()
	text_label.anchor_left = 0.5
	text_label.anchor_right = 0.5
	text_label.anchor_top = 0.5
	text_label.anchor_bottom = 0.5
	text_label.offset_left = -200
	text_label.offset_top = 140
	text_label.offset_right = 200
	text_label.offset_bottom = 180
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 16)
	text_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	text_label.text = "Made with Godot Engine"
	text_label.modulate.a = 0.0
	add_child(text_label)

func _process(delta: float) -> void:
	timer += delta

	match phase:
		0:
			if timer >= BLACK_HOLD:
				phase = 1
				timer = 0.0
		1:
			var t := clampf(timer / LOGO_FADE_IN, 0.0, 1.0)
			t = 1.0 - pow(1.0 - t, 3.0)  # ease out cubic
			logo_control.modulate.a = t
			var s := 0.85 + 0.15 * t
			logo_control.scale = Vector2(s, s)
			if timer >= LOGO_FADE_IN:
				logo_control.modulate.a = 1.0
				logo_control.scale = Vector2.ONE
				phase = 2
				timer = 0.0
		2:
			if timer >= LOGO_HOLD:
				phase = 3
				timer = 0.0
		3:
			var t := clampf(timer / TEXT_FADE_IN, 0.0, 1.0)
			text_label.modulate.a = t
			if timer >= TEXT_FADE_IN:
				text_label.modulate.a = 1.0
				phase = 4
				timer = 0.0
		4:
			if timer >= ALL_HOLD:
				phase = 5
				timer = 0.0
		5:
			var t := clampf(timer / FADE_OUT, 0.0, 1.0)
			var alpha := 1.0 - t
			logo_control.modulate.a = alpha
			text_label.modulate.a = alpha
			if timer >= FADE_OUT:
				phase = 6
				get_tree().change_scene_to_file("res://splash_screen.tscn")
