extends "res://editor/graph/base_graph_node.gd"

## Cutscene event node.
## Flow in/out. References a .dscn scene script.
## Compact display: filename only. Preview in detail panel.

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
