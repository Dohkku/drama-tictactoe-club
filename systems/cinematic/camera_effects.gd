extends Node

## Camera effects: shake, flash, and transition overlays.
## Transitions: fade, directional speed lines, wipe.

var _shake_target: Control = null
var _flash_target: Control = null


func setup(shake_target: Control, flash_target: Control = null) -> void:
	_shake_target = shake_target
	_flash_target = flash_target if flash_target else shake_target


# ── Core effects ──

func shake(intensity: float = 1.0, duration: float = 0.3) -> void:
	if not _shake_target:
		return
	var original_pos := _shake_target.position
	var tween := _shake_target.create_tween()
	var steps: int = int(duration / 0.03)
	for i in range(steps):
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * intensity * 10.0
		tween.tween_property(_shake_target, "position", original_pos + offset, 0.03)
	tween.tween_property(_shake_target, "position", original_pos, 0.03)


func flash(color: Color = Color.WHITE, duration: float = 0.3) -> void:
	if not _flash_target:
		return
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_target.add_child(rect)
	var tween := rect.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
	tween.tween_callback(rect.queue_free)


# ── Fade transitions ──

func fade_to_black(duration: float = 0.3) -> void:
	_fade_in(Color.BLACK, duration)

func fade_from_black(duration: float = 0.3) -> void:
	_fade_out(Color.BLACK, duration)

func fade_to_white(duration: float = 0.2) -> void:
	_fade_in(Color.WHITE, duration)

func fade_from_white(duration: float = 0.2) -> void:
	_fade_out(Color.WHITE, duration)


func _fade_in(color: Color, duration: float) -> void:
	if not _flash_target:
		return
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0
	rect.set_meta("fade_overlay", true)
	_flash_target.add_child(rect)
	var tween := rect.create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, duration)


func _fade_out(color: Color, duration: float) -> void:
	if not _flash_target:
		return
	# Find existing fade overlay or create one at full opacity
	var rect: ColorRect = null
	for child in _flash_target.get_children():
		if child is ColorRect and child.has_meta("fade_overlay"):
			rect = child
			break
	if not rect:
		rect = ColorRect.new()
		rect.color = color
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.modulate.a = 1.0
		_flash_target.add_child(rect)
	var tween := rect.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
	tween.tween_callback(rect.queue_free)


func clear_fades() -> void:
	if not _flash_target:
		return
	for child in _flash_target.get_children():
		if child is ColorRect and child.has_meta("fade_overlay"):
			child.queue_free()


# ── Speed lines (with real movement) ──

func speed_lines(direction: String = "right", duration: float = 0.3, color: Color = Color(1.0, 0.98, 0.92, 0.5)) -> void:
	if not _flash_target:
		return
	var overlay := _SpeedLinesOverlay.new()
	overlay.line_direction = direction
	overlay.line_color = color
	overlay.duration = duration
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_target.add_child(overlay)
	overlay.play()


# ── Wipe ──

func wipe(direction: String = "right", duration: float = 0.4, color: Color = Color.BLACK) -> void:
	## Curtain close — covers the screen progressively. Stays covered.
	if not _flash_target:
		return
	var overlay := _WipeOverlay.new()
	overlay.wipe_direction = direction
	overlay.wipe_color = color
	overlay.is_closing = true
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.set_meta("wipe_overlay", true)
	_flash_target.add_child(overlay)
	overlay.play(duration)


func wipe_out(direction: String = "right", duration: float = 0.4, color: Color = Color.BLACK) -> void:
	## Curtain open — uncovers the screen progressively. Cleans up when done.
	if not _flash_target:
		return
	# Remove any existing wipe overlays
	for child in _flash_target.get_children():
		if child is Control and child.has_meta("wipe_overlay"):
			child.queue_free()
	var overlay := _WipeOverlay.new()
	overlay.wipe_direction = direction
	overlay.wipe_color = color
	overlay.is_closing = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_target.add_child(overlay)
	overlay.play(duration)


# ── Speed Lines Inner Class ──

class _SpeedLinesOverlay extends Control:
	var line_direction: String = "right"
	var line_color: Color = Color(1.0, 0.98, 0.92, 0.5)
	var duration: float = 0.3
	var _lines: Array[Dictionary] = []
	var _alpha: float = 0.0
	var _movement: float = 0.0  # 0..1 progress for line translation
	var _playing: bool = false

	func play() -> void:
		_generate_lines()
		_playing = true
		var tween := create_tween()
		tween.tween_method(_set_alpha, 0.0, 1.0, duration * 0.1)
		tween.tween_interval(duration * 0.6)
		tween.tween_method(_set_alpha, 1.0, 0.0, duration * 0.3)
		tween.tween_callback(queue_free)

	func _process(delta: float) -> void:
		if _playing:
			_movement += delta / duration
			queue_redraw()

	func _set_alpha(a: float) -> void:
		_alpha = a

	func _generate_lines() -> void:
		_lines.clear()
		var sz: Vector2 = get_viewport_rect().size
		if sz == Vector2.ZERO:
			sz = Vector2(1024, 600)
		for i in 35:
			var length: float = randf_range(60.0, 200.0)
			var width: float = randf_range(1.0, 3.0)
			var alpha: float = randf_range(0.15, 0.6)
			var offset: float = randf()  # Random phase offset for variety
			var perp: float = randf()    # Position on perpendicular axis (0..1)
			_lines.append({
				"length": length, "width": width, "alpha": alpha,
				"offset": offset, "perp": perp,
			})

	func _draw() -> void:
		if _alpha <= 0.0:
			return
		var sz: Vector2 = size
		if sz == Vector2.ZERO:
			return

		var is_horizontal: bool = line_direction == "left" or line_direction == "right"
		var is_radial: bool = line_direction == "radial"

		# Draw two passes: outline (black, thicker) then fill (color)
		for pass_idx in 2:
			for l in _lines:
				var col: Color
				var w: float
				if pass_idx == 0:
					# Outline pass
					col = Color(0.0, 0.0, 0.0, l.alpha * _alpha * 0.8)
					w = l.width + 2.0
				else:
					# Fill pass
					col = Color(line_color)
					col.a = l.alpha * _alpha
					w = l.width

				if is_radial:
					var center: Vector2 = sz / 2.0
					var angle: float = l.offset * TAU
					var base_r: float = 30.0 + l.perp * 60.0
					var grow: float = _movement * 300.0
					var inner_r: float = base_r + grow
					var outer_r: float = inner_r + l.length
					var dir := Vector2(cos(angle), sin(angle))
					draw_line(center + dir * inner_r, center + dir * outer_r, col, w, true)
				elif is_horizontal:
					var y: float = l.perp * sz.y
					var travel: float = sz.x + l.length * 2
					var raw: float = l.offset * travel + _movement * travel * 2.0
					var wrapped: float = fmod(raw, travel)
					if line_direction == "right":
						var x: float = wrapped - l.length
						draw_line(Vector2(x, y), Vector2(x + l.length, y), col, w, true)
					else:
						var x: float = sz.x - wrapped + l.length
						draw_line(Vector2(x, y), Vector2(x - l.length, y), col, w, true)
				else:  # up/down
					var x: float = l.perp * sz.x
					var travel: float = sz.y + l.length * 2
					var raw: float = l.offset * travel + _movement * travel * 2.0
					var wrapped: float = fmod(raw, travel)
					if line_direction == "down":
						var y: float = wrapped - l.length
						draw_line(Vector2(x, y), Vector2(x, y + l.length), col, w, true)
					else:
						var y: float = sz.y - wrapped + l.length
						draw_line(Vector2(x, y), Vector2(x, y - l.length), col, w, true)


# ── Wipe Inner Class ──

class _WipeOverlay extends Control:
	var wipe_direction: String = "right"
	var wipe_color: Color = Color.BLACK
	var is_closing: bool = true  # true=cover screen, false=uncover screen
	var _progress: float = 0.0

	func play(duration: float) -> void:
		var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		if is_closing:
			tween.tween_method(_set_progress, 0.0, 1.0, duration)
		else:
			_progress = 1.0
			tween.tween_method(_set_progress, 1.0, 0.0, duration)
			tween.tween_callback(queue_free)

	func _set_progress(p: float) -> void:
		_progress = p
		queue_redraw()

	func _draw() -> void:
		var sz: Vector2 = size
		if sz == Vector2.ZERO or _progress <= 0.0:
			return

		match wipe_direction:
			"right":
				draw_rect(Rect2(0, 0, _progress * sz.x, sz.y), wipe_color)
			"left":
				var edge: float = (1.0 - _progress) * sz.x
				draw_rect(Rect2(edge, 0, sz.x - edge, sz.y), wipe_color)
			"down":
				draw_rect(Rect2(0, 0, sz.x, _progress * sz.y), wipe_color)
			"up":
				var edge: float = (1.0 - _progress) * sz.y
				draw_rect(Rect2(0, edge, sz.x, sz.y - edge), wipe_color)
