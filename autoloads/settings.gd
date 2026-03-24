extends Node

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var window_mode: int = 0  # 0=windowed, 1=fullscreen, 2=borderless

func _ready() -> void:
	load_settings()
	_apply_audio()

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("display", "window_mode", window_mode)
	config.save("user://settings.cfg")

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		return
	master_volume = config.get_value("audio", "master", 1.0)
	music_volume = config.get_value("audio", "music", 1.0)
	sfx_volume = config.get_value("audio", "sfx", 1.0)
	window_mode = config.get_value("display", "window_mode", 0)
	_apply_audio()
	_apply_window_mode()

func _apply_audio() -> void:
	# Apply to Godot audio buses
	var master_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))

func _apply_window_mode() -> void:
	match window_mode:
		0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
