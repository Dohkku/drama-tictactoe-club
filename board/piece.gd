extends Control

var piece_type: int = 0  # 1=X, 2=O
var character_id: String = ""
var emotion: String = "neutral"
var piece_color: Color = Color.WHITE
var _expression_colors: Dictionary = {}

# Drop-shadow offset (pixels)
const _SHADOW_OFFSET := Vector2(2.0, 2.0)
const _SHADOW_ALPHA := 0.22


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

	# --- Drop shadow ---
	var shadow_color = Color(0.0, 0.0, 0.0, _SHADOW_ALPHA)
	var shadow_center = center + _SHADOW_OFFSET
	if piece_type == 1:
		_draw_x(shadow_center, piece_radius, shadow_color)
	elif piece_type == 2:
		_draw_o(shadow_center, piece_radius, shadow_color)

	# --- Background glow ---
	var glow_color = current_color
	glow_color.a = 0.25
	draw_circle(center, piece_radius * 1.15, glow_color)

	# --- Main piece ---
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
	## Animate the piece from its current hand position to target_pos on the board.
	## Uses a physical anticipation-arc: lift -> wind-up -> arc-to-target -> settle.
	pivot_offset = size / 2.0

	var start_pos := position
	var start_size := size

	# Direction from current position to target (used for wind-up)
	var travel := target_pos - start_pos
	var travel_dist := travel.length()

	# ------------------------------------------------------------------
	# 1. LIFT  – scale up slightly and float upward
	# ------------------------------------------------------------------
	var lift_scale := Vector2(1.15, 1.15)
	var lift_pos := Vector2(start_pos.x, start_pos.y - style.lift_height)

	var lift_dur: float = style.arc_duration * 0.35
	var lift_tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_parallel(true)
	lift_tween.tween_property(self, "scale", lift_scale, lift_dur)
	lift_tween.tween_property(self, "position", lift_pos, lift_dur)
	await lift_tween.finished

	# ------------------------------------------------------------------
	# 2. ANTICIPATION  – pull back in the opposite direction (wind-up)
	# ------------------------------------------------------------------
	var anticipation_offset := Vector2.ZERO
	if travel_dist > 1.0:
		anticipation_offset = -travel.normalized() * travel_dist * style.anticipation_factor
	var antic_pos := lift_pos + anticipation_offset

	var antic_dur: float = style.arc_duration * 0.25
	var antic_tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	antic_tween.tween_property(self, "position", antic_pos, antic_dur)
	await antic_tween.finished

	# ------------------------------------------------------------------
	# 3. ARC TO TARGET  – fly to the cell with slight overshoot via TRANS_BACK
	# ------------------------------------------------------------------
	var arc_tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_parallel(true)
	arc_tween.tween_property(self, "position", target_pos, style.arc_duration)
	arc_tween.tween_property(self, "size", target_size, style.arc_duration)
	# Ease scale back toward 1.0 during the arc so the piece shrinks smoothly
	arc_tween.tween_property(self, "scale", Vector2(1.03, 1.03), style.arc_duration)
	await arc_tween.finished

	# ------------------------------------------------------------------
	# 4. SETTLE  – snap to exact position and scale
	# ------------------------------------------------------------------
	var settle_tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_parallel(true)
	settle_tween.tween_property(self, "scale", Vector2.ONE, style.settle_duration)
	settle_tween.tween_property(self, "position", target_pos, style.settle_duration)
	await settle_tween.finished

	# Ensure perfectly clean state
	scale = Vector2.ONE
	position = target_pos
	size = target_size
	pivot_offset = size / 2.0


func _get_emotion_color() -> Color:
	if _expression_colors.has(emotion):
		return _expression_colors[emotion]
	return piece_color


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0
		queue_redraw()
