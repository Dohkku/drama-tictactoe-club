extends Control

var design: Resource = null  # PieceDesign
var character_id: String = ""
var piece_color: Color = Color.WHITE
var effect_player: Node2D = null
var placement_offset: Vector2 = Vector2.ZERO

# Selection infrastructure (dormant — enable via set_selectable)
var selectable: bool = false
var selected: bool = false
# Visual deformation (squash/stretch) — affects drawing, not the Control transform
var visual_scale: Vector2 = Vector2.ONE

signal phase_started(phase_name: String)
signal phase_completed(phase_name: String)
signal move_completed()
signal piece_clicked(piece: Control)

const _SHADOW_OFFSET := Vector2(2.0, 2.0)
const _SHADOW_ALPHA := 0.22


func setup(piece_design: Resource, char_id: String, color: Color) -> void:
	design = piece_design
	character_id = char_id
	piece_color = color
	queue_redraw()


func set_design(new_design: Resource) -> void:
	design = new_design
	queue_redraw()


func _draw() -> void:
	if design == null:
		return

	var center: Vector2 = size / 2.0
	var piece_radius: float = minf(size.x, size.y) * 0.35

	# Apply visual deformation (squash/stretch) around center
	if visual_scale != Vector2.ONE:
		draw_set_transform(center * (Vector2.ONE - visual_scale), 0.0, visual_scale)

	var body_col: Color = design.body_color if design.body_color.a > 0.01 else piece_color
	var sym_col: Color = design.symbol_color if design.symbol_color.a > 0.01 else piece_color

	# 1. Drop shadow of body
	var shadow_color := Color(0.0, 0.0, 0.0, _SHADOW_ALPHA)
	_draw_body(center + _SHADOW_OFFSET, piece_radius, shadow_color)

	# 2. Body filled
	_draw_body(center, piece_radius, body_col)

	# 3. Body border
	_draw_body_border(center, piece_radius, body_col.darkened(0.25))

	# 4. Drop shadow of symbol
	_draw_design(center + _SHADOW_OFFSET * 0.5, piece_radius, shadow_color)

	# 5. Symbol on top
	_draw_design(center, piece_radius, sym_col)

	# 6. Selection highlight (dormant infrastructure)
	if selected:
		var sel_col := Color(1.0, 1.0, 0.4, 0.6)
		_draw_body_border(center, piece_radius * 1.08, sel_col)
		var glow_col := Color(1.0, 1.0, 0.4, 0.15)
		_draw_body(center, piece_radius * 1.15, glow_col)

	# Reset transform
	if visual_scale != Vector2.ONE:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── Body shapes ──

func _draw_body(center: Vector2, radius: float, color: Color) -> void:
	var shape: String = design.body_shape if design.body_shape != "" else "circle"
	match shape:
		"circle":
			draw_circle(center, radius, color)
		"rounded_square":
			_draw_rounded_rect(center, radius * 0.9, radius * 0.2, color)
		"hexagon":
			_draw_regular_polygon(center, radius, 6, color)
		"diamond_body":
			_draw_regular_polygon(center, radius, 4, color)
		"shield":
			_draw_shield(center, radius, color)
		_:
			draw_circle(center, radius, color)


func _draw_body_border(center: Vector2, radius: float, color: Color) -> void:
	var width: float = maxf(1.5, radius * 0.06)
	var shape: String = design.body_shape if design.body_shape != "" else "circle"
	match shape:
		"circle":
			draw_arc(center, radius, 0, TAU, 48, color, width, true)
		"rounded_square":
			var pts: PackedVector2Array = _rounded_rect_points(center, radius * 0.9, radius * 0.2)
			draw_polyline(pts, color, width, true)
		"hexagon":
			var pts: PackedVector2Array = _regular_polygon_points(center, radius, 6)
			pts.append(pts[0])
			draw_polyline(pts, color, width, true)
		"diamond_body":
			var pts: PackedVector2Array = _regular_polygon_points(center, radius, 4)
			pts.append(pts[0])
			draw_polyline(pts, color, width, true)
		"shield":
			var pts: PackedVector2Array = _shield_points(center, radius)
			pts.append(pts[0])
			draw_polyline(pts, color, width, true)
		_:
			draw_arc(center, radius, 0, TAU, 48, color, width, true)


func _draw_rounded_rect(center: Vector2, half_size: float, corner_radius: float, color: Color) -> void:
	draw_colored_polygon(_rounded_rect_points(center, half_size, corner_radius), color)


func _rounded_rect_points(center: Vector2, half_size: float, corner_radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var cr: float = minf(corner_radius, half_size * 0.5)
	var hs: float = half_size
	# Corners: top-right, bottom-right, bottom-left, top-left
	var corners: Array[Vector2] = [
		center + Vector2(hs - cr, -hs + cr),
		center + Vector2(hs - cr, hs - cr),
		center + Vector2(-hs + cr, hs - cr),
		center + Vector2(-hs + cr, -hs + cr),
	]
	var start_angles: Array[float] = [-PI / 2.0, 0.0, PI / 2.0, PI]
	for c_idx in 4:
		for i in 9:
			var angle: float = start_angles[c_idx] + (PI / 2.0) * float(i) / 8.0
			points.append(corners[c_idx] + Vector2(cos(angle), sin(angle)) * cr)
	return points


func _draw_regular_polygon(center: Vector2, radius: float, sides: int, color: Color) -> void:
	draw_colored_polygon(_regular_polygon_points(center, radius, sides), color)


func _regular_polygon_points(center: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in sides:
		var angle: float = -PI / 2.0 + float(i) * TAU / float(sides)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _draw_shield(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(_shield_points(center, radius), color)


func _shield_points(center: Vector2, radius: float) -> PackedVector2Array:
	var w: float = radius * 0.95
	var h: float = radius * 1.1
	return PackedVector2Array([
		center + Vector2(-w, -h * 0.6),
		center + Vector2(w, -h * 0.6),
		center + Vector2(w, h * 0.1),
		center + Vector2(0, h * 0.7),
		center + Vector2(-w, h * 0.1),
	])


# ── Symbol shapes ──

func _draw_design(center: Vector2, radius: float, color: Color) -> void:
	var width: float = maxf(4.0, radius * 0.18) * design.line_width_factor

	match design.design_type:
		"geometric":
			match design.geometric_shape:
				"x": _draw_x(center, radius, color, width)
				"o": _draw_o(center, radius, color, width)
				"triangle": _draw_symbol_triangle(center, radius, color, width)
				"square": _draw_symbol_square(center, radius, color, width)
				"star": _draw_symbol_star(center, radius, color, width)
				"diamond": _draw_symbol_diamond(center, radius, color, width)
		"text":
			_draw_text(center, radius, color)
		"texture":
			_draw_texture(center, radius, color)


func _draw_x(center: Vector2, radius: float, color: Color, width: float) -> void:
	var offset := Vector2(radius, radius) * 0.6
	draw_line(center - offset, center + offset, color, width, true)
	draw_line(center + Vector2(-offset.x, offset.y), center + Vector2(offset.x, -offset.y), color, width, true)


func _draw_o(center: Vector2, radius: float, color: Color, width: float) -> void:
	draw_arc(center, radius * 0.6, 0, TAU, 36, color, width, true)


func _draw_symbol_triangle(center: Vector2, radius: float, color: Color, width: float) -> void:
	var r: float = radius * 0.65
	var points: PackedVector2Array = PackedVector2Array()
	for i in 3:
		var angle: float = -PI / 2.0 + i * TAU / 3.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	points.append(points[0])
	if design.fill:
		draw_colored_polygon(points, color)
	else:
		draw_polyline(points, color, width, true)


func _draw_symbol_square(center: Vector2, radius: float, color: Color, width: float) -> void:
	var r: float = radius * 0.55
	var rect := Rect2(center - Vector2(r, r), Vector2(r * 2, r * 2))
	if design.fill:
		draw_rect(rect, color, true)
	else:
		draw_rect(rect, color, false, width)


func _draw_symbol_star(center: Vector2, radius: float, color: Color, width: float) -> void:
	var outer: float = radius * 0.65
	var inner: float = outer * 0.4
	var points: PackedVector2Array = PackedVector2Array()
	for i in 5:
		var angle_out: float = -PI / 2.0 + i * TAU / 5.0
		points.append(center + Vector2(cos(angle_out), sin(angle_out)) * outer)
		var angle_in: float = angle_out + TAU / 10.0
		points.append(center + Vector2(cos(angle_in), sin(angle_in)) * inner)
	points.append(points[0])
	if design.fill:
		draw_colored_polygon(points, color)
	else:
		draw_polyline(points, color, width, true)


func _draw_symbol_diamond(center: Vector2, radius: float, color: Color, width: float) -> void:
	var rx: float = radius * 0.45
	var ry: float = radius * 0.65
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -ry),
		center + Vector2(rx, 0),
		center + Vector2(0, ry),
		center + Vector2(-rx, 0),
		center + Vector2(0, -ry),
	])
	if design.fill:
		draw_colored_polygon(points, color)
	else:
		draw_polyline(points, color, width, true)


func _draw_text(center: Vector2, radius: float, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = int(radius * 1.4)
	var text: String = design.text_character
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := Vector2(center.x - text_size.x / 2.0, center.y + text_size.y / 4.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_texture(center: Vector2, radius: float, color: Color) -> void:
	if design.texture_image == null:
		return
	var tex_size := Vector2(radius * 1.2, radius * 1.2)
	var rect := Rect2(center - tex_size / 2.0, tex_size)
	draw_texture_rect(design.texture_image, rect, false, color)


# ── Animation ──

func play_move_to(target_pos: Vector2, target_size: Vector2, style: Resource, all_pieces: Array) -> void:
	pivot_offset = size / 2.0
	var start_pos := position
	var travel := target_pos - start_pos
	var travel_dist := travel.length()

	# 1. LIFT
	phase_started.emit("lift")
	var lift_scale := Vector2(1.15, 1.15)
	var lift_pos := Vector2(start_pos.x, start_pos.y - style.lift_height)
	var lift_dur: float = style.arc_duration * 0.35
	var lift_tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_parallel(true)
	lift_tween.tween_property(self, "scale", lift_scale, lift_dur)
	lift_tween.tween_property(self, "position", lift_pos, lift_dur)
	await lift_tween.finished
	phase_completed.emit("lift")

	# 2. ANTICIPATION
	phase_started.emit("anticipation")
	var anticipation_offset := Vector2.ZERO
	if travel_dist > 1.0:
		anticipation_offset = -travel.normalized() * travel_dist * style.anticipation_factor
	var antic_pos := lift_pos + anticipation_offset
	var antic_dur: float = style.arc_duration * 0.25
	var antic_tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	antic_tween.tween_property(self, "position", antic_pos, antic_dur)
	await antic_tween.finished
	phase_completed.emit("anticipation")

	# Trail before arc
	if effect_player and effect_player.has_method("start_trail"):
		effect_player.start_trail(self)

	# 3. ARC TO TARGET — with optional stretch in movement direction
	phase_started.emit("arc")
	if style.arc_stretch > 0.0 and travel_dist > 1.0:
		var dir := travel.normalized()
		var stretch_x: float = 1.0 + style.arc_stretch * absf(dir.x)
		var stretch_y: float = 1.0 + style.arc_stretch * absf(dir.y)
		var squish_x: float = 1.0 / stretch_y  # Preserve volume
		var squish_y: float = 1.0 / stretch_x
		visual_scale = Vector2(maxf(squish_x, stretch_x), maxf(squish_y, stretch_y))
		if absf(dir.x) > absf(dir.y):
			visual_scale = Vector2(1.0 + style.arc_stretch, 1.0 - style.arc_stretch * 0.5)
		else:
			visual_scale = Vector2(1.0 - style.arc_stretch * 0.5, 1.0 + style.arc_stretch)
		queue_redraw()

	var arc_tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_parallel(true)
	arc_tween.tween_property(self, "position", target_pos, style.arc_duration)
	arc_tween.tween_property(self, "size", target_size, style.arc_duration)
	arc_tween.tween_property(self, "scale", Vector2(1.03, 1.03), style.arc_duration)
	if style.spin_rotations > 0:
		rotation = 0.0
		arc_tween.tween_property(self, "rotation", style.spin_rotations * TAU, style.arc_duration) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	await arc_tween.finished
	phase_completed.emit("arc")

	# Stop trail + particles on landing
	if effect_player and effect_player.has_method("stop_trail"):
		effect_player.stop_trail()
		effect_player.play_impact(target_pos + target_size / 2.0)

	# 4. IMPACT — squash on landing + hookpoint for screen effects
	phase_started.emit("impact")
	if style.impact_squash > 0.0:
		visual_scale = Vector2(1.0 + style.impact_squash, 1.0 - style.impact_squash * 0.7)
		queue_redraw()
	phase_completed.emit("impact")

	# 5. SETTLE — spring bounce back to normal
	phase_started.emit("settle")
	if style.spin_rotations > 0:
		var spin_settle := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		spin_settle.tween_property(self, "rotation", 0.0, style.settle_duration)
		await spin_settle.finished

	if style.shake_amount > 0:
		for i in 4:
			var offset := Vector2(
				randf_range(-style.shake_amount, style.shake_amount),
				randf_range(-style.shake_amount, style.shake_amount)
			)
			var shake_tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			shake_tw.tween_property(self, "position", target_pos + offset, style.settle_duration * 0.2)
			await shake_tw.finished

	# Spring bounces for visual_scale (springy jelly effect)
	if style.spring_bounces > 0 and (style.impact_squash > 0.0 or style.arc_stretch > 0.0):
		var bounce_dur: float = style.settle_duration / float(style.spring_bounces)
		for b in style.spring_bounces:
			var intensity: float = 1.0 - float(b) / float(style.spring_bounces)
			var overshoot_x: float = 1.0 - style.impact_squash * 0.3 * intensity
			var overshoot_y: float = 1.0 + style.impact_squash * 0.4 * intensity
			if b % 2 == 1:
				var tmp: float = overshoot_x
				overshoot_x = overshoot_y
				overshoot_y = tmp
			var spring_tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			spring_tw.tween_method(func(v: Vector2): visual_scale = v; queue_redraw(),
				visual_scale, Vector2(overshoot_x, overshoot_y), bounce_dur)
			await spring_tw.finished
		# Final settle to 1,1
		var final_spring := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		final_spring.tween_method(func(v: Vector2): visual_scale = v; queue_redraw(),
			visual_scale, Vector2.ONE, bounce_dur)
		await final_spring.finished
	else:
		visual_scale = Vector2.ONE
		queue_redraw()

	var settle_tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_parallel(true)
	settle_tween.tween_property(self, "scale", Vector2.ONE, style.settle_duration)
	settle_tween.tween_property(self, "position", target_pos, style.settle_duration)
	await settle_tween.finished

	scale = Vector2.ONE
	rotation = 0.0
	visual_scale = Vector2.ONE
	position = target_pos
	size = target_size
	pivot_offset = size / 2.0
	queue_redraw()
	phase_completed.emit("settle")
	move_completed.emit()


# ── Selection infrastructure ──

func set_selectable(val: bool) -> void:
	selectable = val
	mouse_filter = Control.MOUSE_FILTER_STOP if val else Control.MOUSE_FILTER_IGNORE
	if not val and selected:
		set_selected(false)


func set_selected(val: bool) -> void:
	if selected == val:
		return
	selected = val
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not selectable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		piece_clicked.emit(self)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0
		queue_redraw()
