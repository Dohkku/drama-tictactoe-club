extends Control
## A thin separator drawn between two panels that creates a subtle 3D
## shadow / depth illusion.  Place it inside a BoxContainer between the
## two panels.  It automatically detects horizontal vs vertical layout
## from its parent.

const SHADOW_ALPHA := 0.15
const SEPARATOR_SIZE := 6  # px


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_minimum_size()
	if get_parent():
		get_parent().resized.connect(_apply_minimum_size)


func _apply_minimum_size() -> void:
	if _is_vertical():
		custom_minimum_size = Vector2(0, SEPARATOR_SIZE)
	else:
		custom_minimum_size = Vector2(SEPARATOR_SIZE, 0)
	queue_redraw()


func _is_vertical() -> bool:
	var parent: Node = get_parent()
	if parent is BoxContainer:
		return parent.vertical
	return false


func _draw() -> void:
	var rect := get_rect()
	var w := rect.size.x
	var h := rect.size.y

	var dark := Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	var clear := Color(0.0, 0.0, 0.0, 0.0)

	if _is_vertical():
		# Horizontal separator — shadow fades top-to-center and center-to-bottom
		var half := h / 2.0
		_draw_vgradient(Rect2(0, 0, w, half), dark, clear)
		_draw_vgradient(Rect2(0, half, w, half), clear, dark)
	else:
		# Vertical separator — shadow fades left-to-center and center-to-right
		var half := w / 2.0
		_draw_hgradient(Rect2(0, 0, half, h), dark, clear)
		_draw_hgradient(Rect2(half, 0, half, h), clear, dark)


func _draw_hgradient(rect: Rect2, from: Color, to: Color) -> void:
	## Draw a horizontal gradient (left to right) by splitting into thin vertical strips.
	var steps := int(max(rect.size.x, 1))
	var strip_w := rect.size.x / float(steps)
	for i in range(steps):
		var t := float(i) / float(max(steps - 1, 1))
		var col := from.lerp(to, t)
		draw_rect(Rect2(rect.position.x + i * strip_w, rect.position.y, strip_w + 1.0, rect.size.y), col, true)


func _draw_vgradient(rect: Rect2, from: Color, to: Color) -> void:
	## Draw a vertical gradient (top to bottom) by splitting into thin horizontal strips.
	var steps := int(max(rect.size.y, 1))
	var strip_h := rect.size.y / float(steps)
	for i in range(steps):
		var t := float(i) / float(max(steps - 1, 1))
		var col := from.lerp(to, t)
		draw_rect(Rect2(rect.position.x, rect.position.y + i * strip_h, rect.size.x, strip_h + 1.0), col, true)
