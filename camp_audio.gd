extends Node

const RATE := 16000
const SECONDS := {"bow": 0.22, "sword": 0.24, "fire_hit": 0.37, "enemy_hit": 0.20,
	"ally_hit": 0.25, "wood_hit": 0.20, "night": 5.0, "music": 8.0}
const CONFIG_PATH := "user://audio.cfg"

var effects: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var ambience := AudioStreamPlayer.new()
var music := AudioStreamPlayer.new()
var master := 0.72
var sfx := 0.78
var ambience_level := 0.62
var music_enabled := true
var voice_index := 0
var night_active := true

func _ready() -> void:
	for key: String in SECONDS:
		effects[key] = synthesize(key)
	for i in 5:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	add_child(ambience)
	add_child(music)
	ambience.stream = effects.night
	music.stream = effects.music
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		master = clampf(config.get_value("audio", "master", master), 0.0, 1.0)
		sfx = clampf(config.get_value("audio", "sfx", sfx), 0.0, 1.0)
		ambience_level = clampf(config.get_value("audio", "ambience", ambience_level), 0.0, 1.0)
		music_enabled = config.get_value("audio", "music", music_enabled)
	apply_levels()

func apply_levels() -> void:
	ambience.volume_linear = master * ambience_level * 0.50
	music.volume_linear = master * 0.30
	for voice: AudioStreamPlayer in voices:
		voice.volume_linear = master * sfx
	if DisplayServer.get_name() == "headless":
		return
	if night_active and not ambience.playing:
		ambience.play()
	elif not night_active and ambience.playing:
		ambience.stop()
	if music_enabled and not music.playing:
		music.play()
	elif not music_enabled and music.playing:
		music.stop()

func set_night(value: bool) -> void:
	if night_active != value:
		night_active = value
		apply_levels()

func save_levels() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master)
	config.set_value("audio", "sfx", sfx)
	config.set_value("audio", "ambience", ambience_level)
	config.set_value("audio", "music", music_enabled)
	config.save(CONFIG_PATH)

func play_effect(key: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var voice := voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	voice.stream = effects[key]
	voice.play()

func synthesize(key: String) -> AudioStreamWAV:
	var duration: float = SECONDS[key]
	var frames := roundi(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	var wind := 0.0
	for i in frames:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		wind = lerpf(wind, noise, 0.035)
		var sample := 0.0
		match key:
			"bow":
				sample = (sin(TAU * (420.0 * t - 430.0 * t * t)) * 0.35 + noise * 0.14) * exp(-t * 23.0)
			"sword":
				sample = (sin(TAU * 965.0 * t) * 0.19 + sin(TAU * 1433.0 * t) * 0.14 + noise * 0.16) * exp(-t * 23.0)
			"fire_hit":
				sample = (sin(TAU * (95.0 * t - 40.0 * t * t)) * 0.30 + noise * 0.19) * exp(-t * 14.0)
			"enemy_hit":
				sample = (sin(TAU * (190.0 * t - 240.0 * t * t)) * 0.28 + noise * 0.16) * exp(-t * 28.0)
			"ally_hit":
				sample = (sin(TAU * 112.0 * t) * 0.32 + noise * 0.12) * exp(-t * 19.0)
			"wood_hit":
				sample = (sin(TAU * 155.0 * t) * 0.26 + noise * 0.22) * exp(-t * 26.0)
			"night":
				var chirp := pow(maxf(0.0, sin(TAU * 1.6 * t)), 20.0) * sin(TAU * 2180.0 * t)
				sample = wind * 0.34 + chirp * 0.026 + (noise * 0.13 if rng.randf() > 0.995 else 0.0)
			"music":
				sample = (sin(TAU * 55.0 * t) + 0.43 * sin(TAU * 82.5 * t)
					+ 0.2 * sin(TAU * 110.0 * t)) * (0.035 + 0.020 * sin(TAU * t / duration))
		var fade := minf(t / 0.006, (duration - t) / (0.25 if key == "night" else 0.02))
		bytes.encode_s16(i * 2, roundi(clampf(sample * clampf(fade, 0, 1), -1, 1) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.mix_rate = RATE
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = bytes
	if key in ["night", "music"]:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = frames
	return stream

func _exit_tree() -> void:
	for player: AudioStreamPlayer in voices + [ambience, music]:
		player.stop()
		player.stream = null
	effects.clear()
