extends CanvasLayer

## Full-screen overlay that announces match results (victory/defeat/draw).
## Usage:
##   var overlay = preload("res://ui/match_result_overlay.tscn").instantiate()
##   add_child(overlay)
##   await overlay.show_result("win", "Luna")

signal overlay_finished

const DISPLAY_DURATION := 2.5
const FADE_IN_DURATION := 0.3
const TEXT_ANIM_DURATION := 0.5
const FADE_OUT_DURATION := 0.4
const SHAKE_DURATION := 0.3
const SHAKE_STRENGTH := 6.0

var _bg: ColorRect
var _result_label: Label
var _subtitle_label: Label
var _center: CenterContainer
var _vbox: VBoxContainer


func _ready() -> void:
	layer = 5
	_build_ui()


func _build_ui() -> void:
	# Semi-transparent dark background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.0, 0.0, 0.0, 0.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input during overlay
	add_child(_bg)

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 12)
	_center.add_child(_vbox)

	# Main result text
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 72)
	_result_label.modulate.a = 0.0
	_result_label.pivot_offset = Vector2(0, 0)  # Will be set after layout
	_vbox.add_child(_result_label)

	# Subtitle (opponent name)
	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 28)
	_subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
	_subtitle_label.modulate.a = 0.0
	_vbox.add_child(_subtitle_label)


func show_result(result: String, opponent_name: String = "") -> void:
	# Configure text and colors based on result
	var text: String
	var color: Color
	match result:
		"win":
			text = "¡VICTORIA!"
			color = Color(1.0, 0.85, 0.2)  # Gold
		"lose":
			text = "DERROTA"
			color = Color(0.95, 0.25, 0.2)  # Red
		"draw":
			text = "EMPATE"
			color = Color(0.65, 0.65, 0.7)  # Gray
		_:
			text = result.to_upper()
			color = Color.WHITE

	_result_label.text = text
	_result_label.add_theme_color_override("font_color", color)

	if opponent_name != "":
		_subtitle_label.text = "vs %s" % opponent_name
	else:
		_subtitle_label.visible = false

	# --- Animate in ---

	# Background fade in
	var bg_tween = create_tween()
	bg_tween.tween_property(_bg, "color:a", 0.55, FADE_IN_DURATION)

	await get_tree().create_timer(FADE_IN_DURATION * 0.5).timeout

	# Set pivot to center of label for scale animation
	await get_tree().process_frame
	_result_label.pivot_offset = _result_label.size / 2.0

	# Result text: scale from 0 to 1 with overshoot
	_result_label.scale = Vector2(0.0, 0.0)
	_result_label.modulate.a = 1.0

	var text_tween = create_tween()
	text_tween.tween_property(_result_label, "scale", Vector2(1.0, 1.0), TEXT_ANIM_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Screen shake for victory
	if result == "win":
		_do_screen_shake()

	# Subtitle fade in (slightly delayed)
	if _subtitle_label.visible:
		var sub_tween = create_tween()
		sub_tween.tween_interval(TEXT_ANIM_DURATION * 0.6)
		sub_tween.tween_property(_subtitle_label, "modulate:a", 1.0, 0.3)

	# --- Hold ---
	await get_tree().create_timer(DISPLAY_DURATION).timeout

	# --- Animate out ---
	var out_tween = create_tween().set_parallel(true)
	out_tween.tween_property(_bg, "color:a", 0.0, FADE_OUT_DURATION)
	out_tween.tween_property(_result_label, "modulate:a", 0.0, FADE_OUT_DURATION)
	out_tween.tween_property(_subtitle_label, "modulate:a", 0.0, FADE_OUT_DURATION)
	await out_tween.finished

	overlay_finished.emit()
	queue_free()


func _do_screen_shake() -> void:
	var original_offset := _center.position
	var shake_tween := create_tween()
	var steps := 8
	var step_dur := SHAKE_DURATION / steps
	for i in range(steps):
		var strength: float = SHAKE_STRENGTH * (1.0 - float(i) / steps)
		var offset := Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		shake_tween.tween_property(_center, "position", original_offset + offset, step_dur)
	shake_tween.tween_property(_center, "position", original_offset, step_dur)
