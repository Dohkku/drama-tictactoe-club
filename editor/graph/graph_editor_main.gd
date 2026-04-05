extends Control

## Editor 2.0 main controller.
## HSplitContainer with GraphEdit (left) and DetailPanel (right).
## Manages node creation, connections, save/load, and play.

const GraphThemeC = preload("res://editor/graph/graph_theme.gd")
const ConnectionRulesC = preload("res://editor/graph/connection_rules.gd")
const CanvasDataScript = preload("res://editor/graph/canvas_data.gd")
const CanvasNodeDataScript = preload("res://editor/graph/canvas_node_data.gd")
const CanvasConnectionDataScript = preload("res://editor/graph/canvas_connection_data.gd")

const StartNodeScript = preload("res://editor/graph/nodes/start_node.gd")
const EndNodeScript = preload("res://editor/graph/nodes/end_node.gd")
const CharacterNodeScript = preload("res://editor/graph/nodes/character_node.gd")
const CutsceneNodeScript = preload("res://editor/graph/nodes/cutscene_node.gd")
const MatchNodeScript = preload("res://editor/graph/nodes/match_node.gd")
const BoardConfigNodeScript = preload("res://editor/graph/nodes/board_config_node.gd")
const SimultaneousNodeScript = preload("res://editor/graph/nodes/simultaneous_node.gd")
const CommentNodeScript = preload("res://editor/graph/nodes/comment_node.gd")

const ProjectDataScript = preload("res://data/project_data.gd")
const BoardConfigResScript = preload("res://data/board_config.gd")
const CharacterDataScript = preload("res://characters/character_data.gd")

const SAVE_PATH := "user://current_project.tres"

var graph_edit: GraphEdit = null
var detail_panel: PanelContainer = null
var detail_content: VBoxContainer = null
var _selected_node: GraphNode = null
var _popup_menu: PopupMenu = null
var _add_menu: PopupMenu = null
var _context_position: Vector2 = Vector2.ZERO
var _file_dialog: FileDialog = null


func _ready() -> void:
	_build_ui()
	_setup_graph_edit()
	_load_or_create_default()


# ── UI Construction ──

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = GraphThemeC.COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main layout
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	# Toolbar
	var toolbar := _build_toolbar()
	vbox.add_child(toolbar)

	# Split: GraphEdit + Detail Panel
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = -350
	vbox.add_child(split)

	graph_edit = GraphEdit.new()
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.snapping_enabled = true
	graph_edit.snapping_distance = GraphThemeC.SNAP_DISTANCE
	graph_edit.minimap_enabled = true
	graph_edit.right_disconnects = true
	graph_edit.show_grid = true
	split.add_child(graph_edit)

	detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size.x = 320
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = GraphThemeC.COLOR_PANEL_BG
	panel_style.border_color = Color(0.25, 0.25, 0.3)
	panel_style.border_width_left = 1
	detail_panel.add_theme_stylebox_override("panel", panel_style)
	split.add_child(detail_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(scroll)

	detail_content = VBoxContainer.new()
	detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.add_theme_constant_override("separation", 8)
	scroll.add_child(detail_content)

	_show_welcome_panel()

	# File dialog for scripts
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	add_child(_file_dialog)

	# Context menu
	_build_context_menu()


func _build_toolbar() -> PanelContainer:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	var toolbar_style := StyleBoxFlat.new()
	toolbar_style.bg_color = Color(0.12, 0.13, 0.17)
	toolbar_style.content_margin_left = 12
	toolbar_style.content_margin_right = 12
	toolbar_style.content_margin_top = 6
	toolbar_style.content_margin_bottom = 6
	var panel_wrap := PanelContainer.new()
	panel_wrap.add_theme_stylebox_override("panel", toolbar_style)
	panel_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Back button
	var back_btn := _make_toolbar_button("< Volver", Color(0.5, 0.5, 0.6))
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://systems/dev_menu.tscn"))
	hbox.add_child(back_btn)

	hbox.add_child(VSeparator.new())

	# Title
	var title_lbl := Label.new()
	title_lbl.text = "Editor 2.0 — Canvas"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	hbox.add_child(title_lbl)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Add node button
	var add_btn := _make_toolbar_button("+ Agregar Nodo", Color(0.3, 0.6, 0.9))
	add_btn.pressed.connect(func(): _show_add_menu(add_btn.global_position + Vector2(0, add_btn.size.y)))
	hbox.add_child(add_btn)

	hbox.add_child(VSeparator.new())

	# Save
	var save_btn := _make_toolbar_button("Guardar", Color(0.3, 0.7, 0.4))
	save_btn.pressed.connect(_on_save_pressed)
	hbox.add_child(save_btn)

	# Play
	var play_btn := _make_toolbar_button("JUGAR!", Color(0.2, 0.6, 0.3))
	play_btn.pressed.connect(_on_play_pressed)
	hbox.add_child(play_btn)

	panel_wrap.add_child(hbox)
	return panel_wrap


func _make_toolbar_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.4)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("hover", hover)
	return btn


func _build_context_menu() -> void:
	_popup_menu = PopupMenu.new()
	_popup_menu.add_item("Cinematica", 0)
	_popup_menu.add_item("Partida", 1)
	_popup_menu.add_item("Personaje", 2)
	_popup_menu.add_item("Tablero", 3)
	_popup_menu.add_item("Simultanea", 4)
	_popup_menu.add_separator()
	_popup_menu.add_item("Nota", 5)
	_popup_menu.add_separator()
	_popup_menu.add_item("Fin", 6)
	_popup_menu.id_pressed.connect(_on_context_menu_selected)
	add_child(_popup_menu)

	_add_menu = PopupMenu.new()
	_add_menu.add_item("Cinematica", 0)
	_add_menu.add_item("Partida", 1)
	_add_menu.add_item("Personaje", 2)
	_add_menu.add_item("Tablero", 3)
	_add_menu.add_item("Simultanea", 4)
	_add_menu.add_separator()
	_add_menu.add_item("Nota", 5)
	_add_menu.add_separator()
	_add_menu.add_item("Fin", 6)
	_add_menu.id_pressed.connect(_on_context_menu_selected)
	add_child(_add_menu)


func _show_add_menu(pos: Vector2) -> void:
	_context_position = (graph_edit.scroll_offset + graph_edit.size / 2) / graph_edit.zoom
	_add_menu.position = Vector2i(pos)
	_add_menu.popup()


# ── GraphEdit Setup ──

func _setup_graph_edit() -> void:
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.node_selected.connect(_on_node_selected)
	graph_edit.node_deselected.connect(_on_node_deselected)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	graph_edit.popup_request.connect(_on_popup_request)

	# Set valid connection types
	graph_edit.add_valid_connection_type(GraphThemeC.PORT_FLOW, GraphThemeC.PORT_FLOW)
	graph_edit.add_valid_connection_type(GraphThemeC.PORT_CHARACTER, GraphThemeC.PORT_CHARACTER)
	graph_edit.add_valid_connection_type(GraphThemeC.PORT_BOARD_CONFIG, GraphThemeC.PORT_BOARD_CONFIG)
	graph_edit.add_valid_connection_type(GraphThemeC.PORT_SCRIPT, GraphThemeC.PORT_SCRIPT)


# ── Node Creation ──

func _create_node(type: String, pos: Vector2 = Vector2.ZERO) -> GraphNode:
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
	graph_edit.add_child(node)
	return node


func _on_context_menu_selected(id: int) -> void:
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
		_create_node(type, _context_position)


# ── Connections ──

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from := graph_edit.get_node(String(from_node)) as GraphNode
	var to := graph_edit.get_node(String(to_node)) as GraphNode
	if from == null or to == null:
		return

	# Get port types
	var from_type := from.get_slot_type_right(from_port)
	var to_type := to.get_slot_type_left(to_port)

	# Validate same type
	if from_type != to_type:
		return

	# Flow connections: 1:1, no cycles
	if from_type == GraphThemeC.PORT_FLOW:
		if not ConnectionRulesC.flow_output_is_free(graph_edit, from_node, from_port):
			for conn in graph_edit.get_connection_list():
				if conn.from_node == from_node and conn.from_port == from_port:
					graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
					_notify_disconnection(conn.to_node, conn.to_port)
					break
		if not ConnectionRulesC.flow_input_is_free(graph_edit, to_node, to_port):
			for conn in graph_edit.get_connection_list():
				if conn.to_node == to_node and conn.to_port == to_port:
					graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
					_notify_disconnection(conn.to_node, conn.to_port)
					break
		if ConnectionRulesC.would_create_cycle(graph_edit, from_node, to_node):
			return

	# Character & BoardConfig inputs: 1:1 on the INPUT side
	# (a character can fan out to many matches, but each match has one opponent)
	elif from_type == GraphThemeC.PORT_CHARACTER or from_type == GraphThemeC.PORT_BOARD_CONFIG:
		for conn in graph_edit.get_connection_list():
			if conn.to_node == to_node and conn.to_port == to_port:
				graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
				_notify_disconnection(conn.to_node, conn.to_port)
				break

	graph_edit.connect_node(from_node, from_port, to_node, to_port)

	# Notify target node of connection
	if to is BaseGraphNode:
		to.on_connection_changed(to_port, true, from as BaseGraphNode)


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_notify_disconnection(to_node, to_port)


func _notify_disconnection(to_node_name: StringName, to_port: int) -> void:
	var to := graph_edit.get_node(String(to_node_name))
	if to is BaseGraphNode:
		to.on_connection_changed(to_port, false, null)


# ── Selection ──

func _on_node_selected(node: Node) -> void:
	_selected_node = node as GraphNode
	_show_detail_for_node(_selected_node)


func _on_node_deselected(node: Node) -> void:
	if _selected_node == node:
		_selected_node = null
		_show_welcome_panel()


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	for node_name in nodes:
		var node := graph_edit.get_node(String(node_name))
		if node == null:
			continue
		# Don't delete the StartNode
		if node is StartNodeScript:
			continue
		# Remove all connections involving this node
		for conn in graph_edit.get_connection_list():
			if conn.from_node == node_name or conn.to_node == node_name:
				graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
		node.queue_free()

	if _selected_node and is_instance_valid(_selected_node) == false:
		_selected_node = null
		_show_welcome_panel()


func _on_popup_request(at_position: Vector2) -> void:
	_context_position = (graph_edit.scroll_offset + at_position) / graph_edit.zoom
	_popup_menu.position = Vector2i(get_viewport().get_mouse_position())
	_popup_menu.popup()


# ── Detail Panel ──

func _show_welcome_panel() -> void:
	_clear_detail()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "Editor 2.0"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Selecciona un nodo para editarlo.\nClick derecho para agregar nodos.\nConecta los puertos para definir el flujo."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	vbox.add_child(desc)

	var shortcuts := Label.new()
	shortcuts.text = "Atajos:\n  Delete — Borrar nodo\n  Click derecho — Menu contextual\n  Scroll — Zoom\n  Arrastrar — Mover canvas"
	shortcuts.add_theme_font_size_override("font_size", 12)
	shortcuts.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	vbox.add_child(shortcuts)

	margin.add_child(vbox)
	detail_content.add_child(margin)


func _show_detail_for_node(node: GraphNode) -> void:
	_clear_detail()
	if node == null:
		_show_welcome_panel()
		return

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# Header
	var header := Label.new()
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)

	if node is StartNodeScript:
		header.text = "Nodo Inicio"
		vbox.add_child(header)
		var desc := Label.new()
		desc.text = "Punto de entrada del juego.\nConecta la salida al primer evento."
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
		vbox.add_child(desc)

	elif node is EndNodeScript:
		header.text = "Nodo Fin"
		vbox.add_child(header)
		var desc := Label.new()
		desc.text = "Punto de finalizacion del juego."
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
		vbox.add_child(desc)

	elif node is CharacterNodeScript:
		header.text = "Personaje"
		vbox.add_child(header)
		_build_character_detail(vbox, node)

	elif node is MatchNodeScript:
		header.text = "Partida"
		vbox.add_child(header)
		_build_match_detail(vbox, node)

	elif node is CutsceneNodeScript:
		header.text = "Cinematica"
		vbox.add_child(header)
		_build_cutscene_detail(vbox, node)

	elif node is BoardConfigNodeScript:
		header.text = "Tablero"
		vbox.add_child(header)
		_build_board_config_detail(vbox, node)

	elif node is SimultaneousNodeScript:
		header.text = "Simultanea"
		vbox.add_child(header)
		_build_simultaneous_detail(vbox, node)

	elif node is CommentNodeScript:
		header.text = "Nota"
		vbox.add_child(header)

	else:
		header.text = "Nodo"
		vbox.add_child(header)

	margin.add_child(vbox)
	detail_content.add_child(margin)


func _clear_detail() -> void:
	for child in detail_content.get_children():
		child.queue_free()


# ── Detail Builders ──

func _build_character_detail(parent: VBoxContainer, node) -> void:
	if node.character_data == null:
		node.character_data = CharacterDataScript.new()
	var data: Resource = node.character_data

	_add_field(parent, "ID", data.character_id, func(val: String):
		data.character_id = val
		node._refresh_display())

	_add_field(parent, "Nombre", data.display_name, func(val: String):
		data.display_name = val
		node._refresh_display())

	_add_color_field(parent, "Color", data.color, func(val: Color):
		data.color = val
		node._refresh_display())

	_add_field(parent, "Pieza", data.piece_type, func(val: String):
		data.piece_type = val)

	_add_option_field(parent, "Estilo default", data.default_style,
		["gentle", "slam", "spinning", "dramatic", "nervous"],
		func(val: String): data.default_style = val)

	_add_field(parent, "Pose default", data.default_pose, func(val: String):
		data.default_pose = val)

	_add_option_field(parent, "Direccion", data.default_look,
		["left", "center", "right", "away"],
		func(val: String): data.default_look = val)

	parent.add_child(HSeparator.new())
	var voice_header := Label.new()
	voice_header.text = "Voz"
	voice_header.add_theme_font_size_override("font_size", 15)
	voice_header.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	parent.add_child(voice_header)

	_add_slider_field(parent, "Pitch", data.voice_pitch, 50.0, 500.0, func(val: float):
		data.voice_pitch = val)

	_add_slider_field(parent, "Variacion", data.voice_variation, 0.0, 100.0, func(val: float):
		data.voice_variation = val)

	_add_option_field(parent, "Forma de onda", data.voice_waveform,
		["sine", "square", "triangle"],
		func(val: String): data.voice_waveform = val)

	parent.add_child(HSeparator.new())
	var style_header := Label.new()
	style_header.text = "Estilo Dialogo"
	style_header.add_theme_font_size_override("font_size", 15)
	style_header.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	parent.add_child(style_header)

	_add_color_field(parent, "Fondo", data.dialogue_bg_color, func(val: Color):
		data.dialogue_bg_color = val)

	_add_color_field(parent, "Borde", data.dialogue_border_color, func(val: Color):
		data.dialogue_border_color = val)


func _build_match_detail(parent: VBoxContainer, node) -> void:
	var data: Dictionary = node.match_data

	_add_slider_field(parent, "Dificultad IA", data.get("ai_difficulty", 0.5), 0.0, 1.0, func(val: float):
		data["ai_difficulty"] = val
		node._refresh_display())

	_add_option_field(parent, "Estilo jugador", data.get("player_style", "slam"),
		["gentle", "slam", "spinning", "dramatic", "nervous"],
		func(val: String): data["player_style"] = val; node._refresh_display())

	_add_option_field(parent, "Estilo oponente", data.get("opponent_style", "gentle"),
		["gentle", "slam", "spinning", "dramatic", "nervous"],
		func(val: String): data["opponent_style"] = val; node._refresh_display())

	_add_option_field(parent, "Efecto jugador", data.get("player_effect_name", "none"),
		["none", "fire", "sparkle", "smoke", "shockwave"],
		func(val: String): data["player_effect_name"] = val)

	_add_option_field(parent, "Efecto oponente", data.get("opponent_effect_name", "auto"),
		["none", "auto", "fire", "sparkle", "smoke", "shockwave"],
		func(val: String): data["opponent_effect_name"] = val)

	_add_slider_field(parent, "Imprecision", data.get("placement_offset", 0.0), 0.0, 0.3, func(val: float):
		data["placement_offset"] = val)

	_add_option_field(parent, "Pieza jugador", data.get("player_piece_design", "x"),
		["x", "o", "triangle", "square", "star", "diamond"],
		func(val: String): data["player_piece_design"] = val)

	_add_option_field(parent, "Pieza oponente", data.get("opponent_piece_design", "o"),
		["x", "o", "triangle", "square", "star", "diamond"],
		func(val: String): data["opponent_piece_design"] = val)

	var _tpv_cb := func(val: float): data["turns_per_visit"] = int(val)
	_add_slider_field(parent, "Turnos por visita", float(data.get("turns_per_visit", 1)), 1.0, 5.0, _tpv_cb, 1.0)

	parent.add_child(HSeparator.new())
	var scripts_header := Label.new()
	scripts_header.text = "Scripts"
	scripts_header.add_theme_font_size_override("font_size", 15)
	scripts_header.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	parent.add_child(scripts_header)

	_add_file_field(parent, "Intro", data.get("intro_script", ""), func(val: String):
		data["intro_script"] = val)

	_add_file_field(parent, "Reacciones", data.get("reactions_script", ""), func(val: String):
		data["reactions_script"] = val)


func _build_cutscene_detail(parent: VBoxContainer, node) -> void:
	_add_file_field(parent, "Script", node.script_path, func(val: String):
		node.set_script_path(val))

	# Inline preview of the script content
	if node.script_path != "" and FileAccess.file_exists(node.script_path):
		parent.add_child(HSeparator.new())
		var preview_label := Label.new()
		preview_label.text = "Vista previa:"
		preview_label.add_theme_font_size_override("font_size", 13)
		preview_label.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
		parent.add_child(preview_label)

		var code := CodeEdit.new()
		code.custom_minimum_size = Vector2(0, 200)
		code.editable = false
		code.text = FileAccess.get_file_as_string(node.script_path)
		code.add_theme_font_size_override("font_size", 11)
		parent.add_child(code)


func _build_board_config_detail(parent: VBoxContainer, node) -> void:
	var config: Resource = node.board_config
	if config == null:
		return
	var rules = config.get_rules()

	# Default toggle
	var default_check := CheckBox.new()
	default_check.text = "Default del proyecto"
	default_check.button_pressed = node.is_project_default
	default_check.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	default_check.add_theme_font_size_override("font_size", 13)
	default_check.toggled.connect(func(pressed: bool):
		node.is_project_default = pressed
		node._refresh_display())
	parent.add_child(default_check)

	parent.add_child(HSeparator.new())

	var _bs_cb := func(val: float):
		rules.board_size = int(val)
		node._refresh_display()
	_add_slider_field(parent, "Tamano tablero", float(rules.board_size), 3.0, 7.0, _bs_cb, 1.0)

	var _wl_cb := func(val: float):
		rules.win_length = int(val)
		node._refresh_display()
	_add_slider_field(parent, "Para ganar", float(rules.win_length), 3.0, 7.0, _wl_cb, 1.0)

	var _mp_cb := func(val: float):
		rules.max_pieces_per_player = int(val)
		node._refresh_display()
	_add_slider_field(parent, "Max piezas", float(rules.max_pieces_per_player), -1.0, 20.0, _mp_cb, 1.0)

	_add_option_field(parent, "Overflow", rules.overflow_mode,
		["rotate", "block"],
		func(val: String): rules.overflow_mode = val)

	var draw_check := CheckBox.new()
	draw_check.text = "Permitir empate"
	draw_check.button_pressed = rules.allow_draw
	draw_check.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	draw_check.add_theme_font_size_override("font_size", 13)
	draw_check.toggled.connect(func(pressed: bool): rules.allow_draw = pressed)
	parent.add_child(draw_check)


func _build_simultaneous_detail(parent: VBoxContainer, node) -> void:
	var info := Label.new()
	info.text = "Conecta personajes a los puertos de oponente.\nCada oponente tendra su propia config."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	parent.add_child(info)

	# Per-opponent config (if any)
	for i in range(node.opponent_configs.size()):
		parent.add_child(HSeparator.new())
		var opp_header := Label.new()
		opp_header.text = "Oponente %d" % (i + 1)
		opp_header.add_theme_font_size_override("font_size", 14)
		opp_header.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
		parent.add_child(opp_header)

		var opp_data: Dictionary = node.opponent_configs[i]
		_add_slider_field(parent, "Dificultad IA", opp_data.get("ai_difficulty", 0.5), 0.0, 1.0, func(val: float):
			opp_data["ai_difficulty"] = val)


# ── Detail Field Helpers ──

func _add_field(parent: VBoxContainer, label_text: String, value: String, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(lbl)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 13)
	edit.text_changed.connect(on_change)
	hbox.add_child(edit)
	parent.add_child(hbox)


func _add_color_field(parent: VBoxContainer, label_text: String, value: Color, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(lbl)
	var picker := ColorPickerButton.new()
	picker.color = value
	picker.custom_minimum_size = Vector2(40, 28)
	picker.color_changed.connect(on_change)
	hbox.add_child(picker)
	parent.add_child(hbox)


func _add_slider_field(parent: VBoxContainer, label_text: String, value: float, min_val: float, max_val: float, on_change: Callable, step: float = 0.01) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 80
	slider.value_changed.connect(on_change)
	hbox.add_child(slider)
	var val_label := Label.new()
	val_label.text = "%.2f" % value if step < 1.0 else str(int(value))
	val_label.custom_minimum_size.x = 36
	val_label.add_theme_font_size_override("font_size", 12)
	val_label.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	slider.value_changed.connect(func(v: float):
		val_label.text = "%.2f" % v if step < 1.0 else str(int(v)))
	hbox.add_child(val_label)
	parent.add_child(hbox)


func _add_option_field(parent: VBoxContainer, label_text: String, value: String, options: Array, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(lbl)
	var option := OptionButton.new()
	option.add_theme_font_size_override("font_size", 13)
	for opt in options:
		option.add_item(opt)
	var idx := options.find(value)
	if idx >= 0:
		option.selected = idx
	option.item_selected.connect(func(i: int): on_change.call(options[i]))
	hbox.add_child(option)
	parent.add_child(hbox)


func _add_file_field(parent: VBoxContainer, label_text: String, value: String, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(lbl)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 12)
	edit.text_changed.connect(on_change)
	hbox.add_child(edit)
	var browse := Button.new()
	browse.text = "..."
	browse.add_theme_font_size_override("font_size", 12)
	browse.pressed.connect(func():
		_file_dialog.filters = PackedStringArray(["*.dscn ; Scene Scripts"])
		_file_dialog.current_dir = "res://scene_scripts/scripts/"
		_file_dialog.file_selected.connect(func(path: String):
			edit.text = path
			on_change.call(path), CONNECT_ONE_SHOT)
		_file_dialog.popup_centered(Vector2i(600, 400)))
	hbox.add_child(browse)
	parent.add_child(hbox)


# ── Save / Load / Play ──

func _on_save_pressed() -> void:
	var project := _graph_to_project_data()
	var err := ResourceSaver.save(project, SAVE_PATH)
	if err == OK:
		print("[GraphEditor] Proyecto guardado en: ", SAVE_PATH)
	else:
		push_error("[GraphEditor] Error al guardar: %s" % error_string(err))


func _on_play_pressed() -> void:
	_on_save_pressed()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://main.tscn")


func _load_or_create_default() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		var project := ResourceLoader.load(SAVE_PATH)
		if project is ProjectDataScript:
			_import_project_data(project)
			return

	# Default: create StartNode + EndNode
	var start := _create_node("start", Vector2(100, 300))
	_create_node("end", Vector2(800, 300))


## Convert the graph to a ProjectData resource for runtime consumption.
func _graph_to_project_data() -> Resource:
	var project = ProjectDataScript.new()
	project.project_name = "Mi Proyecto"

	# Collect characters
	for child in graph_edit.get_children():
		if child is CharacterNodeScript and child.character_data:
			project.characters.append(child.character_data)

	# Find project default board config
	for child in graph_edit.get_children():
		if child is BoardConfigNodeScript and child.is_project_default:
			project.board_config = child.board_config
			break

	if project.board_config == null:
		project.board_config = BoardConfigResScript.create_default()

	# Walk flow from StartNode to build ordered events
	var start_node: GraphNode = null
	for child in graph_edit.get_children():
		if child is StartNodeScript:
			start_node = child
			break

	if start_node:
		var events := _walk_flow(start_node)
		project.events = events

	# Store canvas data
	project.set_meta("canvas_data", _serialize_canvas())

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

		# Find flow output connection from current node
		var next_name: StringName = StringName("")
		for conn in graph_edit.get_connection_list():
			if conn.from_node == current_name:
				var from_node := graph_edit.get_node(String(conn.from_node)) as GraphNode
				if from_node and from_node.is_slot_enabled_right(conn.from_port) and from_node.get_slot_type_right(conn.from_port) == GraphThemeC.PORT_FLOW:
					next_name = conn.to_node
					break

		if next_name == StringName(""):
			break

		var target := graph_edit.get_node(String(next_name))
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

		# Get opponent from connection
		var opponent_id := ""
		for conn in graph_edit.get_connection_list():
			if conn.to_node == node.name and conn.to_port == 1:
				var char_node := graph_edit.get_node(String(conn.from_node))
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
		mc.intro_script = node.match_data.get("intro_script", "")
		mc.reactions_script = node.match_data.get("reactions_script", "")
		mc.game_rules_preset = node.match_data.get("game_rules_preset", "standard")

		# Board config override from connection
		for conn in graph_edit.get_connection_list():
			if conn.to_node == node.name and conn.to_port == 2:
				var board_node := graph_edit.get_node(String(conn.from_node))
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

		# Get connected opponents
		for conn in graph_edit.get_connection_list():
			if conn.to_node == node.name and conn.to_port >= 3:
				var char_node := graph_edit.get_node(String(conn.from_node))
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


## Serialize the current graph to CanvasData.
func _serialize_canvas() -> Resource:
	var canvas = CanvasDataScript.new()
	canvas.canvas_name = "main"
	canvas.scroll_offset = graph_edit.scroll_offset
	canvas.zoom = graph_edit.zoom

	for child in graph_edit.get_children():
		if child is GraphNode:
			var nd = CanvasNodeDataScript.new()
			if child is BaseGraphNode:
				nd.node_id = child.node_id
				nd.node_type = child.get_node_type()
				nd.config = child.get_node_data()
				nd.ref_path = child.get_resource_path()
			nd.position = child.position_offset
			canvas.nodes.append(nd)

	for conn in graph_edit.get_connection_list():
		var cd = CanvasConnectionDataScript.new()
		cd.from_node = _name_to_node_id(conn.from_node)
		cd.from_port = conn.from_port
		cd.to_node = _name_to_node_id(conn.to_node)
		cd.to_port = conn.to_port
		canvas.connections.append(cd)

	return canvas


func _name_to_node_id(node_name: StringName) -> String:
	var node := graph_edit.get_node(String(node_name))
	if node is BaseGraphNode:
		return node.node_id
	return String(node_name)


## Import a ProjectData into the graph (legacy migration).
func _import_project_data(project: Resource) -> void:
	# Clear existing graph
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()

	await get_tree().process_frame

	# Create start node
	var start := _create_node("start", Vector2(100, 300))
	var prev_name: StringName = start.name
	var x_offset := 400.0

	# Create character nodes (positioned on the left)
	var char_nodes: Dictionary = {}
	var char_y := 50.0
	for ch in project.characters:
		var cn = _create_node("character", Vector2(50, char_y))
		cn.set_character(ch)
		char_nodes[ch.character_id] = cn
		char_y += 140.0

	# Create board config node
	if project.board_config:
		var bcn = _create_node("board_config", Vector2(50, char_y + 40))
		bcn.set_board_config(project.board_config)
		bcn.is_project_default = true
		bcn._refresh_display()

	# Create event nodes in order
	var sorted_events: Array = project.events.duplicate()
	sorted_events.sort_custom(func(a, b): return a.order_index < b.order_index)

	for event in sorted_events:
		var node: GraphNode = null

		match event.event_type:
			"cutscene":
				node = _create_node("cutscene", Vector2(x_offset, 300))
				node.set_script_path(event.cutscene_script_path)

			"match":
				node = _create_node("match", Vector2(x_offset, 300))
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
						"intro_script": mc.intro_script,
						"reactions_script": mc.reactions_script,
						"game_rules_preset": mc.game_rules_preset,
						"custom_rules": mc.board_config != null,
						"board_rules": {},
					}
					node._refresh_display()

					# Connect character
					if char_nodes.has(mc.opponent_id):
						await get_tree().process_frame
						graph_edit.connect_node(char_nodes[mc.opponent_id].name, 0, node.name, 1)
						node.set_connected_character(char_nodes[mc.opponent_id].character_data)

			"simultaneous":
				node = _create_node("simultaneous", Vector2(x_offset, 300))
				# Connect opponent characters
				for i in range(event.simultaneous_configs.size()):
					var mc = event.simultaneous_configs[i]
					if char_nodes.has(mc.opponent_id):
						# Ensure enough slots
						while node._opponent_labels.size() <= i:
							node._add_opponent_slot()
						await get_tree().process_frame
						graph_edit.connect_node(char_nodes[mc.opponent_id].name, 0, node.name, 3 + i)

		if node:
			# Connect flow
			await get_tree().process_frame
			graph_edit.connect_node(prev_name, 0, node.name, 0)
			prev_name = node.name
			x_offset += GraphThemeC.NODE_SEPARATION_X

	# Create end node
	var end_node := _create_node("end", Vector2(x_offset, 300))
	await get_tree().process_frame
	graph_edit.connect_node(prev_name, 0, end_node.name, 0)
