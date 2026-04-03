extends Control

signal cell_clicked(index: int)

@export var cell_index: int = 0

var is_occupied: bool = false
var hovering: bool = false
var input_enabled: bool = true
var is_dark_cell: bool = false

var color_empty := Color(0.92, 0.88, 0.82)
var color_alt := Color(0.25, 0.27, 0.32)
var checkerboard := false
var color_hover := Color(0.85, 0.80, 0.72)
var color_line := Color(0.6, 0.5, 0.4)
var line_width := 2.0

var _hover_blend: float = 0.0
var _hover_tween: Tween = null
const _HOVER_SPEED := 0.12


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var base_color := color_alt if (checkerboard and is_dark_cell) else color_empty
	var bg_color := base_color
	if not is_occupied and input_enabled and _hover_blend > 0.0:
		bg_color = base_color.lerp(color_hover, _hover_blend)
	draw_rect(rect, bg_color)
	draw_rect(rect, color_line, false, line_width)


func _gui_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		if not is_occupied and input_enabled:
			cell_clicked.emit(cell_index)


func get_center_position() -> Vector2:
	return global_position + size / 2.0


func set_occupied(occupied: bool) -> void:
	is_occupied = occupied
	queue_redraw()


func clear() -> void:
	is_occupied = false
	queue_redraw()


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	queue_redraw()


func _on_mouse_entered() -> void:
	hovering = true
	_tween_hover(1.0)


func _on_mouse_exited() -> void:
	hovering = false
	_tween_hover(0.0)


func _tween_hover(target: float) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hover_tween.tween_method(_set_hover_blend, _hover_blend, target, _HOVER_SPEED)


func _set_hover_blend(val: float) -> void:
	_hover_blend = val
	queue_redraw()
