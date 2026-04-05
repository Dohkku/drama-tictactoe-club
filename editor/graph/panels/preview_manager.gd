class_name PreviewManager
extends RefCounted

## Manages cinematic sub-editor and preview/play functionality.

const CinematicEditorScript = preload("res://editor/graph/cinematic/cinematic_editor.gd")
const CharacterNodeScript = preload("res://editor/graph/nodes/character_node.gd")
const CutsceneNodeScript = preload("res://editor/graph/nodes/cutscene_node.gd")
const MatchNodeScript = preload("res://editor/graph/nodes/match_node.gd")
const StartNodeScript = preload("res://editor/graph/nodes/start_node.gd")
const GraphThemeC = preload("res://editor/graph/graph_theme.gd")

var _main: Control  # GraphEditorMain
var _cinematic_editor: RefCounted = null
var _preview_temp_cinematic_editor: RefCounted = null
var _game_preview_window: Window = null


func _init(main: Control) -> void:
	_main = main


func open_cinematic_editor(cutscene_node) -> void:
	if _preview_temp_cinematic_editor and _preview_temp_cinematic_editor.has_method("dispose_without_save"):
		_preview_temp_cinematic_editor.dispose_without_save()
		_preview_temp_cinematic_editor = null
	if _cinematic_editor != null:
		return

	var chars: Array = []
	for child in _main.graph_edit.get_children():
		if child is CharacterNodeScript and child.character_data:
			chars.append(child.character_data)

	_cinematic_editor = CinematicEditorScript.new()
	_cinematic_editor.open(cutscene_node, chars, _main._graph_parent)

	_main.graph_edit.visible = false
	_main._breadcrumb_label.text = "Canvas > %s" % (cutscene_node.script_path.get_file().get_basename() if cutscene_node.script_path != "" else "nueva escena")
	_main._detail_builder.clear_detail()
	_main._detail_builder.show_welcome_panel()


func close_cinematic_editor() -> void:
	if _cinematic_editor == null:
		return
	_cinematic_editor._close_preview()
	_cinematic_editor.close()
	_cinematic_editor = null
	_main.graph_edit.visible = true
	_main._breadcrumb_label.text = "Editor 2.0 — Canvas"
	_main._detail_builder.show_welcome_panel()


func on_preview_toolbar_pressed() -> void:
	if _cinematic_editor:
		_cinematic_editor.open_preview()
		return
	open_combined_preview()


func is_in_cinematic_editor() -> bool:
	return _cinematic_editor != null


func get_all_flow_nodes() -> Array:
	var start_node: GraphNode = null
	for child in _main.graph_edit.get_children():
		if child is StartNodeScript:
			start_node = child
			break
	if start_node == null:
		return []

	var result: Array = []
	var current_name: StringName = start_node.name
	var visited: Dictionary = {}
	while current_name != StringName(""):
		if visited.has(current_name):
			break
		visited[current_name] = true
		var node: Node = _main.graph_edit.get_node_or_null(String(current_name))
		if node is CutsceneNodeScript or node is MatchNodeScript:
			result.append(node)
		var next_name: StringName = StringName("")
		for conn in _main.graph_edit.get_connection_list():
			if conn.from_node == current_name:
				next_name = conn.to_node
				break
		current_name = next_name
	return result


func open_preview_from_main(cutscene_nodes: Array) -> void:
	if _preview_temp_cinematic_editor and _preview_temp_cinematic_editor.has_method("is_preview_open"):
		if _preview_temp_cinematic_editor.is_preview_open():
			_preview_temp_cinematic_editor.open_preview()
			return
		if _preview_temp_cinematic_editor.has_method("dispose_without_save"):
			_preview_temp_cinematic_editor.dispose_without_save()
		_preview_temp_cinematic_editor = null

	var chars: Array = []
	for child in _main.graph_edit.get_children():
		if child is CharacterNodeScript and child.character_data:
			chars.append(child.character_data)

	var idx := 0
	var _open_next: Callable
	_open_next = func():
		if idx >= cutscene_nodes.size():
			if _preview_temp_cinematic_editor:
				_preview_temp_cinematic_editor.dispose_without_save()
				_preview_temp_cinematic_editor = null
			return

		var cutscene_node = cutscene_nodes[idx]
		idx += 1

		if _preview_temp_cinematic_editor and _preview_temp_cinematic_editor.has_method("dispose_without_save"):
			_preview_temp_cinematic_editor.dispose_without_save()

		var temp_editor := CinematicEditorScript.new()
		_preview_temp_cinematic_editor = temp_editor
		temp_editor.open(cutscene_node, chars, _main._graph_parent)
		temp_editor.graph_edit.visible = false
		temp_editor.open_preview()

		var auto_advance_timer := Timer.new()
		auto_advance_timer.wait_time = 0.3
		auto_advance_timer.autostart = true
		_main._graph_parent.add_child(auto_advance_timer)
		auto_advance_timer.timeout.connect(func():
			if temp_editor != _preview_temp_cinematic_editor:
				auto_advance_timer.queue_free()
				return
			if not temp_editor.is_preview_open():
				auto_advance_timer.queue_free()
				return
			if temp_editor._preview_step_index >= temp_editor._preview_commands.size() and not temp_editor._preview_commands.is_empty():
				auto_advance_timer.queue_free()
				if idx < cutscene_nodes.size():
					_open_next.call()
				else:
					pass)

		temp_editor.preview_closed.connect(func():
			auto_advance_timer.queue_free()
			if temp_editor == _preview_temp_cinematic_editor:
				temp_editor.dispose_without_save()
				_preview_temp_cinematic_editor = null)

	_open_next.call()


func open_combined_preview() -> void:
	var flow_nodes: Array = get_all_flow_nodes()
	if flow_nodes.is_empty():
		push_warning("Editor2: No hay nodos para previsualizar.")
		return

	_main._on_save_pressed()

	const SceneParserScript = preload("res://systems/scene_runner/scene_parser.gd")
	var all_commands: Array = []
	var first_bg: String = ""
	var first_cutscene = null

	for node in flow_nodes:
		if node is CutsceneNodeScript:
			if first_cutscene == null:
				first_cutscene = node
			if node.script_path == "" or not FileAccess.file_exists(node.script_path):
				continue
			var text: String = FileAccess.get_file_as_string(node.script_path)
			var parsed: Dictionary = SceneParserScript.parse(text)
			if first_bg == "":
				first_bg = parsed.get("background", "")
			all_commands.append_array(parsed.get("commands", []))

		elif node is MatchNodeScript:
			var opponent_name: String = "???"
			for conn in _main.graph_edit.get_connection_list():
				if conn.to_node == node.name and conn.to_port == 1:
					var char_node: Node = _main.graph_edit.get_node_or_null(String(conn.from_node))
					if char_node is CharacterNodeScript and char_node.character_data:
						opponent_name = char_node.character_data.display_name if char_node.character_data.display_name != "" else char_node.character_data.character_id
					break
			var diff: float = node.match_data.get("ai_difficulty", 0.5)
			all_commands.append({"type": "transition", "style": "fade_black", "duration": 0.6})
			all_commands.append({"type": "title_card", "title": "PARTIDA vs %s" % opponent_name, "subtitle": "IA: %d%%" % int(diff * 100)})
			all_commands.append({"type": "transition", "style": "fade_black", "duration": 0.6})

	if first_cutscene == null:
		push_warning("Editor2: No hay cinemáticas en el flujo.")
		return
	if all_commands.is_empty():
		push_warning("Editor2: No hay comandos para previsualizar.")
		return

	if _preview_temp_cinematic_editor and _preview_temp_cinematic_editor.has_method("dispose_without_save"):
		_preview_temp_cinematic_editor.dispose_without_save()
		_preview_temp_cinematic_editor = null

	var chars: Array = []
	for child in _main.graph_edit.get_children():
		if child is CharacterNodeScript and child.character_data:
			chars.append(child.character_data)

	var temp_editor := CinematicEditorScript.new()
	_preview_temp_cinematic_editor = temp_editor
	temp_editor.preview_closed.connect(func():
		if temp_editor == _preview_temp_cinematic_editor:
			temp_editor.dispose_without_save()
			_preview_temp_cinematic_editor = null)
	temp_editor.open(first_cutscene, chars, _main._graph_parent)
	temp_editor.graph_edit.visible = false
	if first_bg != "":
		temp_editor.scene_background = first_bg
	await temp_editor.open_preview()

	temp_editor._preview_commands_locked = true
	temp_editor._preview_commands = all_commands
	var SerializerScript2 = preload("res://editor/graph/cinematic/cinematic_serializer.gd")
	temp_editor._preview_dscn_cache = SerializerScript2.graph_to_dscn(temp_editor.graph_edit, temp_editor.scene_name, temp_editor.scene_background)
	temp_editor._preview_step_index = 0
	temp_editor._update_step_label()


func preview_single_cutscene(cutscene_node) -> void:
	## Editor button on a cinematic node: save graph, preview just that .dscn
	## in the existing lightweight cutscene preview window.
	_main._on_save_pressed()
	open_preview_from_main([cutscene_node])


func preview_single_match(match_node) -> void:
	## Editor button on a match node: build a mini ProjectData containing only
	## this match and launch main.tscn in the game preview Window. Characters,
	## board_config and stage metadata are copied from the full project so the
	## cinematic stage + board have everything they need.
	_main._on_save_pressed()
	var full_project: Resource = _main._serializer.graph_to_project_data()
	if full_project == null:
		push_warning("Editor2: No se pudo serializar el proyecto para preview.")
		return

	var target_match_id: String = ""
	for conn in _main.graph_edit.get_connection_list():
		if conn.to_node == match_node.name and conn.to_port == 1:
			var char_node: Node = _main.graph_edit.get_node_or_null(String(conn.from_node))
			if char_node is CharacterNodeScript and char_node.character_data:
				target_match_id = char_node.character_data.character_id
			break

	const TournamentEventScript = preload("res://data/tournament_event.gd")
	var single_event: Resource = null
	for ev in full_project.events:
		if ev is TournamentEventScript and ev.event_type == "match" and ev.match_config:
			if target_match_id == "" or ev.match_config.opponent_id == target_match_id:
				single_event = ev
				break

	if single_event == null:
		push_warning("Editor2: La partida no está conectada — no hay evento para previsualizar.")
		return

	single_event.order_index = 0
	full_project.events.clear()
	full_project.events.append(single_event)

	GameState.preview_project_override = full_project
	open_game_preview_window()


func open_game_preview_window() -> void:
	if _game_preview_window and is_instance_valid(_game_preview_window):
		_game_preview_window.grab_focus()
		return

	_game_preview_window = Window.new()
	_game_preview_window.title = "Preview — Juego completo"
	_game_preview_window.size = Vector2i(960, 600)
	_game_preview_window.unresizable = false
	_game_preview_window.wrap_controls = true
	_game_preview_window.close_requested.connect(func():
		if _game_preview_window and is_instance_valid(_game_preview_window):
			_game_preview_window.queue_free()
		_game_preview_window = null)

	var viewport_container := SubViewportContainer.new()
	viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	_game_preview_window.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	viewport_container.resized.connect(func():
		var s := viewport_container.size
		if s.x >= 32 and s.y >= 32:
			viewport.size = Vector2i(int(s.x), int(s.y)))

	var game_scene := load("res://main.tscn")
	var game_instance: Control = game_scene.instantiate()
	game_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(game_instance)

	_main.get_viewport().set_embedding_subwindows(false)
	_main.get_tree().root.add_child(_game_preview_window)
	_game_preview_window.popup_centered()
