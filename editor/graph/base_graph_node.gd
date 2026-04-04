class_name BaseGraphNode
extends GraphNode

## Base class for all custom graph nodes in the editor.
## Provides shared styling, unique ID, and port helpers.

const GraphThemeC = preload("res://editor/graph/graph_theme.gd")

var node_id: String = ""
var accent_color: Color = Color.WHITE


func _init() -> void:
	node_id = _generate_id()


func _ready() -> void:
	_apply_base_theme()
	custom_minimum_size.x = GraphThemeC.NODE_MIN_WIDTH


## Override in subclasses to define the node type string.
func get_node_type() -> String:
	return "base"


## Override to serialize node-specific data.
func get_node_data() -> Dictionary:
	return {}


## Override to restore node-specific data.
func set_node_data(_data: Dictionary) -> void:
	pass


## Override to return a resource path if this node references an external file.
func get_resource_path() -> String:
	return ""


## Called when a connection to this node changes (input connected/disconnected).
func on_connection_changed(_port: int, _connected: bool, _from_node: BaseGraphNode) -> void:
	pass


# ── Port helpers ──

func add_flow_input(slot_idx: int) -> void:
	set_slot(slot_idx,
		true, GraphThemeC.PORT_FLOW, GraphThemeC.COLOR_FLOW,
		false, 0, Color.WHITE)


func add_flow_output(slot_idx: int) -> void:
	set_slot(slot_idx,
		false, 0, Color.WHITE,
		true, GraphThemeC.PORT_FLOW, GraphThemeC.COLOR_FLOW)


func add_flow_through(slot_idx: int) -> void:
	set_slot(slot_idx,
		true, GraphThemeC.PORT_FLOW, GraphThemeC.COLOR_FLOW,
		true, GraphThemeC.PORT_FLOW, GraphThemeC.COLOR_FLOW)


func add_character_input(slot_idx: int) -> void:
	set_slot(slot_idx,
		true, GraphThemeC.PORT_CHARACTER, GraphThemeC.COLOR_CHARACTER,
		false, 0, Color.WHITE)


func add_character_output(slot_idx: int) -> void:
	set_slot(slot_idx,
		false, 0, Color.WHITE,
		true, GraphThemeC.PORT_CHARACTER, GraphThemeC.COLOR_CHARACTER)


func add_board_config_input(slot_idx: int) -> void:
	set_slot(slot_idx,
		true, GraphThemeC.PORT_BOARD_CONFIG, GraphThemeC.COLOR_BOARD_CONFIG,
		false, 0, Color.WHITE)


func add_board_config_output(slot_idx: int) -> void:
	set_slot(slot_idx,
		false, 0, Color.WHITE,
		true, GraphThemeC.PORT_BOARD_CONFIG, GraphThemeC.COLOR_BOARD_CONFIG)


func add_input_port(slot_idx: int, type: int) -> void:
	var col := GraphThemeC.port_color(type)
	set_slot(slot_idx, true, type, col, false, 0, Color.WHITE)


func add_output_port(slot_idx: int, type: int) -> void:
	var col := GraphThemeC.port_color(type)
	set_slot(slot_idx, false, 0, Color.WHITE, true, type, col)


# ── Helpers ──

func _apply_base_theme() -> void:
	var panel := GraphThemeC.node_style(accent_color)
	add_theme_stylebox_override("panel", panel)
	var panel_sel := GraphThemeC.node_style(accent_color, true)
	add_theme_stylebox_override("panel_selected", panel_sel)
	var titlebar := GraphThemeC.titlebar_style(accent_color)
	add_theme_stylebox_override("titlebar", titlebar)
	add_theme_stylebox_override("titlebar_selected", titlebar)
	add_theme_color_override("title_color", GraphThemeC.COLOR_TEXT_HEADER)
	add_theme_font_size_override("title_font_size", GraphThemeC.FONT_SIZE_HEADER)


func _make_label(text: String, font_size: int = GraphThemeC.FONT_SIZE_NORMAL, color: Color = GraphThemeC.COLOR_TEXT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_header_label(text: String) -> Label:
	return _make_label(text, GraphThemeC.FONT_SIZE_HEADER, GraphThemeC.COLOR_TEXT_HEADER)


func _make_dim_label(text: String) -> Label:
	return _make_label(text, GraphThemeC.FONT_SIZE_SMALL, GraphThemeC.COLOR_TEXT_DIM)


static func _generate_id() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var result := ""
	for i in range(8):
		result += chars[randi() % chars.length()]
	return result
