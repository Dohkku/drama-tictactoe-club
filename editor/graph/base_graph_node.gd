class_name BaseGraphNode
extends GraphNode

## Base class for all custom graph nodes in the editor.
## Provides shared styling, unique ID, and port helpers.

const GraphThemeC = preload("res://editor/graph/graph_theme.gd")

var node_id: String = ""
var accent_color: Color = Color.WHITE
var _preview_active_color_saved: Color = Color.WHITE
var _last_validation: Dictionary = {"valid": true, "warnings": [], "errors": []}


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


## Override in subclasses to provide node-specific validation.
## Returns {valid: bool, warnings: Array[String], errors: Array[String]}.
func validate() -> Dictionary:
	return {"valid": true, "warnings": [], "errors": []}


## Reads validate() result and updates visual feedback on the node.
func update_validation_display() -> void:
	_last_validation = validate()
	var has_errors: bool = _last_validation.errors.size() > 0
	var has_warnings: bool = _last_validation.warnings.size() > 0

	# Update panel/titlebar styles to show validation state
	if has_errors:
		_apply_validation_theme(Color(0.9, 0.2, 0.2))
	elif has_warnings:
		_apply_validation_theme(Color(0.95, 0.7, 0.15))
	else:
		# Restore normal theme
		_apply_base_theme()

	# Tooltip with all messages
	var messages: PackedStringArray = []
	for e in _last_validation.errors:
		messages.append("[error] %s" % e)
	for w in _last_validation.warnings:
		messages.append("[aviso] %s" % w)
	tooltip_text = "\n".join(messages) if messages.size() > 0 else ""


## Notify the graph editor to re-validate all nodes.
## Call this from _refresh_display or whenever node data changes.
func _notify_validation_needed() -> void:
	if not is_inside_tree():
		return
	# Walk up from GraphEdit to find the main editor with validate_all_nodes
	var node := get_parent()
	while node != null:
		if node.has_method("validate_all_nodes"):
			node.call_deferred("validate_all_nodes")
			return
		node = node.get_parent()


## Helper: check if this node has a flow connection on a specific input port.
func _has_flow_input_connection(graph_edit: GraphEdit, port: int) -> bool:
	for conn in graph_edit.get_connection_list():
		if conn.to_node == name and conn.to_port == port:
			return true
	return false


## Helper: check if this node has a flow connection on a specific output port.
func _has_flow_output_connection(graph_edit: GraphEdit, port: int) -> bool:
	for conn in graph_edit.get_connection_list():
		if conn.from_node == name and conn.from_port == port:
			return true
	return false


## Helper: count how many connections exist on a specific input port type.
func _count_input_connections(graph_edit: GraphEdit, port: int) -> int:
	var count := 0
	for conn in graph_edit.get_connection_list():
		if conn.to_node == name and conn.to_port == port:
			count += 1
	return count


## Helper: count input connections on ports >= start_port.
func _count_input_connections_from_port(graph_edit: GraphEdit, start_port: int) -> int:
	var count := 0
	for conn in graph_edit.get_connection_list():
		if conn.to_node == name and conn.to_port >= start_port:
			count += 1
	return count


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


func _apply_validation_theme(validation_color: Color) -> void:
	# Panel: use node bg but with validation border
	var panel := StyleBoxFlat.new()
	panel.bg_color = GraphThemeC.COLOR_NODE_BG
	panel.border_color = validation_color
	panel.set_border_width_all(2)
	panel.border_width_left = 4
	panel.set_corner_radius_all(6)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	add_theme_stylebox_override("panel", panel)

	var panel_sel := panel.duplicate()
	panel_sel.bg_color = GraphThemeC.COLOR_NODE_BG_SELECTED
	add_theme_stylebox_override("panel_selected", panel_sel)

	# Titlebar: tinted with validation color
	var titlebar := StyleBoxFlat.new()
	titlebar.bg_color = validation_color.darkened(0.6)
	titlebar.border_color = validation_color
	titlebar.set_border_width_all(0)
	titlebar.border_width_bottom = 2
	titlebar.border_width_top = 2
	titlebar.border_width_left = 2
	titlebar.border_width_right = 2
	titlebar.set_corner_radius_all(0)
	titlebar.corner_radius_top_left = 6
	titlebar.corner_radius_top_right = 6
	titlebar.content_margin_left = 12
	titlebar.content_margin_right = 12
	titlebar.content_margin_top = 6
	titlebar.content_margin_bottom = 6
	add_theme_stylebox_override("titlebar", titlebar)
	add_theme_stylebox_override("titlebar_selected", titlebar)


func set_preview_active(active: bool) -> void:
	if active:
		_preview_active_color_saved = accent_color
		accent_color = Color(1.0, 0.92, 0.3)  # Amarillo cálido para highlight
	else:
		accent_color = _preview_active_color_saved
	_apply_base_theme()


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
