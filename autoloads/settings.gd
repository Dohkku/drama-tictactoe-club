extends Node

var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.7
var voice_volume: float = 0.8
var window_mode: int = 0  # 0=windowed, 1=fullscreen, 2=borderless

func _ready() -> void:
	load_settings()
	_apply_audio()

signal volumes_changed()

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "voice", voice_volume)
	config.set_value("display", "window_mode", window_mode)
	config.save("user://settings.cfg")

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		return
	master_volume = config.get_value("audio", "master", 1.0)
	music_volume = config.get_value("audio", "music", 0.6)
	sfx_volume = config.get_value("audio", "sfx", 0.7)
	voice_volume = config.get_value("audio", "voice", 0.8)
	window_mode = config.get_value("display", "window_mode", 0)
	_apply_audio()
	_apply_window_mode()

func _apply_audio() -> void:
	# Apply to Godot audio buses
	var master_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))

func _apply_window_mode() -> void:
	# Reset borderless by default before applying a mode.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	match window_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			# "Sin Bordes": borderless + maximized window is more consistent across OSes.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
