extends Control

## Editor 2.0 main controller.
## HSplitContainer with GraphEdit (left) and DetailPanel (right).
## Delegates to helpers: DetailPanelBuilder, GraphSerializer, PreviewManager, NodeOperations.

const GraphThemeC = preload("res://editor/graph/graph_theme.gd")
const ConnectionRulesC = preload("res://editor/graph/connection_rules.gd")
const DetailPanelBuilderScript = preload("res://editor/graph/panels/detail_panel_builder.gd")
const GraphSerializerScript = preload("res://editor/graph/panels/graph_serializer.gd")
const PreviewManagerScript = preload("res://editor/graph/panels/preview_manager.gd")
const NodeOperationsScript = preload("res://editor/graph/panels/node_operations.gd")

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
var _graph_parent: Control = null
var _breadcrumb_label: Label = null
var _validation_label: Button = null

# Helpers
var _detail_builder: RefCounted = null  # DetailPanelBuilder
var _serializer: RefCounted = null      # GraphSerializer
var _preview_manager: RefCounted = null # PreviewManager
var _node_ops: RefCounted = null        # NodeOperations


func _ready() -> void:
	_undo_redo = UndoRedo.new()
	_build_ui()
	_detail_builder = DetailPanelBuilderScript.new(self)
	_preview_manager = PreviewManagerScript.new(self)
	_node_ops = NodeOperationsScript.new(self)
	_serializer = GraphSerializerScript.new(self)
	_setup_graph_edit()
	_load_or_create_default()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Z and event.ctrl_pressed and not event.shift_pressed:
			if _undo_redo.has_undo():
				_undo_redo.undo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z and event.ctrl_pressed and event.shift_pressed:
			if _undo_redo.has_redo():
				_undo_redo.redo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_S and event.ctrl_pressed:
			_on_save_pressed()
			get_viewport().set_input_as_handled()


# ── UI Construction ──

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = GraphThemeC.COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	var toolbar := _build_toolbar()
	vbox.add_child(toolbar)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = -350
	vbox.add_child(split)

	_graph_parent = split

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

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	add_child(_file_dialog)

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

	var back_btn := _make_toolbar_button("< Volver", Color(0.5, 0.5, 0.6))
	back_btn.pressed.connect(func():
		if _preview_manager and _preview_manager.is_in_cinematic_editor():
			_preview_manager.close_cinematic_editor()
		else:
			get_tree().change_scene_to_file("res://systems/dev_menu.tscn"))
	hbox.add_child(back_btn)

	hbox.add_child(VSeparator.new())

	_breadcrumb_label = Label.new()
	_breadcrumb_label.text = "Editor 2.0 — Canvas"
	_breadcrumb_label.add_theme_font_size_override("font_size", 16)
	_breadcrumb_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	hbox.add_child(_breadcrumb_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_validation_label = Button.new()
	_validation_label.text = "-- Grafo valido"
	_validation_label.add_theme_font_size_override("font_size", 12)
	_validation_label.add_theme_color_override("font_color", GraphThemeC.COLOR_VALIDATION_OK)
	_validation_label.flat = true
	_validation_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_validation_label.pressed.connect(_on_validation_label_pressed)
	hbox.add_child(_validation_label)

	hbox.add_child(VSeparator.new())

	var add_btn := _make_toolbar_button("+ Agregar Nodo", Color(0.3, 0.6, 0.9))
	add_btn.pressed.connect(func(): _show_add_menu(add_btn.global_position + Vector2(0, add_btn.size.y)))
	hbox.add_child(add_btn)

	hbox.add_child(VSeparator.new())

	var preview_btn := _make_toolbar_button("Preview", Color(0.7, 0.4, 0.2))
	preview_btn.pressed.connect(func():
		if _preview_manager:
			_preview_manager.on_preview_toolbar_pressed())
	hbox.add_child(preview_btn)

	var settings_btn := _make_toolbar_button("Ajustes", Color(0.5, 0.4, 0.6))
	settings_btn.pressed.connect(func():
		if _detail_builder:
			_detail_builder.show_stage_settings())
	hbox.add_child(settings_btn)

	hbox.add_child(VSeparator.new())

	var save_btn := _make_toolbar_button("Guardar", Color(0.3, 0.7, 0.4))
	save_btn.pressed.connect(_on_save_pressed)
	hbox.add_child(save_btn)

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
	_popup_menu.id_pressed.connect(func(id: int):
		if _node_ops:
			_node_ops.on_context_menu_selected(id))
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
	_add_menu.id_pressed.connect(func(id: int):
		if _node_ops:
			_node_ops.on_context_menu_selected(id))
	add_child(_add_menu)


func _show_add_menu(pos: Vector2) -> void:
	_context_position = (graph_edit.scroll_offset + graph_edit.size / 2) / graph_edit.zoom
	_add_menu.position = Vector2i(pos)
	_add_menu.popup()


# ── GraphEdit Setup ──

func _setup_graph_edit() -> void:
	graph_edit.connection_request.connect(_node_ops.on_connection_request)
	graph_edit.disconnection_request.connect(_node_ops.on_disconnection_request)
	graph_edit.node_selected.connect(_node_ops.on_node_selected)
	graph_edit.node_deselected.connect(_node_ops.on_node_deselected)
	graph_edit.delete_nodes_request.connect(_node_ops.on_delete_nodes_request)
	graph_edit.popup_request.connect(_node_ops.on_popup_request)
	graph_edit.copy_nodes_request.connect(_node_ops.on_copy_nodes)
	graph_edit.paste_nodes_request.connect(_node_ops.on_paste_nodes)
	graph_edit.duplicate_nodes_request.connect(_node_ops.on_duplicate_nodes)

	graph_edit.add_valid_connection_type(GraphThemeC.PORT_FLOW, GraphThemeC.PORT_FLOW)
	graph_edit.add_valid_connection_type(GraphThemeC.PORT_CHARACTER, GraphThemeC.PORT_CHARACTER)
	graph_edit.add_valid_connection_type(GraphThemeC.PORT_BOARD_CONFIG, GraphThemeC.PORT_BOARD_CONFIG)
	graph_edit.add_valid_connection_type(GraphThemeC.PORT_SCRIPT, GraphThemeC.PORT_SCRIPT)


# ── Save / Load / Play ──

func _on_save_pressed() -> void:
	var project: Resource = _serializer.graph_to_project_data()
	var err: int = ResourceSaver.save(project, SAVE_PATH)
	if err == OK:
		print("[GraphEditor] Proyecto guardado en: ", SAVE_PATH)
	else:
		push_error("[GraphEditor] Error al guardar: %s" % error_string(err))


func _on_play_pressed() -> void:
	_on_save_pressed()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://main.tscn")


func _load_or_create_default() -> void:
	const ProjectDataScript = preload("res://data/project_data.gd")
	# Try user save first, then fall back to bundled demo project
	for path in [SAVE_PATH, "res://data/resources/demo_story_project.tres"]:
		if ResourceLoader.exists(path):
			var project := ResourceLoader.load(path)
			if project is ProjectDataScript:
				_serializer.import_project_data(project)
				return

	# Default: create StartNode + EndNode
	_node_ops.create_node("start", Vector2(100, 300))
	_node_ops.create_node("end", Vector2(800, 300))
	_detail_builder.show_welcome_panel()
	call_deferred("validate_all_nodes")


# ── Validation ──

func validate_all_nodes() -> void:
	var total_errors := 0
	var total_warnings := 0
	var first_problem_node: GraphNode = null

	for child in graph_edit.get_children():
		if child is BaseGraphNode:
			child.update_validation_display()
			var result: Dictionary = child._last_validation
			var errs: int = result.errors.size()
			var warns: int = result.warnings.size()
			total_errors += errs
			total_warnings += warns
			if (errs > 0 or warns > 0) and first_problem_node == null:
				first_problem_node = child

	_update_validation_toolbar(total_errors, total_warnings)


func _update_validation_toolbar(errors: int, warnings: int) -> void:
	if _validation_label == null:
		return
	var total := errors + warnings
	if total == 0:
		_validation_label.text = "-- Grafo valido"
		_validation_label.add_theme_color_override("font_color", GraphThemeC.COLOR_VALIDATION_OK)
	else:
		var parts: PackedStringArray = []
		if errors > 0:
			parts.append("%d error%s" % [errors, "es" if errors > 1 else ""])
		if warnings > 0:
			parts.append("%d aviso%s" % [warnings, "s" if warnings > 1 else ""])
		_validation_label.text = "!! %s" % ", ".join(parts)
		_validation_label.add_theme_color_override("font_color", GraphThemeC.COLOR_VALIDATION_PROBLEM)


func _on_validation_label_pressed() -> void:
	# Select the first node with a problem
	for child in graph_edit.get_children():
		if child is BaseGraphNode:
			var result: Dictionary = child._last_validation
			if result.errors.size() > 0 or result.warnings.size() > 0:
				# Deselect all first
				for other in graph_edit.get_children():
					if other is GraphNode:
						other.selected = false
				child.selected = true
				# Scroll to show the node
				graph_edit.scroll_offset = child.position_offset * graph_edit.zoom - graph_edit.size / 2
				_node_ops.on_node_selected(child)
				return
