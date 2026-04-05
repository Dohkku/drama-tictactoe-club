class_name PreviewManager
extends RefCounted

## Manages cinematic sub-editor and preview/play functionality.

const CinematicEditorScript = preload("res://editor/graph/cinematic/cinematic_editor.gd")
const CharacterNodeScript = preload("res://editor/graph/nodes/character_node.gd")
const CutsceneNodeScript = preload("res://editor/graph/nodes/cutscene_node.gd")
const MatchNodeScript = preload("res://editor/graph/nodes/match_node.gd")
const StartNodeScript = preload("res://editor/graph/nodes/start_node.gd")
const GraphThemeC = preload("res://editor/graph/graph_theme.gd")
const ScriptEditorWindowScript = preload("res://editor/graph/panels/script_editor_window.gd")

var _main: Control  # GraphEditorMain
var _cinematic_editor: RefCounted = null
var _preview_temp_cinematic_editor: RefCounted = null
var _game_preview_window: Window = null
var _game_instance: Control = null  # main.tscn instance inside the preview window
var _script_editors: Dictionary = {}  # absolute path → ScriptEditorWindow
var _snapshot_stack: Array = []       # Array[Dictionary]
var _preview_toolbar_label: Label = null
var _preview_playpause_btn: Button = null
var _preview_last_match_node = null   # To allow Reset recreation


func _init(main: Control) -> void:
	_main = main


func open_cinematic_editor(cutscene_node) -> void:
	# Node-based cutscene editing was removed from Editor 2.0.
	# Keep this entry point for compatibility and redirect to script editing.
	if cutscene_node == null:
		return
	if cutscene_node.script_path == "":
		push_warning("Editor2: Asigna un script .dscn para editar la cinematica.")
		return
	open_script_editor(cutscene_node.script_path)


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
			var parsed_cmds: Array = parsed.get("commands", [])
			# Fallback: most .dscn files use [background path] as the first
			# bracket command instead of the @background directive, so scan the
			# command list too.
			if first_bg == "":
				for pcmd in parsed_cmds:
					if pcmd.get("type", "") == "background":
						first_bg = pcmd.get("source", "")
						break
			all_commands.append_array(parsed_cmds)

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


func open_script_editor(path: String) -> void:
	## Open (or focus) a floating script editor window for the given .dscn path.
	## Subsequent calls for the same path return the existing window.
	if path == "":
		push_warning("ScriptEditor: path vacio")
		return
	if _script_editors.has(path):
		var existing: RefCounted = _script_editors[path]
		if existing and existing.is_open():
			existing.focus()
			return
		_script_editors.erase(path)

	var editor := ScriptEditorWindowScript.new(_main, path)
	_script_editors[path] = editor
	editor.script_saved.connect(_on_script_saved)
	editor.window_closed.connect(_on_script_editor_closed)
	editor.open()


func _on_script_saved(path: String) -> void:
	## Route a save event to any active preview that cares about this file.
	## Phase 2 wires cinematic + match preview hot reload here.
	if _cinematic_editor and _cinematic_editor.cutscene_node:
		if _cinematic_editor.cutscene_node.script_path == path and _cinematic_editor.has_method("refresh_from_file"):
			_cinematic_editor.refresh_from_file()
	if _preview_temp_cinematic_editor and _preview_temp_cinematic_editor.cutscene_node:
		if _preview_temp_cinematic_editor.cutscene_node.script_path == path and _preview_temp_cinematic_editor.has_method("refresh_from_file"):
			_preview_temp_cinematic_editor.refresh_from_file()
	if _game_instance and is_instance_valid(_game_instance):
		if _game_instance.has_method("on_script_saved"):
			_game_instance.on_script_saved(path)


func _on_script_editor_closed(path: String) -> void:
	_script_editors.erase(path)


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
	_preview_last_match_node = match_node
	_snapshot_stack.clear()
	open_game_preview_window()


func open_game_preview_window() -> void:
	if _game_preview_window and is_instance_valid(_game_preview_window):
		_game_preview_window.grab_focus()
		return

	_game_preview_window = Window.new()
	_game_preview_window.title = "Preview — Juego completo"
	_game_preview_window.size = Vector2i(1000, 680)
	_game_preview_window.unresizable = false
	_game_preview_window.wrap_controls = true
	_game_preview_window.close_requested.connect(func():
		if _game_preview_window and is_instance_valid(_game_preview_window):
			_game_preview_window.queue_free()
		_game_preview_window = null
		_game_instance = null
		_snapshot_stack.clear()
		_preview_toolbar_label = null
		_preview_playpause_btn = null)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 2)

	root.add_child(_build_match_preview_toolbar())

	var viewport_container := SubViewportContainer.new()
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	root.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 640)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	viewport_container.resized.connect(func():
		var s := viewport_container.size
		if s.x >= 32 and s.y >= 32:
			viewport.size = Vector2i(int(s.x), int(s.y)))

	var game_scene := load("res://main.tscn")
	_game_instance = game_scene.instantiate()
	_game_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(_game_instance)

	_game_preview_window.add_child(root)
	_main.get_viewport().set_embedding_subwindows(false)
	_main.get_tree().root.add_child(_game_preview_window)
	_game_preview_window.popup_centered()

	# Wire runner signals after main.tscn finishes _ready (deferred).
	_game_instance.call_deferred("set", "_preview_manager_ref", self)
	_main.get_tree().create_timer(0.6).timeout.connect(_hook_preview_signals)


func _build_match_preview_toolbar() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.17)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	_preview_playpause_btn = _make_toolbar_btn("⏸ Pausa", Color(0.7, 0.4, 0.2))
	_preview_playpause_btn.pressed.connect(_on_preview_playpause)
	hbox.add_child(_preview_playpause_btn)

	var step_btn := _make_toolbar_btn("⏭ Paso", Color(0.3, 0.6, 0.8))
	step_btn.pressed.connect(_on_preview_step)
	hbox.add_child(step_btn)

	var back_btn := _make_toolbar_btn("⏮ Atrás", Color(0.5, 0.3, 0.7))
	back_btn.pressed.connect(_on_preview_step_back)
	hbox.add_child(back_btn)

	var reset_btn := _make_toolbar_btn("⟲ Reset", Color(0.65, 0.25, 0.25))
	reset_btn.pressed.connect(_on_preview_reset)
	hbox.add_child(reset_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_preview_toolbar_label = Label.new()
	_preview_toolbar_label.text = "Listo · Snapshots: 0"
	_preview_toolbar_label.add_theme_font_size_override("font_size", 11)
	_preview_toolbar_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	hbox.add_child(_preview_toolbar_label)

	panel.add_child(hbox)
	return panel


func _make_toolbar_btn(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.4)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("hover", hover)
	return btn


func _hook_preview_signals() -> void:
	if _game_instance == null or not is_instance_valid(_game_instance):
		return
	var runner = _game_instance.runner
	if runner == null:
		return
	if not runner.command_executed.is_connected(_on_runner_command_executed):
		runner.command_executed.connect(_on_runner_command_executed)
	# Hook post-move snapshots on the board controller too.
	if _game_instance.board and _game_instance.board.game_controller:
		# Hook via EventBus.move_made (already emitted after every move).
		if not EventBus.move_made.is_connected(_on_move_made):
			EventBus.move_made.connect(_on_move_made)


func _on_runner_command_executed(label: String) -> void:
	_take_snapshot(label)


func _on_move_made(_idx: int, _piece: String) -> void:
	if _game_instance == null or not is_instance_valid(_game_instance):
		return
	_take_snapshot("move")


func _take_snapshot(label: String) -> void:
	if _game_instance == null or not is_instance_valid(_game_instance):
		return
	var snap: Dictionary = _game_instance.preview_save_state()
	snap["label"] = label
	_snapshot_stack.append(snap)
	if _snapshot_stack.size() > 128:
		_snapshot_stack.pop_front()
	_update_toolbar_label()


func _update_toolbar_label() -> void:
	if _preview_toolbar_label == null:
		return
	var last_label: String = ""
	if not _snapshot_stack.is_empty():
		last_label = _snapshot_stack[-1].get("label", "")
	_preview_toolbar_label.text = "%s · Snapshots: %d" % [last_label, _snapshot_stack.size()]


func _on_preview_playpause() -> void:
	if _game_instance == null or not is_instance_valid(_game_instance):
		return
	if _game_instance.preview_is_paused():
		_game_instance.preview_resume()
		if _preview_playpause_btn:
			_preview_playpause_btn.text = "⏸ Pausa"
	else:
		_game_instance.preview_pause()
		if _preview_playpause_btn:
			_preview_playpause_btn.text = "▶ Play"


func _on_preview_step() -> void:
	if _game_instance == null or not is_instance_valid(_game_instance):
		return
	if not _game_instance.preview_is_paused():
		return
	# Temporary unpause to let one command through. _on_runner_command_executed
	# will re-pause after the snapshot is taken.
	var target := _snapshot_stack.size() + 1
	_game_instance.preview_resume()
	var deadline := Time.get_ticks_msec() + 3000
	while _snapshot_stack.size() < target and Time.get_ticks_msec() < deadline:
		await _main.get_tree().process_frame
	_game_instance.preview_pause()


func _on_preview_step_back() -> void:
	if _game_instance == null or not is_instance_valid(_game_instance):
		return
	if _snapshot_stack.size() < 2:
		return
	_snapshot_stack.pop_back()  # drop current
	var snap: Dictionary = _snapshot_stack[-1]
	_game_instance.preview_pause()
	await _game_instance.preview_load_state(snap)
	if _preview_playpause_btn:
		_preview_playpause_btn.text = "▶ Play"
	_update_toolbar_label()


func _on_preview_reset() -> void:
	if _preview_last_match_node == null:
		return
	# Close current preview, then re-open with the same match node.
	if _game_preview_window and is_instance_valid(_game_preview_window):
		_game_preview_window.queue_free()
	_game_preview_window = null
	_game_instance = null
	_snapshot_stack.clear()
	_preview_toolbar_label = null
	_preview_playpause_btn = null
	preview_single_match(_preview_last_match_node)
