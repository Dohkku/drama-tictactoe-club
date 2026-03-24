extends Control

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var play_button: Button = %PlayButton
@onready var editor_button: Button = %EditorButton
@onready var settings_button: Button = %SettingsButton
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var master_slider: HSlider = %MasterSlider
@onready var window_option: OptionButton = %WindowOption
@onready var settings_close_button: Button = %SettingsCloseButton
@onready var settings_dimmer: ColorRect = $SettingsDimmer


func _ready() -> void:
	# Connect buttons
	play_button.pressed.connect(_on_play_pressed)
	editor_button.pressed.connect(_on_editor_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_close_button.pressed.connect(_on_settings_close_pressed)
	master_slider.value_changed.connect(_on_master_volume_changed)
	window_option.item_selected.connect(_on_window_mode_changed)

	# Editor button is now enabled
	editor_button.tooltip_text = "Abrir el editor de proyecto"

	# Hide settings panel initially
	settings_panel.visible = false

	# Load current settings into UI
	_sync_settings_ui()

	# Entrance animation
	_animate_entrance()


func _sync_settings_ui() -> void:
	master_slider.value = Settings.master_volume * 100.0
	window_option.selected = Settings.window_mode


func _animate_entrance() -> void:
	# Title slides down from above
	var title_target_pos = title_label.position
	title_label.modulate.a = 0.0
	title_label.position.y -= 60.0

	var subtitle_target_pos = subtitle_label.position
	subtitle_label.modulate.a = 0.0

	# Buttons fade in
	play_button.modulate.a = 0.0
	editor_button.modulate.a = 0.0
	settings_button.modulate.a = 0.0

	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Title entrance
	tween.tween_property(title_label, "position:y", title_target_pos.y, 0.7)
	tween.parallel().tween_property(title_label, "modulate:a", 1.0, 0.5)

	# Subtitle fade in
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.4)

	# Buttons staggered fade in
	tween.tween_property(play_button, "modulate:a", 1.0, 0.3)
	tween.tween_property(editor_button, "modulate:a", 1.0, 0.3)
	tween.tween_property(settings_button, "modulate:a", 1.0, 0.3)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _on_editor_pressed() -> void:
	get_tree().change_scene_to_file("res://editor/editor_main.tscn")


func _on_settings_pressed() -> void:
	_sync_settings_ui()
	settings_dimmer.visible = true
	settings_panel.visible = true


func _on_settings_close_pressed() -> void:
	settings_dimmer.visible = false
	settings_panel.visible = false


func _on_master_volume_changed(value: float) -> void:
	Settings.master_volume = value / 100.0
	Settings._apply_audio()
	Settings.save_settings()


func _on_window_mode_changed(index: int) -> void:
	Settings.window_mode = index
	Settings._apply_window_mode()
	Settings.save_settings()
