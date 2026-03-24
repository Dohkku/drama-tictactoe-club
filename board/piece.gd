extends Control

const PlacementEffectsScript = preload("res://board/placement_effects.gd")

var piece_type: int = 0  # 1=X, 2=O
var character_id: String = ""
var emotion: String = "neutral"
var piece_color: Color = Color.WHITE
var _expression_colors: Dictionary = {}


func setup(type: int, char_id: String, color: Color, expressions: Dictionary = {}) -> void:
	piece_type = type
	character_id = char_id
	piece_color = color
	_expression_colors = expressions
	queue_redraw()


func _draw() -> void:
	if piece_type == 0:
		return

	var center = size / 2.0
	var piece_radius: float = min(size.x, size.y) * 0.35
	var current_color = _get_emotion_color()

	# Background glow
	var glow_color = current_color
	glow_color.a = 0.25
	draw_circle(center, piece_radius * 1.15, glow_color)

	if piece_type == 1:
		_draw_x(center, piece_radius, current_color)
	elif piece_type == 2:
		_draw_o(center, piece_radius, current_color)


func _draw_x(center: Vector2, radius: float, color: Color) -> void:
	var offset = Vector2(radius, radius) * 0.6
	var width = max(4.0, radius * 0.18)
	draw_line(center - offset, center + offset, color, width, true)
	draw_line(center + Vector2(-offset.x, offset.y), center + Vector2(offset.x, -offset.y), color, width, true)


func _draw_o(center: Vector2, radius: float, color: Color) -> void:
	var width = max(4.0, radius * 0.18)
	draw_arc(center, radius * 0.6, 0, TAU, 36, color, width, true)


func set_emotion(new_emotion: String) -> void:
	if emotion == new_emotion:
		return
	emotion = new_emotion
	queue_redraw()


func play_move_to(target_pos: Vector2, target_size: Vector2, style: Resource, all_pieces: Array) -> void:
	pivot_offset = size / 2.0

	# Rotation + scale pulse during travel (makes spinning visible even for symmetric shapes)
	if style.move_rotation != 0.0:
		var spin = create_tween()
		spin.tween_property(self, "rotation_degrees", style.move_rotation, style.move_duration)
		spin.tween_property(self, "rotation_degrees", 0.0, 0.15)
		# Scale pulse so spinning is visible on circles and crosses
		var loops = max(1, int(style.move_duration / 0.18))
		var pulse = create_tween().set_loops(loops)
		pulse.tween_property(self, "scale", Vector2(1.25, 1.25), 0.09).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(self, "scale", Vector2(0.8, 0.8), 0.09).set_trans(Tween.TRANS_SINE)

	# Move + resize to target
	var move_tween = create_tween().set_ease(style.move_ease).set_trans(style.move_trans).set_parallel(true)
	move_tween.tween_property(self, "position", target_pos, style.move_duration)
	move_tween.tween_property(self, "size", target_size, style.move_duration)
	await move_tween.finished

	scale = Vector2.ONE
	pivot_offset = size / 2.0

	# Landing effects
	for effect_name in style.effects:
		var fx = PlacementEffectsScript.apply(effect_name, self, style.intensity, all_pieces)
		if fx:
			await fx.finished


func _get_emotion_color() -> Color:
	if _expression_colors.has(emotion):
		return _expression_colors[emotion]
	return piece_color


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0
		queue_redraw()
