class_name CinematicEditor
extends RefCounted

## Sub-canvas editor for cinematic scripts.
## Creates a second GraphEdit that replaces the main view.
## Each DSL command is a visual node.

const GraphThemeC = preload("res://editor/graph/graph_theme.gd")
const ConnectionRulesC = preload("res://editor/graph/connection_rules.gd")
const CmdNodeScript = preload("res://editor/graph/cinematic/cinematic_command_node.gd")
const SerializerScript = preload("res://editor/graph/cinematic/cinematic_serializer.gd")
const StartNodeScript = preload("res://editor/graph/nodes/start_node.gd")
const EndNodeScript = preload("res://editor/graph/nodes/end_node.gd")

var graph_edit: GraphEdit = null
var cutscene_node = null  # The CutsceneNode being edited
var characters: Array = []  # Array[CharacterData] from root canvas
var scene_name: String = ""
var scene_background: String = ""
var _popup_menu: PopupMenu = null


func open(p_cutscene_node, p_characters: Array, parent: Control) -> void:
	cutscene_node = p_cutscene_node
	characters = p_characters

	# Create the cinematic GraphEdit
	graph_edit = GraphEdit.new()
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.snapping_enabled = true
	graph_edit.snapping_distance = GraphThemeC.SNAP_DISTANCE
	graph_edit.minimap_enabled = true
	graph_edit.minimap_size = Vector2(160, 100)
	graph_edit.right_disconnects = true
	graph_edit.show_grid = true
	graph_edit.panning_scheme = GraphEdit.SCROLL_PANS
	parent.add_child(graph_edit)

	# Connection types
	graph_edit.add_valid_connection_type(GraphThemeC.PORT_FLOW, GraphThemeC.PORT_FLOW)
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	graph_edit.popup_request.connect(_on_popup_request)

	# Context menu
	_popup_menu = PopupMenu.new()
	var categories: Array = CmdNodeScript.CATEGORIES.keys()
	for i in range(categories.size()):
		var cat_key: String = categories[i]
		var cat_data: Dictionary = CmdNodeScript.CATEGORIES[cat_key]
		_popup_menu.add_item(cat_data.label, i)
	_popup_menu.id_pressed.connect(_on_popup_selected)
	graph_edit.add_child(_popup_menu)

	# Load existing .dscn if available
	if cutscene_node.script_path != "" and FileAccess.file_exists(cutscene_node.script_path):
		var text: String = FileAccess.get_file_as_string(cutscene_node.script_path)
		var meta: Dictionary = SerializerScript.dscn_to_graph(text, graph_edit, characters)
		scene_name = meta.get("name", "")
		scene_background = meta.get("background", "")
	else:
		# Create default start/end
		var start := StartNodeScript.new()
		start.position_offset = Vector2(50, 200)
		start.name = StringName(start.node_id)
		graph_edit.add_child(start)

		var end_node := EndNodeScript.new()
		end_node.position_offset = Vector2(600, 200)
		end_node.name = StringName(end_node.node_id)
		graph_edit.add_child(end_node)

		graph_edit.connect_node(start.name, 0, end_node.name, 0)
		scene_name = "new_scene"


func close() -> void:
	if graph_edit == null:
		return

	# Serialize back to .dscn
	var text: String = SerializerScript.graph_to_dscn(graph_edit, scene_name, scene_background)

	# Write to file
	if cutscene_node.script_path != "":
		var f := FileAccess.open(cutscene_node.script_path, FileAccess.WRITE)
		if f:
			f.store_string(text)
			f.close()
			print("[CinematicEditor] Saved: %s" % cutscene_node.script_path)

	# Cleanup
	graph_edit.queue_free()
	graph_edit = null


func _create_command_node(cat: String, pos: Vector2) -> void:
	var node := CmdNodeScript.new()
	node.category = cat
	node.available_characters = characters
	node.position_offset = pos
	node.name = StringName(node.node_id)
	graph_edit.add_child(node)


# ── Connections ──

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from := graph_edit.get_node(String(from_node)) as GraphNode
	var to := graph_edit.get_node(String(to_node)) as GraphNode
	if from == null or to == null:
		return

	var from_type := from.get_slot_type_right(from_port)
	var to_type := to.get_slot_type_left(to_port)
	if from_type != to_type:
		return

	# Flow: 1:1, replace existing
	if from_type == GraphThemeC.PORT_FLOW:
		if not ConnectionRulesC.flow_output_is_free(graph_edit, from_node, from_port):
			for conn in graph_edit.get_connection_list():
				if conn.from_node == from_node and conn.from_port == from_port:
					graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
					break
		if not ConnectionRulesC.flow_input_is_free(graph_edit, to_node, to_port):
			for conn in graph_edit.get_connection_list():
				if conn.to_node == to_node and conn.to_port == to_port:
					graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
					break
		if ConnectionRulesC.would_create_cycle(graph_edit, from_node, to_node):
			return

	graph_edit.connect_node(from_node, from_port, to_node, to_port)


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	for node_name in nodes:
		var node := graph_edit.get_node(String(node_name))
		if node == null or node is StartNodeScript:
			continue
		for conn in graph_edit.get_connection_list():
			if conn.from_node == node_name or conn.to_node == node_name:
				graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
		node.queue_free()


var _popup_pos: Vector2 = Vector2.ZERO

func _on_popup_request(at_position: Vector2) -> void:
	_popup_pos = (graph_edit.scroll_offset + at_position) / graph_edit.zoom
	_popup_menu.position = Vector2i(graph_edit.get_viewport().get_mouse_position())
	_popup_menu.popup()


func _on_popup_selected(id: int) -> void:
	var keys: Array = CmdNodeScript.CATEGORIES.keys()
	if id >= 0 and id < keys.size():
		_create_command_node(keys[id], _popup_pos)
