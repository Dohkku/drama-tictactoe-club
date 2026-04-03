extends Control

## Screen-level visual effects: flash overlay, propagation ring.
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
