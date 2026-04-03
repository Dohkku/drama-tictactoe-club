extends Control
## An overlay Control that draws an animated border highlight on top of its
## parent PanelContainer.  Add it as a child of the panel you want to
## highlight, set it to fill the entire parent rect, then call
## set_highlighted(true/false) to animate.

const HIGHLIGHT_COLOR := Color(0.95, 0.8, 0.4, 0.85)   # warm gold/amber
const INACTIVE_COLOR  := Color(0.3, 0.3, 0.3, 0.0)     # fully transparent when idle
const HIGHLIGHT_WIDTH := 3.0
const INACTIVE_WIDTH  := 0.0
const CORNER_RADIUS   := 3.0
const TRANSITION_DURATION := 0.3

var _highlighted: bool = false
var _tween: Tween = null
var _border_color: Color = INACTIVE_COLOR
var _border_width: float = INACTIVE_WIDTH


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fill the parent rect
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 10  # draw above siblings


func set_highlighted(active: bool) -> void:
	if active == _highlighted:
		return
	_highlighted = active

	if _tween and _tween.is_valid():
		_tween.kill()

	var target_color: Color = HIGHLIGHT_COLOR if active else INACTIVE_COLOR
	var target_width: float = HIGHLIGHT_WIDTH if active else INACTIVE_WIDTH

	var from_color := _border_color
	var from_width := _border_width

	_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(func(t: float) -> void:
		_border_color = from_color.lerp(target_color, t)
		_border_width = lerpf(from_width, target_width, t)
		queue_redraw()
	, 0.0, 1.0, TRANSITION_DURATION)


func _draw() -> void:
	if _border_width < 0.25 or _border_color.a < 0.01:
		return

	var rect := Rect2(Vector2.ZERO, size).grow(-_border_width * 0.5)

	# Draw with rounded corners if the rect is valid
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	# Use multiple draw_line calls around the perimeter for a clean border
	var half := _border_width * 0.5
	var r := Rect2(Vector2(half, half), size - Vector2(_border_width, _border_width))
	if r.size.x <= 0 or r.size.y <= 0:
		return

	# Top
	draw_line(r.position, Vector2(r.end.x, r.position.y), _border_color, _border_width, true)
	# Bottom
	draw_line(Vector2(r.position.x, r.end.y), r.end, _border_color, _border_width, true)
	# Left
	draw_line(r.position, Vector2(r.position.x, r.end.y), _border_color, _border_width, true)
	# Right
	draw_line(Vector2(r.end.x, r.position.y), r.end, _border_color, _border_width, true)
