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

const CinematicEditorScript = preload("res://editor/graph/cinematic/cinematic_editor.gd")

const SAVE_PATH := "user://current_project.tres"

var graph_edit: GraphEdit = null
var detail_panel: PanelContainer = null
var detail_content: VBoxContainer = null
var _selected_node: GraphNode = null
var _popup_menu: PopupMenu = null
var _add_menu: PopupMenu = null
var _context_position: Vector2 = Vector2.ZERO
var _file_dialog: FileDialog = null
var _undo_redo: UndoRedo = null
var _stage_height_ratio: float = 0.92
var _stage_aspect: float = 0.60
var _stage_max_width: float = 0.45
var _cinematic_editor: RefCounted = null
var _graph_parent: Control = null  # Parent container for graph_edit (to add sub-editors)
var _breadcrumb_label: Label = null


func _ready() -> void:
	_undo_redo = UndoRedo.new()
	_build_ui()
	_setup_graph_edit()
	_load_or_create_default()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed:
		# Ctrl+Z: Undo
		if event.keycode == KEY_Z and event.ctrl_pressed and not event.shift_pressed:
			if _undo_redo.has_undo():
				_undo_redo.undo()
			get_viewport().set_input_as_handled()
		# Ctrl+Shift+Z: Redo
		elif event.keycode == KEY_Z and event.ctrl_pressed and event.shift_pressed:
			if _undo_redo.has_redo():
				_undo_redo.redo()
			get_viewport().set_input_as_handled()
		# Ctrl+S: Save
		elif event.keycode == KEY_S and event.ctrl_pressed:
			_on_save_pressed()
			get_viewport().set_input_as_handled()


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

	_graph_parent = split  # Save reference for sub-editors

	graph_edit = GraphEdit.new()
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.snapping_enabled = true
	graph_edit.snapping_distance = GraphThemeC.SNAP_DISTANCE
	graph_edit.minimap_enabled = true
	graph_edit.minimap_size = Vector2(180, 120)
	graph_edit.right_disconnects = true
	graph_edit.show_grid = true
	graph_edit.panning_scheme = GraphEdit.SCROLL_PANS
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
	back_btn.pressed.connect(func():
		if _is_in_cinematic_editor():
			_close_cinematic_editor()
		else:
			get_tree().change_scene_to_file("res://systems/dev_menu.tscn"))
	hbox.add_child(back_btn)

	hbox.add_child(VSeparator.new())

	# Breadcrumb / Title
	_breadcrumb_label = Label.new()
	_breadcrumb_label.text = "Editor 2.0 — Canvas"
	_breadcrumb_label.add_theme_font_size_override("font_size", 16)
	_breadcrumb_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	hbox.add_child(_breadcrumb_label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Add node button
	var add_btn := _make_toolbar_button("+ Agregar Nodo", Color(0.3, 0.6, 0.9))
	add_btn.pressed.connect(func(): _show_add_menu(add_btn.global_position + Vector2(0, add_btn.size.y)))
	hbox.add_child(add_btn)

	hbox.add_child(VSeparator.new())

	# Settings
	var settings_btn := _make_toolbar_button("Ajustes", Color(0.5, 0.4, 0.6))
	settings_btn.pressed.connect(_show_stage_settings)
	hbox.add_child(settings_btn)

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

	# Connect CutsceneNode sub-editor signal
	if node is CutsceneNodeScript and node.has_signal("editor_requested"):
		node.editor_requested.connect(_open_cinematic_editor)

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
		_undo_create_node(type, _context_position)


## Create node with undo support.
func _undo_create_node(type: String, pos: Vector2) -> GraphNode:
	var node := _create_node(type, pos)
	if node == null:
		return null
	var node_name: StringName = node.name
	_undo_redo.create_action("Create %s node" % type)
	_undo_redo.add_do_method(_noop)
	_undo_redo.add_undo_method(_remove_node_by_name.bind(node_name))
	_undo_redo.commit_action(false)  # false = don't execute do (already done)
	return node


func _remove_node_by_name(node_name: StringName) -> void:
	var node := graph_edit.get_node_or_null(String(node_name))
	if node == null:
		return
	# Disconnect all connections
	for conn in graph_edit.get_connection_list():
		if conn.from_node == node_name or conn.to_node == node_name:
			graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	node.queue_free()


func _noop() -> void:
	pass


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

	# Register undo action
	_undo_redo.create_action("Connect nodes")
	_undo_redo.add_do_method(_noop)
	_undo_redo.add_undo_method(_do_disconnect.bind(from_node, from_port, to_node, to_port))
	_undo_redo.commit_action(false)


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_notify_disconnection(to_node, to_port)
	# Register undo
	_undo_redo.create_action("Disconnect nodes")
	_undo_redo.add_do_method(_noop)
	_undo_redo.add_undo_method(_do_connect.bind(from_node, from_port, to_node, to_port))
	_undo_redo.commit_action(false)


func _do_disconnect(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_notify_disconnection(to_node, to_port)


func _do_connect(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	var to := graph_edit.get_node_or_null(String(to_node))
	var from := graph_edit.get_node_or_null(String(from_node))
	if to is BaseGraphNode and from is BaseGraphNode:
		to.on_connection_changed(to_port, true, from)


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
		# Collect connections for undo
		var removed_connections: Array = []
		for conn in graph_edit.get_connection_list():
			if conn.from_node == node_name or conn.to_node == node_name:
				removed_connections.append(conn.duplicate())
				graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)

		# Save node data for undo
		var node_type := ""
		var node_data := {}
		var node_pos: Vector2 = node.position_offset
		if node is BaseGraphNode:
			node_type = node.get_node_type()
			node_data = node.get_node_data()

		node.queue_free()

		# Register undo
		if node_type != "":
			_undo_redo.create_action("Delete %s" % node_type)
			_undo_redo.add_do_method(_noop)
			_undo_redo.add_undo_method(_undo_delete_node.bind(node_type, node_pos, node_data, removed_connections))
			_undo_redo.commit_action(false)

	if _selected_node and is_instance_valid(_selected_node) == false:
		_selected_node = null
		_show_welcome_panel()


func _undo_delete_node(type: String, pos: Vector2, data: Dictionary, connections: Array) -> void:
	var node := _create_node(type, pos)
	if node == null:
		return
	if node is BaseGraphNode:
		node.set_node_data(data)
	# Restore connections (best effort — names may differ)
	await get_tree().process_frame
	for conn in connections:
		var fn: StringName = conn.from_node
		var tn: StringName = conn.to_node
		if graph_edit.get_node_or_null(String(fn)) and graph_edit.get_node_or_null(String(tn)):
			graph_edit.connect_node(fn, conn.from_port, tn, conn.to_port)


func _on_popup_request(at_position: Vector2) -> void:
	_context_position = (graph_edit.scroll_offset + at_position) / graph_edit.zoom
	_popup_menu.position = Vector2i(get_viewport().get_mouse_position())
	_popup_menu.popup()


# ── Detail Panel ──

func _show_welcome_panel() -> void:
	_clear_detail()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "Editor 2.0"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Selecciona un nodo para ver sus propiedades aqui."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	# Navigation section
	var nav_title := Label.new()
	nav_title.text = "Navegacion"
	nav_title.add_theme_font_size_override("font_size", 15)
	nav_title.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(nav_title)
	_add_help_line(vbox, "Scroll", "Mover canvas arriba/abajo")
	_add_help_line(vbox, "Shift + Scroll", "Mover canvas izquierda/derecha")
	_add_help_line(vbox, "Ctrl + Scroll", "Zoom in/out")
	_add_help_line(vbox, "Minimap", "Arrastra en la esquina inferior derecha")

	vbox.add_child(HSeparator.new())

	# Editing section
	var edit_title := Label.new()
	edit_title.text = "Edicion"
	edit_title.add_theme_font_size_override("font_size", 15)
	edit_title.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(edit_title)
	_add_help_line(vbox, "Click derecho", "Menu: agregar nodos")
	_add_help_line(vbox, "Arrastrar puerto", "Crear conexion")
	_add_help_line(vbox, "Click en nodo", "Seleccionar y editar")
	_add_help_line(vbox, "Delete / Supr", "Borrar nodo seleccionado")
	_add_help_line(vbox, "Arrastrar puerto der.", "Desconectar (right_disconnects)")

	vbox.add_child(HSeparator.new())

	# Node types section
	var types_title := Label.new()
	types_title.text = "Tipos de nodo"
	types_title.add_theme_font_size_override("font_size", 15)
	types_title.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(types_title)
	_add_help_line(vbox, "INICIO", "Punto de entrada (1 por canvas)")
	_add_help_line(vbox, "CINEMATICA", "Escena de dialogo (.dscn)")
	_add_help_line(vbox, "PARTIDA", "Match vs oponente con IA")
	_add_help_line(vbox, "PERSONAJE", "Definicion de personaje")
	_add_help_line(vbox, "TABLERO", "Config de reglas y visual")
	_add_help_line(vbox, "SIMULTANEA", "Ronda multiple oponentes")
	_add_help_line(vbox, "FIN", "Punto de finalizacion")

	vbox.add_child(HSeparator.new())

	# Connections section
	var conn_title := Label.new()
	conn_title.text = "Conexiones"
	conn_title.add_theme_font_size_override("font_size", 15)
	conn_title.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(conn_title)
	_add_help_line(vbox, "Blanco", "Flujo (orden de ejecucion)")
	_add_help_line(vbox, "Naranja", "Personaje → Partida")
	_add_help_line(vbox, "Cyan", "Tablero → Partida")

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


func _show_stage_settings() -> void:
	_clear_detail()
	_selected_node = null
	# Deselect all nodes in graph
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.selected = false

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.text = "Ajustes de Escena"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	vbox.add_child(header)

	# Stage preview with SubViewport
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(0, 200)
	viewport_container.stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	var stage_scene = load("res://systems/cinematic/cinematic_stage.tscn")
	var preview_stage: Control = stage_scene.instantiate()
	preview_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(preview_stage)

	# Load a character for preview
	var _preview_loaded := false
	var _load_preview := func():
		if _preview_loaded:
			return
		_preview_loaded = true
		for child in graph_edit.get_children():
			if child is CharacterNodeScript and child.character_data:
				preview_stage.register_character(child.character_data)
				preview_stage.enter_character(child.character_data.character_id, "center")
				break

	viewport_container.ready.connect(_load_preview, CONNECT_ONE_SHOT)
	vbox.add_child(viewport_container)

	# Character sizing controls
	_add_section_header(vbox, "Tamano de personajes")

	var desc := Label.new()
	desc.text = "Ajusta como se ven los personajes en el escenario."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	vbox.add_child(desc)

	var _refresh_preview := func():
		# Reposition all characters on stage with new sizing
		for char_id in preview_stage.characters_on_stage:
			var slot = preview_stage.characters_on_stage[char_id]
			var pos_name = preview_stage._character_positions.get(char_id, "center")
			var frac = preview_stage.POSITIONS.get(pos_name, 0.5)
			preview_stage._apply_slot_position(slot, frac)

	_add_slider_field(vbox, "Altura", _stage_height_ratio, 0.5, 1.0, func(val: float):
		preview_stage.char_height_ratio = val
		_stage_height_ratio = val
		_refresh_preview.call())

	_add_slider_field(vbox, "Aspecto", _stage_aspect, 0.3, 0.8, func(val: float):
		preview_stage.char_aspect = val
		_stage_aspect = val
		_refresh_preview.call())

	_add_slider_field(vbox, "Max ancho", _stage_max_width, 0.2, 0.6, func(val: float):
		preview_stage.char_max_width_frac = val
		_stage_max_width = val
		_refresh_preview.call())

	var apply_info := Label.new()
	apply_info.text = "Los valores se aplican al jugar."
	apply_info.add_theme_font_size_override("font_size", 11)
	apply_info.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	vbox.add_child(apply_info)

	margin.add_child(vbox)
	detail_content.add_child(margin)


# ── Detail Builders ──

func _build_character_detail(parent: VBoxContainer, node) -> void:
	if node.character_data == null:
		node.character_data = CharacterDataScript.new()
	var data: Resource = node.character_data

	# ── Identidad ──
	_add_section_header(parent, "Identidad")

	_add_field(parent, "ID", data.character_id, func(val: String):
		data.character_id = val
		node._refresh_display())

	_add_field(parent, "Nombre", data.display_name, func(val: String):
		data.display_name = val
		node._refresh_display())

	_add_color_field(parent, "Color", data.color, func(val: Color):
		data.color = val
		node._refresh_display())

	# ── Retrato ──
	_add_section_header(parent, "Retrato")

	# Live portrait preview with mask (simulates runtime behavior)
	var mask_container := Control.new()
	mask_container.custom_minimum_size = Vector2(160, 200)
	mask_container.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	# Dark background to see the mask area
	var mask_bg := ColorRect.new()
	mask_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask_bg.color = Color(0.1, 0.1, 0.15)
	mask_container.add_child(mask_bg)

	var preview_img := TextureRect.new()
	preview_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if data.portrait_image:
		preview_img.texture = data.portrait_image
	# Apply current zoom/offset
	preview_img.pivot_offset = Vector2(80, 100)  # center of 160x200
	preview_img.scale = Vector2(data.portrait_zoom, data.portrait_zoom)
	preview_img.position = data.portrait_offset * Vector2(160, 200)
	mask_container.add_child(preview_img)
	parent.add_child(mask_container)

	# Update preview function
	var _refresh_crop := func():
		preview_img.scale = Vector2(data.portrait_zoom, data.portrait_zoom)
		preview_img.position = data.portrait_offset * Vector2(160, 200)
		preview_img.pivot_offset = Vector2(80, 100)

	_add_file_field(parent, "Imagen", data.portrait_image.resource_path if data.portrait_image else "", func(val: String):
		if ResourceLoader.exists(val):
			data.portrait_image = load(val)
			preview_img.texture = data.portrait_image
			node._refresh_display())

	_add_slider_field(parent, "Zoom", data.portrait_zoom, 0.5, 3.0, func(val: float):
		data.portrait_zoom = val
		_refresh_crop.call())

	var _ox_cb := func(val: float):
		data.portrait_offset.x = val
		_refresh_crop.call()
	_add_slider_field(parent, "Offset X", data.portrait_offset.x, -0.5, 0.5, _ox_cb)

	var _oy_cb := func(val: float):
		data.portrait_offset.y = val
		_refresh_crop.call()
	_add_slider_field(parent, "Offset Y", data.portrait_offset.y, -0.5, 0.5, _oy_cb)

	# ── Gameplay ──
	_add_section_header(parent, "Gameplay")

	_add_option_field(parent, "Pieza", data.piece_type,
		["X", "O"],
		func(val: String): data.piece_type = val)

	_add_option_field(parent, "Estilo", data.default_style,
		["gentle", "slam", "spinning", "dramatic", "nervous"],
		func(val: String): data.default_style = val)

	_add_field(parent, "Pose default", data.default_pose, func(val: String):
		data.default_pose = val)

	_add_option_field(parent, "Direccion", data.default_look,
		["left", "center", "right", "away"],
		func(val: String): data.default_look = val)

	# ── Expresiones ──
	_add_section_header(parent, "Expresiones (%d)" % data.expressions.size())

	for expr_name in data.expressions:
		var expr_color: Color = data.expressions[expr_name]
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		var name_lbl := Label.new()
		name_lbl.text = expr_name
		name_lbl.custom_minimum_size.x = 80
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
		hbox.add_child(name_lbl)
		var color_rect := ColorRect.new()
		color_rect.color = expr_color
		color_rect.custom_minimum_size = Vector2(24, 16)
		hbox.add_child(color_rect)
		if data.expression_images.has(expr_name) and data.expression_images[expr_name] != null:
			var img_lbl := Label.new()
			img_lbl.text = "img"
			img_lbl.add_theme_font_size_override("font_size", 10)
			img_lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_START)
			hbox.add_child(img_lbl)
		parent.add_child(hbox)

	# Add expression button
	var add_expr_hbox := HBoxContainer.new()
	add_expr_hbox.add_theme_constant_override("separation", 4)
	var new_expr_edit := LineEdit.new()
	new_expr_edit.placeholder_text = "nueva expresion"
	new_expr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_expr_edit.add_theme_font_size_override("font_size", 12)
	add_expr_hbox.add_child(new_expr_edit)
	var add_expr_btn := Button.new()
	add_expr_btn.text = "+"
	add_expr_btn.add_theme_font_size_override("font_size", 12)
	add_expr_btn.pressed.connect(func():
		var ename: String = new_expr_edit.text.strip_edges()
		if ename != "" and not data.expressions.has(ename):
			data.expressions[ename] = data.color
			_show_detail_for_node(node))
	add_expr_hbox.add_child(add_expr_btn)
	parent.add_child(add_expr_hbox)

	# ── Poses ──
	_add_section_header(parent, "Poses (%d)" % data.poses.size())

	for pose_name in data.poses:
		var pose_lbl := Label.new()
		pose_lbl.text = "  %s" % pose_name
		pose_lbl.add_theme_font_size_override("font_size", 12)
		pose_lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
		parent.add_child(pose_lbl)

	var add_pose_hbox := HBoxContainer.new()
	add_pose_hbox.add_theme_constant_override("separation", 4)
	var new_pose_edit := LineEdit.new()
	new_pose_edit.placeholder_text = "nueva pose"
	new_pose_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_pose_edit.add_theme_font_size_override("font_size", 12)
	add_pose_hbox.add_child(new_pose_edit)
	var add_pose_btn := Button.new()
	add_pose_btn.text = "+"
	add_pose_btn.add_theme_font_size_override("font_size", 12)
	add_pose_btn.pressed.connect(func():
		var pname: String = new_pose_edit.text.strip_edges()
		if pname != "" and not data.poses.has(pname):
			data.poses[pname] = {"description": "", "energy": 0.5, "openness": 0.5}
			_show_detail_for_node(node))
	add_pose_hbox.add_child(add_pose_btn)
	parent.add_child(add_pose_hbox)

	# ── Voz ──
	_add_section_header(parent, "Voz")

	_add_slider_field(parent, "Pitch", data.voice_pitch, 50.0, 500.0, func(val: float):
		data.voice_pitch = val)

	_add_slider_field(parent, "Variacion", data.voice_variation, 0.0, 100.0, func(val: float):
		data.voice_variation = val)

	_add_option_field(parent, "Waveform", data.voice_waveform,
		["sine", "square", "triangle"],
		func(val: String): data.voice_waveform = val)

	# ── Estilo Dialogo ──
	_add_section_header(parent, "Dialogo")

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
		node.set_script_path(val)
		_show_detail_for_node(node))

	# Create new script button
	if node.script_path == "":
		var create_btn := Button.new()
		create_btn.text = "Crear nuevo script"
		create_btn.add_theme_font_size_override("font_size", 13)
		var cs := StyleBoxFlat.new()
		cs.bg_color = GraphThemeC.COLOR_CUTSCENE.darkened(0.4)
		cs.set_corner_radius_all(4)
		cs.content_margin_left = 8
		cs.content_margin_right = 8
		cs.content_margin_top = 4
		cs.content_margin_bottom = 4
		create_btn.add_theme_stylebox_override("normal", cs)
		create_btn.add_theme_color_override("font_color", Color.WHITE)
		create_btn.pressed.connect(func():
			var new_path := "res://scene_scripts/scripts/new_scene_%s.dscn" % node.node_id
			var f := FileAccess.open(new_path, FileAccess.WRITE)
			if f:
				f.store_string("@scene new_scene\n\n[fullscreen]\n[camera_mode smooth]\n\n")
				f.close()
				node.set_script_path(new_path)
				_show_detail_for_node(node))
		parent.add_child(create_btn)

	# Editable script content
	if node.script_path != "" and FileAccess.file_exists(node.script_path):
		_add_section_header(parent, "Editor de Script")

		var code := CodeEdit.new()
		code.custom_minimum_size = Vector2(0, 300)
		code.size_flags_vertical = Control.SIZE_EXPAND_FILL
		code.text = FileAccess.get_file_as_string(node.script_path)
		code.add_theme_font_size_override("font_size", 11)
		code.gutters_draw_line_numbers = true
		parent.add_child(code)

		# Save button
		var save_script_btn := Button.new()
		save_script_btn.text = "Guardar script"
		save_script_btn.add_theme_font_size_override("font_size", 13)
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(0.2, 0.5, 0.3)
		ss.set_corner_radius_all(4)
		ss.content_margin_left = 8
		ss.content_margin_right = 8
		ss.content_margin_top = 4
		ss.content_margin_bottom = 4
		save_script_btn.add_theme_stylebox_override("normal", ss)
		save_script_btn.add_theme_color_override("font_color", Color.WHITE)
		var script_path_ref: String = node.script_path
		save_script_btn.pressed.connect(func():
			var f := FileAccess.open(script_path_ref, FileAccess.WRITE)
			if f:
				f.store_string(code.text)
				f.close()
				print("[GraphEditor] Script guardado: ", script_path_ref))
		parent.add_child(save_script_btn)

		# Quick command buttons
		_add_section_header(parent, "Comandos rapidos")
		var cmd_grid := GridContainer.new()
		cmd_grid.columns = 3
		cmd_grid.add_theme_constant_override("h_separation", 4)
		cmd_grid.add_theme_constant_override("v_separation", 4)
		var commands := [
			["enter", "[enter char center left]"],
			["exit", "[exit char left]"],
			["expr", "[expression char neutral]"],
			["pose", "[pose char idle]"],
			["focus", "[focus char]"],
			["unfocus", "[clear_focus]"],
			["close_up", "[close_up char 1.3 0.4]"],
			["cam_reset", "[camera_reset 0.3]"],
			["flash", "[flash #ffffff 0.08]"],
			["shake", "[shake 0.3 0.2]"],
			["wait", "[wait 0.5]"],
			["music", "[music bgm_chill.mp3]"],
			["title", "[title_card Titulo | Sub]"],
			["split", "[split]"],
			["full", "[fullscreen]"],
			["flag", "[set_flag flag_name]"],
			["if", "[if flag name]\n\n[end_if]"],
			["choose", "[choose]\n> Opcion -> flag\n[end_choose]"],
		]
		for cmd in commands:
			var btn := Button.new()
			btn.text = cmd[0]
			btn.add_theme_font_size_override("font_size", 10)
			var cmd_text: String = cmd[1]
			btn.pressed.connect(func(): code.insert_text_at_caret(cmd_text + "\n"))
			cmd_grid.add_child(btn)
		parent.add_child(cmd_grid)


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

	# Presets
	_add_section_header(parent, "Preset")
	var preset_hbox := HBoxContainer.new()
	preset_hbox.add_theme_constant_override("separation", 4)
	var presets := [["Std 3x3", 3, 3, -1, true], ["Rot 3", 3, 3, 3, false], ["Big 5x5", 5, 4, -1, true]]
	for p in presets:
		var btn := Button.new()
		btn.text = p[0]
		btn.add_theme_font_size_override("font_size", 11)
		var p_ref: Array = p
		btn.pressed.connect(func():
			rules.board_size = p_ref[1]
			rules.win_length = p_ref[2]
			rules.max_pieces_per_player = p_ref[3]
			rules.allow_draw = p_ref[4]
			if p_ref[3] > 0:
				rules.overflow_mode = "rotate"
			node._refresh_display()
			_show_detail_for_node(node))
		preset_hbox.add_child(btn)
	parent.add_child(preset_hbox)

	# Rules
	_add_section_header(parent, "Reglas")

	var _bs_cb := func(val: float):
		rules.board_size = int(val)
		node._refresh_display()
	_add_slider_field(parent, "Tamano", float(rules.board_size), 3.0, 7.0, _bs_cb, 1.0)

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

	# Visual config
	_add_section_header(parent, "Visual")

	_add_color_field(parent, "Celda vacia", config.cell_color_empty, func(val: Color):
		config.cell_color_empty = val; node._refresh_display())

	var checker := CheckBox.new()
	checker.text = "Checkerboard"
	checker.button_pressed = config.checkerboard_enabled
	checker.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	checker.add_theme_font_size_override("font_size", 13)
	checker.toggled.connect(func(p: bool): config.checkerboard_enabled = p; node._refresh_display())
	parent.add_child(checker)

	if config.checkerboard_enabled:
		_add_color_field(parent, "Celda alt", config.cell_color_alt, func(val: Color):
			config.cell_color_alt = val; node._refresh_display())

	_add_color_field(parent, "Lineas", config.cell_line_color, func(val: Color):
		config.cell_line_color = val; node._refresh_display())

	_add_color_field(parent, "Fondo", config.board_bg_color, func(val: Color):
		config.board_bg_color = val)

	_add_section_header(parent, "Colores Jugadores")

	_add_color_field(parent, "Jugador", config.default_player_color, func(val: Color):
		config.default_player_color = val)

	_add_color_field(parent, "Oponente", config.default_opponent_color, func(val: Color):
		config.default_opponent_color = val)


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
	var _browse_cb := func():
		_file_dialog.filters = PackedStringArray(["*.dscn ; Scene Scripts"])
		_file_dialog.current_dir = "res://scene_scripts/scripts/"
		var _on_file := func(path: String):
			edit.text = path
			on_change.call(path)
		_file_dialog.file_selected.connect(_on_file, CONNECT_ONE_SHOT)
		_file_dialog.popup_centered(Vector2i(600, 400))
	browse.pressed.connect(_browse_cb)
	hbox.add_child(browse)
	parent.add_child(hbox)


func _add_section_header(parent: VBoxContainer, text: String) -> void:
	parent.add_child(HSeparator.new())
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	parent.add_child(lbl)


func _add_help_line(parent: VBoxContainer, key: String, desc: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.custom_minimum_size.x = 100
	key_lbl.add_theme_font_size_override("font_size", 12)
	key_lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)
	hbox.add_child(key_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)
	hbox.add_child(desc_lbl)
	parent.add_child(hbox)


# ── Cinematic Sub-Editor ──

func _open_cinematic_editor(cutscene_node) -> void:
	if _cinematic_editor != null:
		return

	# Collect characters from root canvas
	var chars: Array = []
	for child in graph_edit.get_children():
		if child is CharacterNodeScript and child.character_data:
			chars.append(child.character_data)

	_cinematic_editor = CinematicEditorScript.new()
	_cinematic_editor.open(cutscene_node, chars, _graph_parent)

	# Hide main graph, show cinematic sub-canvas
	graph_edit.visible = false
	_breadcrumb_label.text = "Canvas > %s" % (cutscene_node.script_path.get_file().get_basename() if cutscene_node.script_path != "" else "nueva escena")
	_clear_detail()
	_show_welcome_panel()


func _close_cinematic_editor() -> void:
	if _cinematic_editor == null:
		return
	_cinematic_editor.close()
	_cinematic_editor = null
	graph_edit.visible = true
	_breadcrumb_label.text = "Editor 2.0 — Canvas"
	_show_welcome_panel()


func _is_in_cinematic_editor() -> bool:
	return _cinematic_editor != null


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

	# Store canvas data and stage settings
	project.set_meta("canvas_data", _serialize_canvas())
	project.set_meta("stage_height_ratio", _stage_height_ratio)
	project.set_meta("stage_aspect", _stage_aspect)
	project.set_meta("stage_max_width", _stage_max_width)

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
