extends Node
## Minimal audio manager — generates all sounds at runtime, no WAV files needed

var hit_snd: AudioStreamPlayer
var trap_snd: AudioStreamPlayer
var map_change_snd: AudioStreamPlayer
var drone_snd: AudioStreamPlayer
var death_snd: AudioStreamPlayer
var select_snd: AudioStreamPlayer
var slide_snd: AudioStreamPlayer
var music_snd: AudioStreamPlayer
var gear_snd: AudioStreamPlayer
var horror_bgm_snd: AudioStreamPlayer
var flashlight_on_snd: AudioStreamPlayer
var flashlight_off_snd: AudioStreamPlayer

func _ready():
	print("[AudioManager] initializing...")

	hit_snd = _make_player(_gen_tone(220, 0.15, 0.6), -4.0)
	add_child(hit_snd)

	trap_snd = _make_player(_gen_tone(440, 0.08, 0.4), -6.0)
	add_child(trap_snd)

	map_change_snd = _make_player(_gen_tone(330, 0.3, 0.5), -4.0)
	add_child(map_change_snd)

	death_snd = _make_player(_gen_tone(150, 0.5, 0.7), -2.0)
	add_child(death_snd)

	select_snd = _make_player(_gen_click(), -6.0)
	add_child(select_snd)

	slide_snd = _make_player(_gen_sweep(1800, 500, 0.07, 0.5), -6.0)
	add_child(slide_snd)

	gear_snd = _make_player(_gen_gear_click(), -8.0)
	add_child(gear_snd)

	flashlight_on_snd = _make_player(_gen_flashlight(true), -8.0)
	add_child(flashlight_on_snd)

	flashlight_off_snd = _make_player(_gen_flashlight(false), -10.0)
	add_child(flashlight_off_snd)

	drone_snd = _make_player(_gen_tone(55, 2.0, 0.2), -12.0)
	drone_snd.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	add_child(drone_snd)
	drone_snd.play()

	# Background music — dark ambient pad
	music_snd = _make_player(_gen_ambient_pad(), -10.0)
	music_snd.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music_snd.bus = &"Music" if AudioServer.get_bus_count() > 1 else &"Master"
	add_child(music_snd)
	music_snd.play()

	# Horror BGM — loop from external OGG file
	var bgm_path = ProjectSettings.globalize_path("res://horror_bgm.ogg")
	var bgm_stream = AudioStreamOggVorbis.load_from_file(bgm_path)
	if bgm_stream:
		bgm_stream.loop = true
		horror_bgm_snd = AudioStreamPlayer.new()
		horror_bgm_snd.stream = bgm_stream
		horror_bgm_snd.volume_db = -6.0
		add_child(horror_bgm_snd)
		horror_bgm_snd.play()
		print("[AudioManager] horror BGM started")
	else:
		print("[AudioManager] failed to load horror_bgm.ogg")

	print("[AudioManager] ready, children: ", get_child_count())

func _make_player(data: AudioStreamWAV, vol: float) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.stream = data
	p.volume_db = vol
	return p

func _gen_tone(freq: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 11025
	var frame_count := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var data := PackedByteArray()
	data.resize(frame_count)
	for i in frame_count:
		var t := float(i) / sample_rate
		var env := 1.0 - (float(i) / frame_count)
		var sample := sin(TAU * freq * t) * amplitude * env
		data[i] = clampi(int((sample + 1.0) * 127.5), 0, 255)

	stream.data = data
	return stream

func _gen_click() -> AudioStreamWAV:
	# Short, punchy UI click — two tones layered
	var sample_rate := 11025
	var duration := 0.05
	var frame_count := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var data := PackedByteArray()
	data.resize(frame_count)
	for i in frame_count:
		var t := float(i) / sample_rate
		var progress := float(i) / frame_count
		var env := pow(1.0 - progress, 3.0)  # fast exponential decay
		var s1 := sin(TAU * 1000.0 * t) * 0.6
		var s2 := sin(TAU * 1500.0 * t) * 0.3
		var sample := (s1 + s2) * env
		data[i] = clampi(int((sample + 1.0) * 127.5), 0, 255)

	stream.data = data
	return stream

func _gen_sweep(freq_from: float, freq_to: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 11025
	var frame_count := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var data := PackedByteArray()
	data.resize(frame_count)
	for i in frame_count:
		var t := float(i) / frame_count
		var env := pow(1.0 - t, 1.5)
		var freq: float = lerp(freq_from, freq_to, t)
		var phase: float = TAU * freq * float(i) / sample_rate
		var sample := sin(phase) * amplitude * env
		data[i] = clampi(int((sample + 1.0) * 127.5), 0, 255)

	stream.data = data
	return stream

func _gen_ambient_pad() -> AudioStreamWAV:
	# Dark ambient pad — low drone + subtle dissonant overtone
	var sample_rate := 11025
	var duration := 4.0
	var frame_count := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var data := PackedByteArray()
	data.resize(frame_count)
	for i in frame_count:
		var t := float(i) / sample_rate
		var env := 1.0
		# Slow fade in/out envelope
		var progress := float(i) / frame_count
		if progress < 0.1:
			env = progress / 0.1
		elif progress > 0.9:
			env = (1.0 - progress) / 0.1
		# Layered tones for atmosphere
		var bass := sin(TAU * 55.0 * t) * 0.35
		var mid := sin(TAU * 82.5 * t) * 0.15  # perfect fifth above
		var dissonant := sin(TAU * 117.0 * t) * 0.08  # slight detune for eerieness
		var tremolo := 0.85 + 0.15 * sin(TAU * 0.3 * t)  # slow tremolo
		var sample := (bass + mid + dissonant) * env * tremolo
		data[i] = clampi(int((sample + 1.0) * 127.5), 0, 255)

	stream.data = data
	return stream

func _gen_gear_click() -> AudioStreamWAV:
	# Mechanical gear click — metallic ping + noise burst
	var sample_rate := 11025
	var duration := 0.08
	var frame_count := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # consistent gear texture
	var data := PackedByteArray()
	data.resize(frame_count)
	for i in frame_count:
		var t := float(i) / sample_rate
		var progress := float(i) / frame_count
		var env := pow(1.0 - progress, 4.0)  # sharp decay
		# Metallic resonant ping — two close frequencies create "cog" feel
		var ping1 := sin(TAU * 3200.0 * t) * 0.35
		var ping2 := sin(TAU * 4800.0 * t) * 0.2
		var ring := sin(TAU * 1600.0 * t) * 0.15 * sin(TAU * 60.0 * t)  # tremolo ring
		# Short noise burst for mechanical texture
		var noise := rng.randf_range(-1.0, 1.0) * 0.3 * pow(1.0 - progress, 6.0)
		var sample := (ping1 + ping2 + ring + noise) * env
		data[i] = clampi(int((sample + 1.0) * 127.5), 0, 255)

	stream.data = data
	return stream

func _gen_flashlight(on: bool) -> AudioStreamWAV:
	# Mechanical switch click — sharp transient + resonant body
	var sample_rate := 11025
	var duration := 0.12
	var frame_count := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var rng := RandomNumberGenerator.new()
	rng.seed = 99 if on else 77
	var data := PackedByteArray()
	data.resize(frame_count)
	for i in frame_count:
		var t := float(i) / sample_rate
		var progress := float(i) / frame_count
		var env: float
		var sample := 0.0
		if on:
			# Switch ON: sharp click + rising electrical hum
			env = pow(1.0 - progress, 2.5)
			var click := sin(TAU * 4000.0 * t) * 0.4 * pow(1.0 - progress, 6.0)
			var snap := rng.randf_range(-1.0, 1.0) * 0.25 * pow(1.0 - progress, 8.0)
			var hum := sin(TAU * 120.0 * t) * 0.15 * smoothstep(0.0, 0.03, t) * (1.0 - progress)
			sample = (click + snap + hum) * env
		else:
			# Switch OFF: softer damped thud
			env = pow(1.0 - progress, 3.5)
			var thud := sin(TAU * 2500.0 * t) * 0.3 * pow(1.0 - progress, 4.0)
			var damp := rng.randf_range(-1.0, 1.0) * 0.15 * pow(1.0 - progress, 5.0)
			sample = (thud + damp) * env
		data[i] = clampi(int((sample + 1.0) * 127.5), 0, 255)

	stream.data = data
	return stream

# ── Public API ──

func play_hit():
	if hit_snd:
		hit_snd.pitch_scale = randf_range(0.8, 1.2)
		hit_snd.play()

func play_trap():
	if trap_snd:
		trap_snd.pitch_scale = randf_range(0.7, 1.3)
		trap_snd.play()

func play_map_change():
	if map_change_snd:
		map_change_snd.play()

func play_death():
	if death_snd:
		death_snd.play()

func play_select():
	print("[AudioManager] play_select")
	if select_snd:
		select_snd.play()

func play_slide():
	print("[AudioManager] play_slide")
	if slide_snd:
		slide_snd.pitch_scale = randf_range(0.85, 1.15)
		slide_snd.play()

func play_gear():
	if gear_snd:
		gear_snd.pitch_scale = randf_range(0.9, 1.1)
		gear_snd.play()

func play_flashlight(on: bool):
	if on and flashlight_on_snd:
		flashlight_on_snd.play()
	elif not on and flashlight_off_snd:
		flashlight_off_snd.play()

func stop_horror_bgm():
	if horror_bgm_snd:
		horror_bgm_snd.stop()

func play_horror_bgm():
	if horror_bgm_snd:
		horror_bgm_snd.play()
