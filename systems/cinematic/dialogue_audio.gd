class_name DialogueAudio
extends Node

## Generates programmatic typing beep sounds for dialogue.
## Each character gets a distinct tone based on pitch and waveform.

const SAMPLE_RATE := 22050
const BEEP_DURATION := 0.04  # 40ms

var _player: AudioStreamPlayer
var _sample_cache: Dictionary = {}  # character_id -> AudioStreamWAV


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -12.0
	add_child(_player)


## Play a short beep for a text character. Skips spaces and punctuation pauses.
## character_id is used as a cache key so each speaker gets a consistent sound.
func play_char_beep(character_id: String, pitch: float = 220.0, waveform: String = "sine") -> void:
	var sample := _get_or_create_sample(character_id, pitch, waveform)
	_player.stream = sample
	_player.play()


## Add slight pitch variation per visible character to feel more lively.
func play_char_beep_varied(character_id: String, base_pitch: float = 220.0, variation: float = 30.0, waveform: String = "sine") -> void:
	var varied_pitch := base_pitch + randf_range(-variation, variation)
	# Build a unique cache key including the rounded pitch to limit cache size
	var cache_key := "%s_%d" % [character_id, int(varied_pitch / 10.0) * 10]
	var sample := _get_or_create_sample(cache_key, varied_pitch, waveform)
	_player.stream = sample
	_player.play()


func _get_or_create_sample(cache_key: String, pitch: float, waveform: String) -> AudioStreamWAV:
	if _sample_cache.has(cache_key):
		return _sample_cache[cache_key]

	var sample := _generate_sample(pitch, waveform)
	_sample_cache[cache_key] = sample
	return sample


func _generate_sample(pitch: float, waveform: String) -> AudioStreamWAV:
	var num_frames := int(SAMPLE_RATE * BEEP_DURATION)
	var data := PackedByteArray()
	data.resize(num_frames * 2)  # 16-bit mono = 2 bytes per frame

	for i in range(num_frames):
		var t := float(i) / SAMPLE_RATE
		var phase := t * pitch

		# Envelope: quick fade in/out to avoid clicks
		var envelope := 1.0
		var fade_frames := int(num_frames * 0.1)
		if i < fade_frames:
			envelope = float(i) / fade_frames
		elif i > num_frames - fade_frames:
			envelope = float(num_frames - i) / fade_frames

		var value := 0.0
		match waveform:
			"sine":
				value = sin(phase * TAU)
			"square":
				value = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"triangle":
				var p := fmod(phase, 1.0)
				value = 4.0 * abs(p - 0.5) - 1.0
			_:
				value = sin(phase * TAU)

		value *= envelope * 0.5  # Keep volume moderate

		# Convert to 16-bit signed integer
		var sample_int := clampi(int(value * 32767.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data

	return stream
