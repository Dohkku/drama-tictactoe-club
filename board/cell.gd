extends Control

signal cell_clicked(index: int)

@export var cell_index: int = 0

var is_occupied: bool = false
var hovering: bool = false
var input_enabled: bool = true

const COLOR_EMPTY := Color(0.15, 0.15, 0.2)
const COLOR_HOVER := Color(0.25, 0.25, 0.35)
const COLOR_LINE := Color(0.3, 0.3, 0.4)


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var bg_color := COLOR_HOVER if (hovering and not is_occupied and input_enabled) else COLOR_EMPTY
	draw_rect(rect, bg_color)
	draw_rect(rect, COLOR_LINE, false, 2.0)


func _gui_input(event: InputEvent) -> void:
	var is_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_touch = event is InputEventScreenTouch and event.pressed
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
	queue_redraw()


func _on_mouse_exited() -> void:
	hovering = false
	queue_redraw()
