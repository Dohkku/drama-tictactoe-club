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

const SceneParserScript = preload("res://systems/scene_runner/scene_parser.gd")
const SceneRunnerScript = preload("res://systems/scene_runner/scene_runner.gd")

var graph_edit: GraphEdit = null
var cutscene_node = null  # The CutsceneNode being edited
var characters: Array = []  # Array[CharacterData] from root canvas
var scene_name: String = ""
var scene_background: String = ""
var _popup_menu: PopupMenu = null
var _preview_window: Window = null
var _preview_stage = null
var _preview_dialogue = null
var _preview_runner: RefCounted = null
var _preview_playing: bool = false
var _preview_step_index: int = 0
var _preview_commands: Array = []
var _parent_ref: Control = null


func open(p_cutscene_node, p_characters: Array, parent: Control) -> void:
	cutscene_node = p_cutscene_node
	characters = p_characters
	_parent_ref = parent

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

	_renumber_steps()


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
	_renumber_steps()


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_renumber_steps()


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
		_renumber_steps()


## Walk flow from start and assign step numbers to each command node.
func _renumber_steps() -> void:
	# Reset all
	for child in graph_edit.get_children():
		if child is CmdNodeScript:
			child.set_step(-1)

	# Walk flow
	var start_node: GraphNode = null
	for child in graph_edit.get_children():
		if child is StartNodeScript:
			start_node = child
			break
	if start_node == null:
		return

	var current_name: StringName = start_node.name
	var visited: Dictionary = {}
	var step := 1

	while current_name != StringName(""):
		if visited.has(current_name):
			break
		visited[current_name] = true

		var next_name: StringName = StringName("")
		for conn in graph_edit.get_connection_list():
			if conn.from_node == current_name:
				next_name = conn.to_node
				break

		if next_name == StringName(""):
			break

		var node := graph_edit.get_node_or_null(String(next_name))
		if node is CmdNodeScript:
			node.set_step(step)
			step += 1

		current_name = next_name


# ── Preview Window ──

func open_preview() -> void:
	if _preview_window != null and is_instance_valid(_preview_window):
		_preview_window.grab_focus()
		return

	# Create Window — independent (not transient) so it works on other monitors
	_preview_window = Window.new()
	_preview_window.title = "Preview — %s" % (cutscene_node.script_path.get_file() if cutscene_node.script_path != "" else "nueva escena")
	_preview_window.size = Vector2i(800, 500)
	_preview_window.unresizable = false
	_preview_window.transient = false
	_preview_window.exclusive = false
	_preview_window.always_on_top = false
	_preview_window.close_requested.connect(_close_preview)

	# Main layout inside window
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Controls bar
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	var ctrl_bg := PanelContainer.new()
	var ctrl_style := StyleBoxFlat.new()
	ctrl_style.bg_color = Color(0.12, 0.13, 0.17)
	ctrl_style.content_margin_left = 10
	ctrl_style.content_margin_right = 10
	ctrl_style.content_margin_top = 6
	ctrl_style.content_margin_bottom = 6
	ctrl_bg.add_theme_stylebox_override("panel", ctrl_style)

	var play_btn := Button.new()
	play_btn.text = "Reproducir"
	play_btn.add_theme_font_size_override("font_size", 14)
	play_btn.pressed.connect(_preview_play_all)
	controls.add_child(play_btn)

	var step_btn := Button.new()
	step_btn.text = "Paso >"
	step_btn.add_theme_font_size_override("font_size", 14)
	step_btn.pressed.connect(_preview_step)
	controls.add_child(step_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reiniciar"
	reset_btn.add_theme_font_size_override("font_size", 14)
	reset_btn.pressed.connect(_preview_reset)
	controls.add_child(reset_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)

	var step_label := Label.new()
	step_label.text = "Paso: 0 / 0"
	step_label.add_theme_font_size_override("font_size", 13)
	step_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	controls.add_child(step_label)

	ctrl_bg.add_child(controls)
	vbox.add_child(ctrl_bg)

	# Stage viewport
	var viewport_container := SubViewportContainer.new()
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true

	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 440)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	# CinematicStage
	var stage_scene = load("res://systems/cinematic/cinematic_stage.tscn")
	_preview_stage = stage_scene.instantiate()
	_preview_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(_preview_stage)

	# DialogueBox
	var dialogue_scene = load("res://systems/cinematic/dialogue_box.tscn")
	_preview_dialogue = dialogue_scene.instantiate()
	_preview_dialogue.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_preview_dialogue.offset_top = -120
	viewport.add_child(_preview_dialogue)

	vbox.add_child(viewport_container)
	_preview_window.add_child(vbox)

	# Register characters on preview stage
	for ch in characters:
		_preview_stage.register_character(ch)

	# Setup runner
	_preview_runner = SceneRunnerScript.new()
	_preview_runner.setup(_preview_stage, null, _preview_dialogue)

	# Serialize current graph to commands
	var dscn_text: String = SerializerScript.graph_to_dscn(graph_edit, scene_name, scene_background)
	var parsed: Dictionary = SceneParserScript.parse(dscn_text)
	_preview_commands = parsed.get("commands", [])
	_preview_step_index = 0

	step_label.text = "Paso: 0 / %d" % _preview_commands.size()

	# Store ref for updating
	_preview_window.set_meta("step_label", step_label)

	# Add window to scene tree
	_parent_ref.get_tree().root.add_child(_preview_window)
	_preview_window.popup_centered()


func _close_preview() -> void:
	if _preview_window and is_instance_valid(_preview_window):
		_preview_window.queue_free()
		_preview_window = null
	_preview_stage = null
	_preview_dialogue = null
	_preview_runner = null
	_preview_playing = false


func _preview_reset() -> void:
	_preview_step_index = 0
	_preview_playing = false
	if _preview_stage:
		_preview_stage.clear_stage()
		# Re-register characters
		for ch in characters:
			_preview_stage.register_character(ch)
	if _preview_dialogue:
		_preview_dialogue.hide_dialogue()
	_update_step_label()


func _preview_step() -> void:
	if _preview_runner == null or _preview_commands.is_empty():
		return
	if _preview_step_index >= _preview_commands.size():
		return

	var cmd: Dictionary = _preview_commands[_preview_step_index]
	_preview_step_index += 1
	_update_step_label()

	# Execute single command
	var data := {"commands": [cmd], "background": ""}
	await _preview_runner.execute(data)


func _preview_play_all() -> void:
	if _preview_playing:
		_preview_playing = false
		return

	_preview_playing = true
	while _preview_playing and _preview_step_index < _preview_commands.size():
		await _preview_step()
		if _preview_playing:
			await _parent_ref.get_tree().create_timer(0.1).timeout
	_preview_playing = false


func _update_step_label() -> void:
	if _preview_window and is_instance_valid(_preview_window) and _preview_window.has_meta("step_label"):
		var label: Label = _preview_window.get_meta("step_label")
		if label and is_instance_valid(label):
			label.text = "Paso: %d / %d" % [_preview_step_index, _preview_commands.size()]
