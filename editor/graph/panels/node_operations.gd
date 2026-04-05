class_name NodeOperations
extends RefCounted

## Manages node creation, deletion, connections, copy/paste, and undo/redo.

const GraphThemeC = preload("res://editor/graph/graph_theme.gd")
const ConnectionRulesC = preload("res://editor/graph/connection_rules.gd")
const StartNodeScript = preload("res://editor/graph/nodes/start_node.gd")
const EndNodeScript = preload("res://editor/graph/nodes/end_node.gd")
const CharacterNodeScript = preload("res://editor/graph/nodes/character_node.gd")
const CutsceneNodeScript = preload("res://editor/graph/nodes/cutscene_node.gd")
const MatchNodeScript = preload("res://editor/graph/nodes/match_node.gd")
const BoardConfigNodeScript = preload("res://editor/graph/nodes/board_config_node.gd")
const SimultaneousNodeScript = preload("res://editor/graph/nodes/simultaneous_node.gd")
const CommentNodeScript = preload("res://editor/graph/nodes/comment_node.gd")

var _main: Control  # GraphEditorMain
var _clipboard: Array = []


func _init(main: Control) -> void:
	_main = main


func create_node(type: String, pos: Vector2 = Vector2.ZERO) -> GraphNode:
	var node: GraphNode = null
	match type:
		"start":
			node = StartNodeScript.new()
		"end":
			node = EndNodeScript.new()
		"character":
			node = CharacterNodeScript.new()
		"cutscene":
			node = CutsceneNodeScript.new()
		"match":
			node = MatchNodeScript.new()
		"board_config":
			node = BoardConfigNodeScript.new()
		"simultaneous":
			node = SimultaneousNodeScript.new()
		"comment":
			node = CommentNodeScript.new()

	if node == null:
		return null

	node.position_offset = pos
	node.name = StringName(node.node_id)
	_main.graph_edit.add_child(node)

	if node is CutsceneNodeScript and node.has_signal("editor_requested"):
		node.editor_requested.connect(_main._preview_manager.open_cinematic_editor)

	_main.call_deferred("validate_all_nodes")
	return node


func on_context_menu_selected(id: int) -> void:
	var type := ""
	match id:
		0: type = "cutscene"
		1: type = "match"
		2: type = "character"
		3: type = "board_config"
		4: type = "simultaneous"
		5: type = "comment"
		6: type = "end"
	if type != "":
		undo_create_node(type, _main._context_position)


func undo_create_node(type: String, pos: Vector2) -> GraphNode:
	var node := create_node(type, pos)
	if node == null:
		return null
	var node_name: StringName = node.name
	_main._undo_redo.create_action("Create %s node" % type)
	_main._undo_redo.add_do_method(_noop)
	_main._undo_redo.add_undo_method(_remove_node_by_name.bind(node_name))
	_main._undo_redo.commit_action(false)
	return node


func _remove_node_by_name(node_name: StringName) -> void:
	var node: Node = _main.graph_edit.get_node_or_null(String(node_name))
	if node == null:
		return
	for conn in _main.graph_edit.get_connection_list():
		if conn.from_node == node_name or conn.to_node == node_name:
			_main.graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	node.queue_free()


func _noop() -> void:
	pass


# ── Connections ──

func on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from: GraphNode = _main.graph_edit.get_node(String(from_node)) as GraphNode
	var to: GraphNode = _main.graph_edit.get_node(String(to_node)) as GraphNode
	if from == null or to == null:
		return

	var from_type := from.get_slot_type_right(from_port)
	var to_type := to.get_slot_type_left(to_port)

	if from_type != to_type:
		return

	if from_type == GraphThemeC.PORT_FLOW:
		if not ConnectionRulesC.flow_output_is_free(_main.graph_edit, from_node, from_port):
			for conn in _main.graph_edit.get_connection_list():
				if conn.from_node == from_node and conn.from_port == from_port:
					_main.graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
					_notify_disconnection(conn.to_node, conn.to_port)
					break
		if not ConnectionRulesC.flow_input_is_free(_main.graph_edit, to_node, to_port):
			for conn in _main.graph_edit.get_connection_list():
				if conn.to_node == to_node and conn.to_port == to_port:
					_main.graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
					_notify_disconnection(conn.to_node, conn.to_port)
					break
		if ConnectionRulesC.would_create_cycle(_main.graph_edit, from_node, to_node):
			return

	elif from_type == GraphThemeC.PORT_CHARACTER or from_type == GraphThemeC.PORT_BOARD_CONFIG:
		for conn in _main.graph_edit.get_connection_list():
			if conn.to_node == to_node and conn.to_port == to_port:
				_main.graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
				_notify_disconnection(conn.to_node, conn.to_port)
				break

	_main.graph_edit.connect_node(from_node, from_port, to_node, to_port)

	if to is BaseGraphNode:
		to.on_connection_changed(to_port, true, from as BaseGraphNode)

	_main._undo_redo.create_action("Connect nodes")
	_main._undo_redo.add_do_method(_noop)
	_main._undo_redo.add_undo_method(_do_disconnect.bind(from_node, from_port, to_node, to_port))
	_main._undo_redo.commit_action(false)

	_main.validate_all_nodes()


func on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	_main.graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_notify_disconnection(to_node, to_port)
	_main._undo_redo.create_action("Disconnect nodes")
	_main._undo_redo.add_do_method(_noop)
	_main._undo_redo.add_undo_method(_do_connect.bind(from_node, from_port, to_node, to_port))
	_main._undo_redo.commit_action(false)

	_main.validate_all_nodes()


func _do_disconnect(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	_main.graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_notify_disconnection(to_node, to_port)


func _do_connect(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	_main.graph_edit.connect_node(from_node, from_port, to_node, to_port)
	var to: Node = _main.graph_edit.get_node_or_null(String(to_node))
	var from: Node = _main.graph_edit.get_node_or_null(String(from_node))
	if to is BaseGraphNode and from is BaseGraphNode:
		to.on_connection_changed(to_port, true, from)


func _notify_disconnection(to_node_name: StringName, to_port: int) -> void:
	var to: Node = _main.graph_edit.get_node(String(to_node_name))
	if to is BaseGraphNode:
		to.on_connection_changed(to_port, false, null)


# ── Selection ─���

func on_node_selected(node: Node) -> void:
	_main._selected_node = node as GraphNode
	_main._detail_builder.show_detail_for_node(_main._selected_node)


func on_node_deselected(node: Node) -> void:
	if _main._selected_node == node:
		_main._selected_node = null
		_main._detail_builder.show_welcome_panel()


func on_delete_nodes_request(nodes: Array[StringName]) -> void:
	for node_name in nodes:
		var node: Node = _main.graph_edit.get_node(String(node_name))
		if node == null:
			continue
		if node is StartNodeScript:
			continue
		var removed_connections: Array = []
		for conn in _main.graph_edit.get_connection_list():
			if conn.from_node == node_name or conn.to_node == node_name:
				removed_connections.append(conn.duplicate())
				_main.graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)

		var node_type := ""
		var node_data := {}
		var node_pos: Vector2 = node.position_offset
		if node is BaseGraphNode:
			node_type = node.get_node_type()
			node_data = node.get_node_data()

		node.queue_free()

		if node_type != "":
			_main._undo_redo.create_action("Delete %s" % node_type)
			_main._undo_redo.add_do_method(_noop)
			_main._undo_redo.add_undo_method(_undo_delete_node.bind(node_type, node_pos, node_data, removed_connections))
			_main._undo_redo.commit_action(false)

	if _main._selected_node and is_instance_valid(_main._selected_node) == false:
		_main._selected_node = null
		_main._detail_builder.show_welcome_panel()

	_main.call_deferred("validate_all_nodes")


func _undo_delete_node(type: String, pos: Vector2, data: Dictionary, connections: Array) -> void:
	var node := create_node(type, pos)
	if node == null:
		return
	if node is BaseGraphNode:
		node.set_node_data(data)
	await _main.get_tree().process_frame
	for conn in connections:
		var fn: StringName = conn.from_node
		var tn: StringName = conn.to_node
		if _main.graph_edit.get_node_or_null(String(fn)) and _main.graph_edit.get_node_or_null(String(tn)):
			_main.graph_edit.connect_node(fn, conn.from_port, tn, conn.to_port)


# ── Copy / Paste / Duplicate ──

func on_copy_nodes() -> void:
	_clipboard.clear()
	for child in _main.graph_edit.get_children():
		if child is BaseGraphNode and child.selected and not child is StartNodeScript:
			_clipboard.append({
				"type": child.get_node_type(),
				"data": child.get_node_data(),
				"pos": child.position_offset,
			})


func on_paste_nodes() -> void:
	if _clipboard.is_empty():
		return
	for child in _main.graph_edit.get_children():
		if child is GraphNode:
			child.selected = false
	var offset := Vector2(40, 40)
	for entry in _clipboard:
		var node := create_node(entry.type, entry.pos + offset)
		if node and node is BaseGraphNode:
			node.set_node_data(entry.data)
			node.selected = true


func on_duplicate_nodes() -> void:
	on_copy_nodes()
	on_paste_nodes()


func on_popup_request(at_position: Vector2) -> void:
	_main._context_position = (_main.graph_edit.scroll_offset + at_position) / _main.graph_edit.zoom
	_main._popup_menu.position = Vector2i(_main.get_viewport().get_mouse_position())
	_main._popup_menu.popup()
