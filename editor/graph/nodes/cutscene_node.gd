extends "res://editor/graph/base_graph_node.gd"

## Cutscene event node.
## Flow in/out. References a .dscn scene script.
## Double-click or button opens the cinematic sub-editor.

signal editor_requested(node)

var script_path: String = ""
var _path_label: Label = null


func _init() -> void:
	super._init()
	accent_color = GraphThemeC.COLOR_CUTSCENE


func _ready() -> void:
	title = "CINEMATICA"
	custom_minimum_size.x = 160
	super._ready()

	# Row 0: flow through + script filename
	_path_label = _make_label("(sin script)", GraphThemeC.FONT_SIZE_NORMAL, GraphThemeC.COLOR_TEXT)
	_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_path_label.custom_maximum_size.x = 150
	add_child(_path_label)
	add_flow_through(0)

	# Row 1: open editor button — prominent
	var btn := Button.new()
	btn.text = ">> Editar escena <<"
	btn.add_theme_font_size_override("font_size", 12)
	btn.custom_minimum_size = Vector2(0, 28)
	var s_normal := StyleBoxFlat.new()
	s_normal.bg_color = Color(0.25, 0.45, 0.85)
	s_normal.set_corner_radius_all(4)
	s_normal.content_margin_left = 8
	s_normal.content_margin_right = 8
	s_normal.content_margin_top = 4
	s_normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", s_normal)
	var s_hover := StyleBoxFlat.new()
	s_hover.bg_color = Color(0.35, 0.55, 0.95)
	s_hover.set_corner_radius_all(4)
	s_hover.content_margin_left = 8
	s_hover.content_margin_right = 8
	s_hover.content_margin_top = 4
	s_hover.content_margin_bottom = 4
	btn.add_theme_stylebox_override("hover", s_hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(func(): editor_requested.emit(self))
	add_child(btn)
	set_slot_enabled_left(1, false)
	set_slot_enabled_right(1, false)

	if script_path != "":
		_refresh_display()


func get_node_type() -> String:
	return "cutscene"


func get_node_data() -> Dictionary:
	return {"script_path": script_path}


func set_node_data(data: Dictionary) -> void:
	script_path = data.get("script_path", "")
	_refresh_display()


func get_resource_path() -> String:
	return script_path


func set_script_path(path: String) -> void:
	script_path = path
	if is_inside_tree():
		_refresh_display()


func _refresh_display() -> void:
	if _path_label:
		if script_path != "":
			_path_label.text = script_path.get_file().get_basename()
		else:
			_path_label.text = "(sin script)"
