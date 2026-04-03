extends Control

## Screen-level visual effects: flash overlay, propagation ring, win line.
## Add as child of the board area — it overlays everything.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func flash(color: Color, duration: float = 0.1) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var tween := rect.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
	tween.tween_callback(rect.queue_free)


func play_win_line(positions: PackedVector2Array, color: Color = Color.WHITE,
		width: float = 6.0, duration: float = 0.4, glow: bool = true,
		pulse: bool = true, pulse_speed: float = 1.5) -> Control:
	var line := _WinLine.new()
	var local_pts := PackedVector2Array()
	for pt in positions:
		local_pts.append(pt - global_position)
	line.points = local_pts
	line.line_color = color
	line.line_width = width
	line.glow_enabled = glow
	line.pulse_enabled = pulse
	line.pulse_speed = pulse_speed
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(line)
	line.play(duration)
	return line


func propagation_ring(origin: Vector2, color: Color, max_radius: float = 200.0, duration: float = 0.3) -> void:
	var ring := _PropagationRing.new()
	ring.origin_point = origin - global_position
	ring.ring_color = color
	ring.max_radius = max_radius
	ring.duration = duration
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ring)
	ring.play()


class _PropagationRing extends Control:
	var origin_point: Vector2 = Vector2.ZERO
	var ring_color: Color = Color.WHITE
	var max_radius: float = 200.0
	var duration: float = 0.3
	var _current_radius: float = 0.0
	var _alpha: float = 1.0

	func play() -> void:
		var tween := create_tween().set_parallel(true)
		tween.tween_method(_set_radius, 0.0, max_radius, duration)
		tween.tween_method(_set_alpha, 0.8, 0.0, duration)
		tween.chain().tween_callback(queue_free)

	func _set_radius(r: float) -> void:
		_current_radius = r
		queue_redraw()

	func _set_alpha(a: float) -> void:
		_alpha = a
		queue_redraw()

	func _draw() -> void:
		if _current_radius <= 0.0:
			return
		var c: Color = Color(ring_color)
		c.a = _alpha
		var width: float = maxf(2.0, _current_radius * 0.08)
		draw_arc(origin_point, _current_radius, 0.0, TAU, 48, c, width, true)


class _WinLine extends Control:
	var points: PackedVector2Array = PackedVector2Array()
	var line_color: Color = Color.WHITE
	var line_width: float = 6.0
	var glow_enabled: bool = true
	var pulse_enabled: bool = true
	var pulse_speed: float = 1.5
	var _progress: float = 0.0
	var _total_length: float = 0.0
	var _pulse_phase: float = 0.0
	var _draw_complete: bool = false

	func play(duration: float) -> void:
		_total_length = 0.0
		for i in range(points.size() - 1):
			_total_length += points[i].distance_to(points[i + 1])
		if _total_length <= 0.0:
			return
		var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_method(_set_progress, 0.0, 1.0, duration)
		tween.tween_callback(func(): _draw_complete = true)

	func _process(delta: float) -> void:
		if _draw_complete and pulse_enabled:
			_pulse_phase += delta * pulse_speed
			queue_redraw()

	func _set_progress(p: float) -> void:
		_progress = p
		queue_redraw()

	func _draw() -> void:
		if points.size() < 2 or _total_length <= 0.0:
			return

		# Pulse modulates alpha and width after draw completes
		var pulse_alpha: float = 1.0
		var pulse_width_mult: float = 1.0
		if _draw_complete and pulse_enabled:
			var breath: float = (sin(_pulse_phase * TAU) + 1.0) * 0.5  # 0..1
			pulse_alpha = lerpf(0.5, 1.0, breath)
			pulse_width_mult = lerpf(0.9, 1.2, breath)

		var draw_length: float = _progress * _total_length
		var consumed: float = 0.0
		var cur_width: float = line_width * pulse_width_mult

		for i in range(points.size() - 1):
			var seg_len: float = points[i].distance_to(points[i + 1])
			if seg_len <= 0.0:
				continue
			var start_pt: Vector2 = points[i]
			var end_pt: Vector2
			if consumed + seg_len <= draw_length:
				end_pt = points[i + 1]
				consumed += seg_len
			else:
				var t: float = (draw_length - consumed) / seg_len
				end_pt = start_pt.lerp(points[i + 1], t)
				consumed = draw_length
			# Glow
			if glow_enabled:
				var glow_col: Color = Color(line_color)
				glow_col.a = 0.15 * pulse_alpha
				draw_line(start_pt, end_pt, glow_col, cur_width * 3.5, true)
			# Main line
			var main_col: Color = Color(line_color)
			main_col.a = pulse_alpha
			draw_line(start_pt, end_pt, main_col, cur_width, true)
			if consumed >= draw_length:
				break
