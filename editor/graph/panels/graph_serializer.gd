class_name GraphSerializer
extends RefCounted

## Handles save/load and serialization of the graph editor.

const GraphThemeC = preload("res://editor/graph/graph_theme.gd")
const ProjectDataScript = preload("res://data/project_data.gd")
const BoardConfigResScript = preload("res://data/board_config.gd")
const CanvasDataScript = preload("res://editor/graph/canvas_data.gd")
const CanvasNodeDataScript = preload("res://editor/graph/canvas_node_data.gd")
const CanvasConnectionDataScript = preload("res://editor/graph/canvas_connection_data.gd")
const CharacterNodeScript = preload("res://editor/graph/nodes/character_node.gd")
const StartNodeScript = preload("res://editor/graph/nodes/start_node.gd")
const CutsceneNodeScript = preload("res://editor/graph/nodes/cutscene_node.gd")
const MatchNodeScript = preload("res://editor/graph/nodes/match_node.gd")
const BoardConfigNodeScript = preload("res://editor/graph/nodes/board_config_node.gd")
const SimultaneousNodeScript = preload("res://editor/graph/nodes/simultaneous_node.gd")

const SAVE_PATH := "user://current_project.tres"

var _main: Control  # GraphEditorMain


func _init(main: Control) -> void:
	_main = main


func graph_to_project_data() -> Resource:
	var project = ProjectDataScript.new()
	project.project_name = "Mi Proyecto"

	for child in _main.graph_edit.get_children():
		if child is CharacterNodeScript and child.character_data:
			project.characters.append(child.character_data)

	for child in _main.graph_edit.get_children():
		if child is BoardConfigNodeScript and child.is_project_default:
			project.board_config = child.board_config
			break

	if project.board_config == null:
		project.board_config = BoardConfigResScript.create_default()

	var start_node: GraphNode = null
	for child in _main.graph_edit.get_children():
		if child is StartNodeScript:
			start_node = child
			break

	if start_node:
		var events := _walk_flow(start_node)
		project.events = events

	project.set_meta("canvas_data", _serialize_canvas())
	project.set_meta("stage_height_ratio", _main._stage_height_ratio)
	project.set_meta("stage_aspect", _main._stage_aspect)
	project.set_meta("stage_max_width", _main._stage_max_width)

	return project


func _walk_flow(start_node: GraphNode) -> Array:
	var events: Array[Resource] = []
	var current_name: StringName = start_node.name
	var visited: Dictionary = {}
	var order := 0

	while current_name != StringName(""):
		if visited.has(current_name):
			break
		visited[current_name] = true

		var next_name: StringName = StringName("")
		for conn in _main.graph_edit.get_connection_list():
			if conn.from_node == current_name:
				var from_node: GraphNode = _main.graph_edit.get_node(String(conn.from_node)) as GraphNode
				if from_node and from_node.is_slot_enabled_right(conn.from_port) and from_node.get_slot_type_right(conn.from_port) == GraphThemeC.PORT_FLOW:
					next_name = conn.to_node
					break

		if next_name == StringName(""):
			break

		var target: Node = _main.graph_edit.get_node(String(next_name))
		if target == null:
			break

		var event := _node_to_event(target, order)
		if event:
			events.append(event)
			order += 1

		current_name = next_name

	return events


func _node_to_event(node: GraphNode, order: int) -> Resource:
	const TournamentEventScript = preload("res://data/tournament_event.gd")
	const MatchConfigScript = preload("res://match_system/match_config.gd")

	if node is CutsceneNodeScript:
		var te = TournamentEventScript.new()
		te.event_type = "cutscene"
		te.event_name = "Cinematica"
		te.cutscene_script_path = node.script_path
		te.order_index = order
		return te

	elif node is MatchNodeScript:
		var te = TournamentEventScript.new()
		te.event_type = "match"
		var mc = MatchConfigScript.new()

		var opponent_id := ""
		for conn in _main.graph_edit.get_connection_list():
			if conn.to_node == node.name and conn.to_port == 1:
				var char_node: Node = _main.graph_edit.get_node(String(conn.from_node))
				if char_node is CharacterNodeScript and char_node.character_data:
					opponent_id = char_node.character_data.character_id
				break

		mc.match_id = opponent_id
		mc.opponent_id = opponent_id
		mc.ai_difficulty = node.match_data.get("ai_difficulty", 0.5)
		mc.player_style = node.match_data.get("player_style", "slam")
		mc.opponent_style = node.match_data.get("opponent_style", "gentle")
		mc.player_effect_name = node.match_data.get("player_effect_name", "none")
		mc.opponent_effect_name = node.match_data.get("opponent_effect_name", "auto")
		mc.placement_offset = node.match_data.get("placement_offset", 0.0)
		mc.player_piece_design = node.match_data.get("player_piece_design", "x")
		mc.opponent_piece_design = node.match_data.get("opponent_piece_design", "o")
		mc.turns_per_visit = node.match_data.get("turns_per_visit", 1)
		mc.starting_player = node.match_data.get("starting_player", "player")
		mc.intro_script = node.match_data.get("intro_script", "")
		mc.reactions_script = node.match_data.get("reactions_script", "")
		mc.game_rules_preset = node.match_data.get("game_rules_preset", "standard")

		for conn in _main.graph_edit.get_connection_list():
			if conn.to_node == node.name and conn.to_port == 2:
				var board_node: Node = _main.graph_edit.get_node(String(conn.from_node))
				if board_node is BoardConfigNodeScript and board_node.board_config:
					mc.board_config = board_node.board_config.copy_config()
				break

		te.match_config = mc
		te.event_name = "vs %s" % opponent_id
		te.order_index = order
		return te

	elif node is SimultaneousNodeScript:
		var te = TournamentEventScript.new()
		te.event_type = "simultaneous"
		te.event_name = "Simultanea"
		te.order_index = order

		for conn in _main.graph_edit.get_connection_list():
			if conn.to_node == node.name and conn.to_port >= 3:
				var char_node: Node = _main.graph_edit.get_node(String(conn.from_node))
				if char_node is CharacterNodeScript and char_node.character_data:
					var mc = MatchConfigScript.new()
					mc.opponent_id = char_node.character_data.character_id
					mc.match_id = "sim_%s" % mc.opponent_id
					var opp_idx: int = conn.to_port - 3
					if opp_idx < node.opponent_configs.size():
						var opp_cfg: Dictionary = node.opponent_configs[opp_idx]
						mc.ai_difficulty = opp_cfg.get("ai_difficulty", 0.5)
						mc.player_style = opp_cfg.get("player_style", "slam")
						mc.opponent_style = opp_cfg.get("opponent_style", "gentle")
					te.simultaneous_configs.append(mc)

		return te

	return null


func _serialize_canvas() -> Resource:
	var canvas = CanvasDataScript.new()
	canvas.canvas_name = "main"
	canvas.scroll_offset = _main.graph_edit.scroll_offset
	canvas.zoom = _main.graph_edit.zoom

	for child in _main.graph_edit.get_children():
		if child is GraphNode:
			var nd = CanvasNodeDataScript.new()
			if child is BaseGraphNode:
				nd.node_id = child.node_id
				nd.node_type = child.get_node_type()
				nd.config = child.get_node_data()
				nd.ref_path = child.get_resource_path()
			nd.position = child.position_offset
			canvas.nodes.append(nd)

	for conn in _main.graph_edit.get_connection_list():
		var cd = CanvasConnectionDataScript.new()
		cd.from_node = _name_to_node_id(conn.from_node)
		cd.from_port = conn.from_port
		cd.to_node = _name_to_node_id(conn.to_node)
		cd.to_port = conn.to_port
		canvas.connections.append(cd)

	return canvas


func _name_to_node_id(node_name: StringName) -> String:
	var node: Node = _main.graph_edit.get_node(String(node_name))
	if node is BaseGraphNode:
		return node.node_id
	return String(node_name)


func import_project_data(project: Resource) -> void:
	if _main._preview_manager and _main._preview_manager._preview_temp_cinematic_editor:
		if _main._preview_manager._preview_temp_cinematic_editor.has_method("dispose_without_save"):
			_main._preview_manager._preview_temp_cinematic_editor.dispose_without_save()
			_main._preview_manager._preview_temp_cinematic_editor = null

	for child in _main.graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()

	await _main.get_tree().process_frame

	var start: GraphNode = _main._node_ops.create_node("start", Vector2(100, 300))
	var prev_name: StringName = start.name
	var x_offset := 400.0

	var char_nodes: Dictionary = {}
	var char_y := 50.0
	for ch in project.characters:
		var cn: GraphNode = _main._node_ops.create_node("character", Vector2(50, char_y))
		cn.set_character(ch)
		char_nodes[ch.character_id] = cn
		char_y += 140.0

	if project.board_config:
		var bcn: GraphNode = _main._node_ops.create_node("board_config", Vector2(50, char_y + 40))
		bcn.set_board_config(project.board_config)
		bcn.is_project_default = true
		bcn._refresh_display()

	var sorted_events: Array = project.events.duplicate()
	sorted_events.sort_custom(func(a, b): return a.order_index < b.order_index)

	for event in sorted_events:
		var node: GraphNode = null

		match event.event_type:
			"cutscene":
				node = _main._node_ops.create_node("cutscene", Vector2(x_offset, 300))
				node.set_script_path(event.cutscene_script_path)

			"match":
				node = _main._node_ops.create_node("match", Vector2(x_offset, 300))
				if event.match_config:
					var mc = event.match_config
					node.match_data = {
						"ai_difficulty": mc.ai_difficulty,
						"player_style": mc.player_style,
						"opponent_style": mc.opponent_style,
						"player_effect_name": mc.player_effect_name,
						"opponent_effect_name": mc.opponent_effect_name,
						"placement_offset": mc.placement_offset,
						"player_piece_design": mc.player_piece_design,
						"opponent_piece_design": mc.opponent_piece_design,
						"turns_per_visit": mc.turns_per_visit,
						"starting_player": mc.starting_player if mc.get("starting_player") else "player",
						"intro_script": mc.intro_script,
						"reactions_script": mc.reactions_script,
						"game_rules_preset": mc.game_rules_preset,
						"custom_rules": mc.board_config != null,
						"board_rules": {},
					}
					node._refresh_display()

					if char_nodes.has(mc.opponent_id):
						await _main.get_tree().process_frame
						_main.graph_edit.connect_node(char_nodes[mc.opponent_id].name, 0, node.name, 1)
						node.set_connected_character(char_nodes[mc.opponent_id].character_data)

			"simultaneous":
				node = _main._node_ops.create_node("simultaneous", Vector2(x_offset, 300))
				for i in range(event.simultaneous_configs.size()):
					var mc = event.simultaneous_configs[i]
					if char_nodes.has(mc.opponent_id):
						while node._opponent_labels.size() <= i:
							node._add_opponent_slot()
						await _main.get_tree().process_frame
						_main.graph_edit.connect_node(char_nodes[mc.opponent_id].name, 0, node.name, 3 + i)

		if node:
			await _main.get_tree().process_frame
			_main.graph_edit.connect_node(prev_name, 0, node.name, 0)
			prev_name = node.name
			x_offset += GraphThemeC.NODE_SEPARATION_X

	var end_node: GraphNode = _main._node_ops.create_node("end", Vector2(x_offset, 300))
	await _main.get_tree().process_frame
	_main.graph_edit.connect_node(prev_name, 0, end_node.name, 0)

	_main.call_deferred("validate_all_nodes")
