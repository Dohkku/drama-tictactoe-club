class_name SpeedLinesEffect
extends Control

## Draws radial speed lines from center for SNAPPY camera transitions.
## Add as a child of CinematicStage, overlaying the CharacterLayer.

var _lines: Array[Dictionary] = []
var _playing: bool = false
const LINE_COUNT := 25
const MIN_LENGTH := 40.0
const MAX_LENGTH := 180.0
const LINE_WIDTH := 1.5
const LINE_COLOR := Color(1.0, 0.98, 0.92, 0.45)  # Semi-transparent cream


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false


func play() -> void:
	if _playing:
		return
	_playing = true
	_generate_lines()
	visible = true
	queue_redraw()

	var tween := create_tween()
	# Quick fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.05)
	# Brief hold (implicit from sequential tween)
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(_on_finished)


func _generate_lines() -> void:
	_lines.clear()
	var center := size / 2.0
	for i in LINE_COUNT:
		var angle := randf() * TAU
		var inner_radius := randf_range(30.0, 80.0)
		var outer_radius := inner_radius + randf_range(MIN_LENGTH, MAX_LENGTH)
		var width := randf_range(1.0, LINE_WIDTH * 2.0)
		var alpha := randf_range(0.2, 0.6)
		_lines.append({
			"from": center + Vector2(cos(angle), sin(angle)) * inner_radius,
			"to": center + Vector2(cos(angle), sin(angle)) * outer_radius,
			"width": width,
			"alpha": alpha,
		})


func _draw() -> void:
	if not _playing:
		return
	for line_data in _lines:
		var color := LINE_COLOR
		color.a = line_data.alpha
		draw_line(line_data["from"], line_data["to"], color, line_data.width, true)


func _on_finished() -> void:
	_playing = false
	visible = false
	_lines.clear()
	queue_redraw()
