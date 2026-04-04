extends "res://editor/graph/base_graph_node.gd"

## Cutscene event node.
## Flow in/out. References a .dscn scene script.
## Shows script filename and first few lines as preview.

var script_path: String = ""
var _path_label: Label = null
var _preview_label: Label = null


func _init() -> void:
	super._init()
	accent_color = GraphThemeC.COLOR_CUTSCENE


func _ready() -> void:
	title = "CINEMATICA"
	custom_minimum_size.x = 200
	super._ready()

	# Row 0: flow through + script path
	_path_label = _make_label("(sin script)", GraphThemeC.FONT_SIZE_NORMAL, GraphThemeC.COLOR_TEXT)
	_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_path_label)
	add_flow_through(0)

	# Row 1: preview text
	_preview_label = _make_dim_label("")
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.custom_minimum_size.y = 30
	add_child(_preview_label)
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
			_path_label.text = script_path.get_file()
		else:
			_path_label.text = "(sin script)"

	if _preview_label and script_path != "":
		_load_preview()


func _load_preview() -> void:
	if not FileAccess.file_exists(script_path):
		_preview_label.text = "(archivo no encontrado)"
		return

	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return

	var lines: PackedStringArray = []
	var count := 0
	while not file.eof_reached() and count < 3:
		var line := file.get_line().strip_edges()
		if line != "" and not line.begins_with("@") and not line.begins_with("#"):
			lines.append(line)
			count += 1

	_preview_label.text = "\n".join(lines) if lines.size() > 0 else "(vacio)"
