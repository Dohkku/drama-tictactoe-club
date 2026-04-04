extends Node

## Procedural audio system for board visuals.
## Generates all sounds programmatically using AudioStreamWAV.

const SAMPLE_RATE := 22050

var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _sting_player: AudioStreamPlayer
var _sample_cache: Dictionary = {}
var _bgm_base_volume: float = -18.0
var _sfx_volume: float = -6.0
var _current_theme: int = 0  # 0=Classic, 1=Retro, 2=Mellow


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = _bgm_base_volume
	add_child(_bgm_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	_sfx_player.volume_db = _sfx_volume
	add_child(_sfx_player)

	_sting_player = AudioStreamPlayer.new()
	_sting_player.bus = "Master"
	add_child(_sting_player)


# External audio override paths — drop files here to replace procedural sounds
# Structure: res://audio/sfx/<name>.ogg|wav  and  res://audio/music/bgm.ogg|wav
const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"


# ── Public API ──

func play_sfx(sfx_name: String) -> void:
	var stream: AudioStream = _load_external_sfx(sfx_name)
	if not stream:
		stream = _get_sfx(sfx_name)
	if stream:
		_sfx_player.stream = stream
		_sfx_player.volume_db = _sfx_volume
		_sfx_player.play()


func play_bgm(track_name: String = "bgm") -> void:
	var stream: AudioStream = _load_external_music(track_name)
	if not stream:
		stream = _generate_bgm_loop()
	_bgm_player.stream = stream
	_bgm_player.volume_db = _bgm_base_volume
	_bgm_player.play()


func stop_bgm() -> void:
	_bgm_player.stop()


func duck_bgm(duration: float = 0.3) -> void:
	if not _bgm_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_bgm_player, "volume_db", _bgm_base_volume - 14.0, 0.05)
	tween.tween_property(_bgm_player, "volume_db", _bgm_base_volume, duration)


func interrupt_bgm(sting_name: String) -> void:
	var stream: AudioStreamWAV = _get_sfx(sting_name)
	if not stream:
		return
	_bgm_player.stream_paused = true
	_sting_player.stream = stream
	_sting_player.volume_db = _sfx_volume
	_sting_player.play()
	_sting_player.finished.connect(func(): _bgm_player.stream_paused = false, CONNECT_ONE_SHOT)


func set_sfx_volume(linear: float) -> void:
	_sfx_volume = linear_to_db(clampf(linear, 0.01, 1.0))


func set_bgm_volume(linear: float) -> void:
	_bgm_base_volume = linear_to_db(clampf(linear, 0.01, 1.0))
	if _bgm_player.playing:
		_bgm_player.volume_db = _bgm_base_volume


func apply_theme(theme_idx: int) -> void:
	_current_theme = theme_idx
	_sample_cache.clear()


# ── Sound cache ──

func _get_sfx(sfx_name: String) -> AudioStreamWAV:
	var key: String = "%d_%s" % [_current_theme, sfx_name]
	if _sample_cache.has(key):
		return _sample_cache[key]
	var stream: AudioStreamWAV = _build_sfx(sfx_name)
	if stream:
		_sample_cache[key] = stream
	return stream


func _build_sfx(sfx_name: String) -> AudioStreamWAV:
	var wave: String = _theme_waveform()
	match sfx_name:
		"lift":
			return _generate_tone(_theme_freq(800.0), 0.03, wave, 0.3)
		"whoosh":
			return _generate_sweep(_theme_freq(600.0), _theme_freq(200.0), 0.2, "noise", 0.15)
		"impact_light":
			return _generate_tone(_theme_freq(150.0), 0.08, wave, 0.4)
		"impact_heavy":
			return _generate_impact_heavy()
		"win":
			return _generate_arpeggio(
				PackedFloat64Array([_theme_freq(523.0), _theme_freq(659.0), _theme_freq(784.0)]),
				0.12, 0.5)
		"draw":
			return _generate_sweep(_theme_freq(400.0), _theme_freq(200.0), 0.25, wave, 0.3)
	return null


func _theme_waveform() -> String:
	match _current_theme:
		0: return "sine"
		1: return "square"
		2: return "triangle"
	return "sine"


func _theme_freq(base: float) -> float:
	match _current_theme:
		1: return base * 1.2  # Retro: higher pitch
		2: return base * 0.75  # Mellow: lower pitch
	return base


# ── Procedural generation ──

func _generate_tone(freq: float, duration: float, waveform: String, volume: float) -> AudioStreamWAV:
	var num_frames: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_frames * 2)

	for i in num_frames:
		var t: float = float(i) / float(SAMPLE_RATE)
		var envelope: float = _envelope(i, num_frames)
		var sample: float = _oscillator(waveform, freq, t) * volume * envelope
		var s16: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	return _make_wav(data)


func _generate_sweep(freq_start: float, freq_end: float, duration: float, waveform: String, volume: float) -> AudioStreamWAV:
	var num_frames: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_frames * 2)

	for i in num_frames:
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = float(i) / float(num_frames)
		var freq: float = lerpf(freq_start, freq_end, progress)
		var envelope: float = _envelope(i, num_frames)
		var sample: float = _oscillator(waveform, freq, t) * volume * envelope
		var s16: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	return _make_wav(data)


func _generate_arpeggio(frequencies: PackedFloat64Array, note_duration: float, volume: float) -> AudioStreamWAV:
	var frames_per_note: int = int(SAMPLE_RATE * note_duration)
	var total_frames: int = frames_per_note * frequencies.size()
	var data := PackedByteArray()
	data.resize(total_frames * 2)
	var wave: String = _theme_waveform()

	for n in frequencies.size():
		var freq: float = frequencies[n]
		for i in frames_per_note:
			var t: float = float(i) / float(SAMPLE_RATE)
			var envelope: float = _envelope(i, frames_per_note)
			var sample: float = _oscillator(wave, freq, t) * volume * envelope
			var idx: int = (n * frames_per_note + i) * 2
			var s16: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
			data[idx] = s16 & 0xFF
			data[idx + 1] = (s16 >> 8) & 0xFF

	return _make_wav(data)


func _generate_impact_heavy() -> AudioStreamWAV:
	var duration: float = 0.12
	var num_frames: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_frames * 2)
	var wave: String = _theme_waveform()
	var freq: float = _theme_freq(80.0)

	for i in num_frames:
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = float(i) / float(num_frames)
		# Fast attack, fast decay for punch
		var env: float = 1.0 - progress
		env = env * env  # Quadratic decay
		if progress < 0.04:
			env = progress / 0.04
		# Mix low tone + noise
		var tone: float = _oscillator(wave, freq, t) * 0.5
		var noise: float = randf_range(-1.0, 1.0) * 0.3 * maxf(0.0, 1.0 - progress * 3.0)
		var sample: float = (tone + noise) * env * 0.6
		var s16: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	return _make_wav(data)


func _generate_bgm_loop() -> AudioStreamWAV:
	# Melodic ambient loop — chord progression with rhythm
	var duration: float = 8.0
	var num_frames: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_frames * 2)
	var base_freq: float = _theme_freq(110.0)

	# Simple chord progression: i - VI - III - VII (Am - F - C - G feel)
	var chords: Array = [
		[1.0, 1.2, 1.5],       # i  (root, minor 3rd, 5th)
		[0.89, 1.12, 1.33],    # VI
		[0.75, 0.94, 1.12],    # III
		[0.84, 1.0, 1.26],     # VII
	]
	var chord_dur: float = duration / float(chords.size())

	for i in num_frames:
		var t: float = float(i) / float(SAMPLE_RATE)
		var chord_idx: int = mini(int(t / chord_dur), chords.size() - 1)
		var chord: Array = chords[chord_idx]
		var chord_t: float = fmod(t, chord_dur) / chord_dur

		# Soft pad (detuned sines)
		var pad: float = 0.0
		for interval in chord:
			var freq: float = base_freq * interval
			pad += sin(TAU * freq * t) * 0.06
			pad += sin(TAU * freq * 1.003 * t) * 0.05  # Slight detune for warmth
		# Fifth harmony
		pad += sin(TAU * base_freq * chord[2] * t) * 0.03

		# Subtle rhythmic pulse (every beat)
		var beat_pos: float = fmod(t, 0.5)
		var pulse: float = 0.0
		if beat_pos < 0.05:
			pulse = sin(TAU * base_freq * 2.0 * t) * 0.08 * (1.0 - beat_pos / 0.05)

		# Chord transition fade
		var fade: float = 1.0
		if chord_t < 0.05:
			fade = chord_t / 0.05
		elif chord_t > 0.95:
			fade = (1.0 - chord_t) / 0.05

		var sample: float = (pad + pulse) * fade
		var s16: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	var wav := _make_wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_frames
	return wav


# ── Helpers ──

func _oscillator(waveform: String, freq: float, t: float) -> float:
	var phase: float = fmod(freq * t, 1.0)
	match waveform:
		"sine":
			return sin(TAU * freq * t)
		"square":
			return 1.0 if phase < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(phase - 0.5) - 1.0
		"noise":
			return randf_range(-1.0, 1.0)
	return sin(TAU * freq * t)


func _envelope(frame: int, total: int) -> float:
	var progress: float = float(frame) / float(total)
	# Attack: first 10%
	if progress < 0.1:
		return progress / 0.1
	# Decay: last 30%
	if progress > 0.7:
		return (1.0 - progress) / 0.3
	return 1.0


func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav


# ── External file loading ──
# Drop .ogg or .wav files in res://audio/sfx/ or res://audio/music/
# to override procedural sounds. File name must match the sound name.

func _load_external_sfx(sfx_name: String) -> AudioStream:
	return _try_load_audio(SFX_DIR + sfx_name)


func _load_external_music(track_name: String) -> AudioStream:
	return _try_load_audio(MUSIC_DIR + track_name)


func _try_load_audio(base_path: String) -> AudioStream:
	for ext in [".ogg", ".wav", ".mp3"]:
		var path: String = base_path + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null
