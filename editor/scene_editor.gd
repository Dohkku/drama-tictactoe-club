extends HSplitContainer

## Scene Script Editor — visual editor for .dscn cutscene/reaction scripts.
## Provides syntax-highlighted code editing, command palette for quick insertion,
## and a live preview via SubViewport with CinematicStage + DialogueBox.

const CinematicStageScene = preload("res://cinematic/cinematic_stage.tscn")
const DialogueBoxScene = preload("res://cinematic/dialogue_box.tscn")

# --- Node references (built in _ready) ---
var code_edit: CodeEdit
var file_name_label: Label
var preview_viewport: SubViewport
var preview_stage: Control  # CinematicStage instance
var preview_dialogue: Control  # DialogueBox instance
var speed_slider: HSlider
var status_label: Label

# --- File state ---
var _current_file_path: String = ""
var _file_dialog: FileDialog = null

# --- Preview state ---
var _scene_runner: RefCounted = null  # SceneRunner
var _parsed_data: Dictionary = {}
var _command_index: int = 0
var _is_playing: bool = false
var _is_stepping: bool = false

# --- Character registry for preview ---
var _preview_characters: Array[Resource] = []


func _ready() -> void:
	_build_ui()
	_setup_highlighting()
	_register_default_characters()


# ============================================================
# UI CONSTRUCTION
# ============================================================

func _build_ui() -> void:
	# Root is this HSplitContainer
	split_offset = 500
	dragger_visibility = SplitContainer.DRAGGER_VISIBLE

	# === LEFT PANEL ===
	var left_panel := VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.6
	add_child(left_panel)

	# File bar
	var file_bar := HBoxContainer.new()
	file_bar.add_theme_constant_override("separation", 6)
	left_panel.add_child(file_bar)

	var new_btn := _make_button("Nuevo")
	new_btn.pressed.connect(_on_new_pressed)
	file_bar.add_child(new_btn)

	var open_btn := _make_button("Abrir")
	open_btn.pressed.connect(_on_open_pressed)
	file_bar.add_child(open_btn)

	var save_btn := _make_button("Guardar")
	save_btn.pressed.connect(_on_save_pressed)
	file_bar.add_child(save_btn)

	file_name_label = Label.new()
	file_name_label.text = "(sin archivo)"
	file_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	file_name_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	file_name_label.add_theme_font_size_override("font_size", 13)
	file_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	file_bar.add_child(file_name_label)

	# Code editor
	code_edit = CodeEdit.new()
	code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_edit.custom_minimum_size = Vector2(300, 200)
	code_edit.draw_tabs = true
	code_edit.draw_spaces = false
	code_edit.minimap_draw = false
	code_edit.line_folding = true
	code_edit.gutters_draw_line_numbers = true
	code_edit.gutters_draw_fold_gutter = true
	code_edit.scroll_smooth = true
	code_edit.caret_blink = true
	code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY

	# Dark editor colors
	var editor_sb := StyleBoxFlat.new()
	editor_sb.bg_color = Color(0.08, 0.08, 0.1)
	editor_sb.border_color = Color(0.2, 0.2, 0.28)
	editor_sb.set_border_width_all(1)
	editor_sb.set_corner_radius_all(4)
	editor_sb.set_content_margin_all(8)
	code_edit.add_theme_stylebox_override("normal", editor_sb)
	code_edit.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
	code_edit.add_theme_color_override("background_color", Color(0.08, 0.08, 0.1))
	code_edit.add_theme_color_override("current_line_color", Color(0.12, 0.12, 0.16))
	code_edit.add_theme_color_override("line_number_color", Color(0.35, 0.35, 0.42))
	code_edit.add_theme_color_override("caret_color", Color(0.9, 0.9, 1.0))
	code_edit.add_theme_color_override("selection_color", Color(0.2, 0.3, 0.5, 0.5))
	code_edit.add_theme_font_size_override("font_size", 14)

	# Set placeholder text
	code_edit.placeholder_text = "# Escribe tu script aquí...\n@scene mi_escena\n\n[enter akira center]\nakira \"confident\": ¡Hola!\n\n@end"

	left_panel.add_child(code_edit)

	# Command palette label
	var palette_label := Label.new()
	palette_label.text = "Insertar comando:"
	palette_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	palette_label.add_theme_font_size_override("font_size", 12)
	left_panel.add_child(palette_label)

	# Command palette (scrollable)
	var palette_scroll := ScrollContainer.new()
	palette_scroll.custom_minimum_size = Vector2(0, 42)
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	palette_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(palette_scroll)

	var palette := HBoxContainer.new()
	palette.add_theme_constant_override("separation", 4)
	palette_scroll.add_child(palette)

	_add_palette_buttons(palette)

	# === RIGHT PANEL ===
	var right_panel := VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.4
	right_panel.add_theme_constant_override("separation", 6)
	add_child(right_panel)

	# Preview label
	var preview_label := Label.new()
	preview_label.text = "Vista Previa"
	preview_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	preview_label.add_theme_font_size_override("font_size", 15)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_panel.add_child(preview_label)

	# Preview container
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.06, 0.06, 0.08)
	panel_sb.border_color = Color(0.2, 0.2, 0.28)
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(4)
	panel_sb.set_content_margin_all(2)
	preview_panel.add_theme_stylebox_override("panel", panel_sb)
	right_panel.add_child(preview_panel)

	var subviewport_container := SubViewportContainer.new()
	subviewport_container.stretch = true
	subviewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subviewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(subviewport_container)

	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(480, 320)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	preview_viewport.handle_input_locally = true
	preview_viewport.gui_disable_input = false
	preview_viewport.transparent_bg = false
	subviewport_container.add_child(preview_viewport)

	# Instance the cinematic stage into the SubViewport
	_setup_preview_stage()

	# Playback controls
	var playback := HBoxContainer.new()
	playback.add_theme_constant_override("separation", 6)
	playback.alignment = BoxContainer.ALIGNMENT_CENTER
	right_panel.add_child(playback)

	var play_btn := _make_button("Reproducir")
	play_btn.pressed.connect(_on_play_pressed)
	playback.add_child(play_btn)

	var step_btn := _make_button("Paso")
	step_btn.pressed.connect(_on_step_pressed)
	playback.add_child(step_btn)

	var stop_btn := _make_button("Detener")
	stop_btn.pressed.connect(_on_stop_pressed)
	playback.add_child(stop_btn)

	# Speed controls
	var speed_label := Label.new()
	speed_label.text = "Velocidad:"
	speed_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	speed_label.add_theme_font_size_override("font_size", 12)
	playback.add_child(speed_label)

	speed_slider = HSlider.new()
	speed_slider.min_value = 0.5
	speed_slider.max_value = 3.0
	speed_slider.step = 0.25
	speed_slider.value = 1.0
	speed_slider.custom_minimum_size = Vector2(80, 20)
	speed_slider.tooltip_text = "Velocidad de reproducción"
	playback.add_child(speed_slider)

	var speed_value_label := Label.new()
	speed_value_label.text = "1.0x"
	speed_value_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	speed_value_label.add_theme_font_size_override("font_size", 12)
	speed_slider.value_changed.connect(func(val: float) -> void: speed_value_label.text = "%.1fx" % val)
	playback.add_child(speed_value_label)

	# Status bar
	status_label = Label.new()
	status_label.text = "Listo"
	status_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.4))
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_panel.add_child(status_label)


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.16, 0.22)
	sb.border_color = Color(0.3, 0.3, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", sb)
	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = Color(0.2, 0.22, 0.3)
	hover_sb.border_color = Color(0.4, 0.4, 0.55)
	hover_sb.set_border_width_all(1)
	hover_sb.set_corner_radius_all(4)
	hover_sb.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	btn.add_theme_font_size_override("font_size", 13)
	return btn


func _make_palette_button(text: String, insert_text: String) -> Button:
	var btn := _make_button(text)
	btn.add_theme_font_size_override("font_size", 11)
	btn.custom_minimum_size = Vector2(0, 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.2)
	sb.border_color = Color(0.25, 0.3, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.pressed.connect(_insert_template.bind(insert_text))
	return btn


# ============================================================
# COMMAND PALETTE
# ============================================================

func _add_palette_buttons(container: HBoxContainer) -> void:
	var commands := [
		["Dialogo", "character \"expression\": texto"],
		["Entrar", "[enter character center]"],
		["Salir", "[exit character]"],
		["Mover", "[move character center]"],
		["Esperar", "[wait 1.0]"],
		["Shake", "[shake 0.5 0.3]"],
		["Flash", "[flash white 0.3]"],
		["Elegir", "[choose]\n> opcion -> flag\n[end_choose]"],
		["Si/Flag", "[if flag nombre]\n[else]\n[end_if]"],
		["Fullscreen", "[fullscreen]"],
		["Split", "[split]"],
		["Close-up", "[close_up character 1.4 0.5]"],
		["Pose", "[pose character idle]"],
		["Mirada", "[look_at character target]"],
		["Musica", "[music track_name]"],
		["SFX", "[sfx sound_name]"],
		["Foco", "[focus character]"],
		["Profund.", "[depth character 1.2 0.4]"],
	]

	for cmd in commands:
		container.add_child(_make_palette_button(cmd[0], cmd[1]))


func _insert_template(template: String) -> void:
	if code_edit == null:
		return
	var line := code_edit.get_caret_line()
	var col := code_edit.get_caret_column()

	code_edit.begin_complex_operation()
	code_edit.insert_text_at_caret(template)
	code_edit.end_complex_operation()

	# Move caret to end of inserted text
	var lines := template.split("\n")
	if lines.size() > 1:
		code_edit.set_caret_line(line + lines.size() - 1)
		code_edit.set_caret_column(lines[lines.size() - 1].length())
	else:
		code_edit.set_caret_column(col + template.length())

	code_edit.grab_focus()


# ============================================================
# SYNTAX HIGHLIGHTING
# ============================================================

func _setup_highlighting() -> void:
	var highlighter := CodeHighlighter.new()

	# Line comments (gray)
	highlighter.add_color_region("#", "", Color(0.5, 0.5, 0.55), true)

	# Bracket commands (cyan/teal)
	highlighter.add_color_region("[", "]", Color(0.3, 0.8, 0.8))

	# Quoted expressions (green)
	highlighter.add_color_region("\"", "\"", Color(0.4, 0.8, 0.4))

	# DSL text tags (yellow)
	highlighter.add_color_region("{", "}", Color(0.9, 0.8, 0.3))

	# Keywords (purple/violet)
	for kw in ["@scene", "@reactions", "@on", "@end_on", "@end", "@background"]:
		highlighter.keyword_colors[kw] = Color(0.6, 0.4, 0.9)

	# Character names (orange) — configurable list
	for char_name in ["akira", "mei", "player", "hiro", "yuki", "sensei"]:
		highlighter.keyword_colors[char_name] = Color(0.9, 0.6, 0.2)

	# Choice marker
	highlighter.keyword_colors[">"] = Color(0.8, 0.5, 0.8)

	# Number color
	highlighter.number_color = Color(0.6, 0.8, 1.0)

	# Function color (for command names inside brackets — handled by region)
	highlighter.function_color = Color(0.3, 0.8, 0.8)

	# Symbol color
	highlighter.symbol_color = Color(0.65, 0.65, 0.72)

	# Member variable color
	highlighter.member_variable_color = Color(0.9, 0.6, 0.2)

	code_edit.syntax_highlighter = highlighter


# ============================================================
# PREVIEW SETUP
# ============================================================

func _setup_preview_stage() -> void:
	# Instance the CinematicStage scene into the preview SubViewport
	preview_stage = CinematicStageScene.instantiate()
	preview_viewport.add_child(preview_stage)

	# Instance the DialogueBox for preview
	preview_dialogue = DialogueBoxScene.instantiate()
	preview_viewport.add_child(preview_dialogue)

	# Ensure the dialogue box is visible at the bottom of the viewport
	preview_dialogue.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	preview_dialogue.offset_top = -100


func _register_default_characters() -> void:
	# Register some default characters for preview.
	# These use the CharacterData resource structure.
	var defaults := [
		{"id": "akira", "name": "Akira", "color": Color(0.9, 0.3, 0.2),
		 "bg": Color(0.15, 0.08, 0.08, 0.9), "border": Color(0.9, 0.3, 0.2)},
		{"id": "mei", "name": "Mei", "color": Color(0.3, 0.5, 0.9),
		 "bg": Color(0.08, 0.08, 0.15, 0.9), "border": Color(0.3, 0.5, 0.9)},
		{"id": "player", "name": "Jugador", "color": Color(0.8, 0.8, 0.9),
		 "bg": Color(0.1, 0.1, 0.15, 0.9), "border": Color(0.5, 0.5, 0.6)},
	]

	for def in defaults:
		var data := CharacterData.new()
		data.character_id = def.id
		data.display_name = def.name
		data.color = def.color
		data.dialogue_bg_color = def.bg
		data.dialogue_border_color = def.border
		data.default_pose = "idle"
		data.default_look = "center"
		data.voice_pitch = 220.0
		data.voice_variation = 30.0
		data.voice_waveform = "sine"
		data.expressions = {
			"neutral": def.color,
			"confident": def.color.lightened(0.2),
			"nervous": def.color.darkened(0.2),
			"surprised": Color(0.9, 0.8, 0.3),
			"angry": Color(0.9, 0.2, 0.2),
			"happy": Color(0.3, 0.9, 0.4),
		}
		_preview_characters.append(data)
		if preview_stage:
			preview_stage.register_character(data)


## Allows external code (e.g., the editor shell) to pass in
## the characters defined in the character editor for preview use.
func set_preview_characters(chars: Array) -> void:
	_preview_characters.clear()
	for ch in chars:
		if ch is CharacterData:
			_preview_characters.append(ch)
			if preview_stage:
				preview_stage.register_character(ch)


# ============================================================
# FILE MANAGEMENT
# ============================================================

func _on_new_pressed() -> void:
	code_edit.text = "# Nuevo script\n@scene mi_escena\n\n\n@end\n"
	_current_file_path = ""
	file_name_label.text = "(sin archivo)"
	_set_status("Nuevo archivo creado")


func _on_open_pressed() -> void:
	if _file_dialog != null and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()

	_file_dialog = FileDialog.new()
	_file_dialog.title = "Abrir Script de Escena"
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.current_dir = "res://scene_scripts/scripts/"
	_file_dialog.filters = PackedStringArray(["*.dscn ; Scripts de Escena"])
	_file_dialog.size = Vector2i(700, 500)
	_file_dialog.file_selected.connect(_on_file_selected_open)

	# Style the dialog
	_file_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN

	add_child(_file_dialog)
	_file_dialog.popup_centered()


func _on_file_selected_open(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		_set_status("Error: no se pudo abrir %s" % path, true)
		return

	code_edit.text = file.get_as_text()
	file.close()
	_current_file_path = path
	file_name_label.text = path
	_set_status("Archivo abierto: %s" % path.get_file())

	if _file_dialog and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()
		_file_dialog = null


func _on_save_pressed() -> void:
	if _current_file_path == "":
		# No file open — prompt for save location
		_open_save_dialog()
		return

	_save_to_path(_current_file_path)


func _open_save_dialog() -> void:
	if _file_dialog != null and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()

	_file_dialog = FileDialog.new()
	_file_dialog.title = "Guardar Script de Escena"
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.current_dir = "res://scene_scripts/scripts/"
	_file_dialog.filters = PackedStringArray(["*.dscn ; Scripts de Escena"])
	_file_dialog.size = Vector2i(700, 500)
	_file_dialog.file_selected.connect(_on_file_selected_save)
	_file_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN

	add_child(_file_dialog)
	_file_dialog.popup_centered()


func _on_file_selected_save(path: String) -> void:
	# Ensure .dscn extension
	if not path.ends_with(".dscn"):
		path += ".dscn"
	_save_to_path(path)

	if _file_dialog and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()
		_file_dialog = null


func _save_to_path(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_set_status("Error: no se pudo guardar en %s" % path, true)
		return

	file.store_string(code_edit.text)
	file.close()
	_current_file_path = path
	file_name_label.text = path
	_set_status("Guardado: %s" % path.get_file())


# ============================================================
# PLAYBACK — LIVE PREVIEW
# ============================================================

func _on_play_pressed() -> void:
	_stop_preview()
	_parse_and_prepare()
	if _parsed_data.is_empty():
		return

	_is_playing = true
	_set_status("Reproduciendo...")

	# Set time scale from speed slider
	if preview_viewport.get_tree():
		Engine.time_scale = speed_slider.value

	if _parsed_data.type == "cutscene":
		_run_cutscene_preview()
	elif _parsed_data.type == "reactions":
		_set_status("Modo reacciones: usa 'Paso' para probar cada evento")
		_is_playing = false


func _on_step_pressed() -> void:
	if _parsed_data.is_empty():
		_parse_and_prepare()
		if _parsed_data.is_empty():
			return

	if _parsed_data.type == "cutscene":
		_step_cutscene()
	elif _parsed_data.type == "reactions":
		_step_reaction()


func _on_stop_pressed() -> void:
	_stop_preview()
	_set_status("Detenido")


func _parse_and_prepare() -> void:
	var text := code_edit.text
	if text.strip_edges().is_empty():
		_set_status("El editor esta vacio", true)
		return

	_parsed_data = SceneParser.parse(text)

	if _parsed_data.type == "cutscene" and _parsed_data.commands.is_empty():
		_set_status("No se encontraron comandos", true)
		_parsed_data = {}
		return

	if _parsed_data.type == "reactions" and _parsed_data.reactions.is_empty():
		_set_status("No se encontraron reacciones", true)
		_parsed_data = {}
		return

	_command_index = 0

	# Reset preview stage
	if preview_stage:
		preview_stage.clear_stage()

	# Re-register characters (they may have been lost after clear)
	for ch in _preview_characters:
		preview_stage.register_character(ch)

	_set_status("Script analizado: %s (%s)" % [_parsed_data.name, _parsed_data.type])


func _run_cutscene_preview() -> void:
	if _parsed_data.is_empty() or _parsed_data.type != "cutscene":
		return

	var commands: Array = _parsed_data.commands
	_command_index = 0

	while _command_index < commands.size() and _is_playing:
		var cmd: Dictionary = commands[_command_index]
		_set_status("Ejecutando [%d/%d]: %s" % [_command_index + 1, commands.size(), cmd.get("type", "?")])
		await _execute_preview_command(cmd)
		_command_index += 1

	if _is_playing:
		_is_playing = false
		Engine.time_scale = 1.0
		_set_status("Reproduccion finalizada")


func _step_cutscene() -> void:
	if _parsed_data.is_empty() or _parsed_data.type != "cutscene":
		return

	var commands: Array = _parsed_data.commands
	if _command_index >= commands.size():
		_set_status("Fin del script (reinicia con Reproducir)")
		return

	var cmd: Dictionary = commands[_command_index]
	_set_status("Paso [%d/%d]: %s" % [_command_index + 1, commands.size(), cmd.get("type", "?")])
	await _execute_preview_command(cmd)
	_command_index += 1


func _step_reaction() -> void:
	if _parsed_data.is_empty() or _parsed_data.type != "reactions":
		return

	var event_names := _parsed_data.reactions.keys()
	if event_names.is_empty():
		_set_status("No hay reacciones definidas")
		return

	# Cycle through reaction events one at a time
	if _command_index >= event_names.size():
		_command_index = 0

	var event_name: String = event_names[_command_index]
	var cmds: Array = _parsed_data.reactions[event_name]

	_set_status("Reaccion: '%s' (%d/%d)" % [event_name, _command_index + 1, event_names.size()])

	# Reset stage for each reaction
	preview_stage.clear_stage()
	for ch in _preview_characters:
		preview_stage.register_character(ch)

	# Run all commands in this reaction
	for cmd in cmds:
		await _execute_preview_command(cmd)

	_command_index += 1


func _stop_preview() -> void:
	_is_playing = false
	_is_stepping = false
	_command_index = 0
	_parsed_data = {}
	Engine.time_scale = 1.0

	# Clear the stage
	if preview_stage:
		preview_stage.clear_stage()
		# Re-register characters
		for ch in _preview_characters:
			preview_stage.register_character(ch)

	# Hide dialogue
	if preview_dialogue and preview_dialogue.has_method("hide_dialogue"):
		preview_dialogue.hide_dialogue()


# ============================================================
# COMMAND EXECUTION FOR PREVIEW
# ============================================================

func _execute_preview_command(cmd: Dictionary) -> void:
	if preview_stage == null:
		return

	var cmd_type: String = cmd.get("type", "")

	match cmd_type:
		"enter":
			var character_id: String = cmd.get("character", "")
			var position_name: String = cmd.get("position", "center")
			var enter_from: String = cmd.get("enter_from", "")
			await preview_stage.enter_character(character_id, position_name, enter_from)

		"exit":
			var character_id: String = cmd.get("character", "")
			var direction: String = cmd.get("direction", "")
			await preview_stage.exit_character(character_id, direction)

		"move":
			var character_id: String = cmd.get("character", "")
			var position_name: String = cmd.get("position", "center")
			await preview_stage.move_character(character_id, position_name)

		"dialogue":
			_preview_dialogue_command(cmd)
			# Wait briefly to simulate dialogue display, then auto-advance
			await get_tree().create_timer(1.5 / speed_slider.value).timeout

		"shake":
			if preview_stage.camera_effects:
				preview_stage.camera_effects.shake(cmd.get("intensity", 0.5), cmd.get("duration", 0.3))
			await get_tree().create_timer(cmd.get("duration", 0.3)).timeout

		"flash":
			if preview_stage.camera_effects:
				var color_name: String = cmd.get("color", "white")
				var color := _resolve_color(color_name)
				preview_stage.camera_effects.flash(color, cmd.get("duration", 0.3))
			await get_tree().create_timer(cmd.get("duration", 0.3)).timeout

		"wait":
			var duration: float = cmd.get("duration", 1.0)
			await get_tree().create_timer(duration / speed_slider.value).timeout

		"expression":
			preview_stage.set_character_expression(cmd.get("character", ""), cmd.get("expression", ""))

		"look_at":
			preview_stage.set_look_at(cmd.get("character", ""), cmd.get("target", "center"))

		"pose":
			preview_stage.set_body_state(cmd.get("character", ""), cmd.get("state", "idle"))

		"focus":
			var character_id: String = cmd.get("character", "")
			if character_id != "":
				preview_stage.set_focus(character_id)
			else:
				preview_stage.clear_focus()

		"clear_focus":
			preview_stage.clear_focus()

		"close_up":
			preview_stage.camera_close_up(
				cmd.get("character", ""),
				cmd.get("zoom", 1.4),
				cmd.get("duration", 0.5)
			)
			await get_tree().create_timer(cmd.get("duration", 0.5)).timeout

		"pull_back":
			preview_stage.camera_pull_back(
				cmd.get("character", ""),
				cmd.get("zoom", 0.8),
				cmd.get("duration", 0.5)
			)
			await get_tree().create_timer(cmd.get("duration", 0.5)).timeout

		"camera_reset":
			preview_stage.camera_reset(cmd.get("duration", 0.4))
			await get_tree().create_timer(cmd.get("duration", 0.4)).timeout

		"depth":
			preview_stage.set_character_depth(
				cmd.get("character", ""),
				cmd.get("depth", 1.0),
				cmd.get("duration", 0.4)
			)
			await get_tree().create_timer(cmd.get("duration", 0.4)).timeout

		"choose":
			# In preview, just show the choices briefly
			_preview_choices(cmd.get("options", []))
			await get_tree().create_timer(2.0 / speed_slider.value).timeout
			if preview_dialogue and preview_dialogue.has_method("hide_dialogue"):
				preview_dialogue.hide_dialogue()

		"layout":
			# Layout transitions are not fully supported in the isolated preview.
			# Just show a status message.
			_set_status("Layout: %s (solo visual en juego completo)" % cmd.get("mode", "?"))
			await get_tree().create_timer(0.3).timeout

		"if_flag", "else", "end_if", "set_flag", "clear_flag":
			# Conditional flow — skip in preview (execute all branches linearly)
			pass

		"board_enable", "board_disable":
			# Board commands — not relevant in preview
			pass

		"set_style", "set_emotion", "override_next_style":
			# Board-related — not relevant in preview
			pass

		"music":
			_set_status("Musica: %s" % cmd.get("track", "?"))

		"sfx":
			_set_status("SFX: %s" % cmd.get("sound", "?"))

		"stop_music":
			_set_status("Musica detenida")

		_:
			_set_status("Comando no soportado en vista previa: %s" % cmd_type)


func _preview_dialogue_command(cmd: Dictionary) -> void:
	if preview_dialogue == null or not preview_dialogue.has_method("show_dialogue"):
		return

	var character_id: String = cmd.get("character", "")
	var expression: String = cmd.get("expression", "")
	var text: String = cmd.get("text", "")
	var target: String = cmd.get("target", "")

	# Set expression on stage
	if expression != "" and character_id != "player":
		preview_stage.set_character_expression(character_id, expression)
		preview_stage.set_character_speaking(character_id, true)

	# Resolve display name and color
	var display_name := character_id
	var color := Color.WHITE
	var char_data: Resource = null

	for ch in _preview_characters:
		if ch.character_id == character_id:
			display_name = ch.display_name
			color = ch.color
			char_data = ch
			break

	# Build speaker label
	var speaker := display_name
	if target != "":
		var target_name := target
		for ch in _preview_characters:
			if ch.character_id == target:
				target_name = ch.display_name
				break
		speaker = "%s -> %s" % [display_name, target_name]

	preview_dialogue.show_dialogue(speaker, text, color, char_data)


func _preview_choices(options: Array) -> void:
	if preview_dialogue == null:
		return

	# Show a simple dialogue with the choice text
	var choice_text := ""
	for opt in options:
		choice_text += "> %s\n" % opt.get("text", "?")

	preview_dialogue.show_dialogue("Eleccion", choice_text.strip_edges(), Color(0.8, 0.5, 0.8), null)


# ============================================================
# HELPERS
# ============================================================

func _set_status(text: String, is_error: bool = false) -> void:
	if status_label:
		status_label.text = text
		if is_error:
			status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		else:
			status_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.4))


static func _resolve_color(name: String) -> Color:
	match name.to_lower():
		"white": return Color.WHITE
		"black": return Color.BLACK
		"red": return Color.RED
		"blue": return Color.BLUE
		"yellow": return Color.YELLOW
		"green": return Color.GREEN
	if name.begins_with("#"):
		return Color.html(name)
	return Color.WHITE


# ============================================================
# PUBLIC API
# ============================================================

## Load a .dscn file into the editor by path.
func load_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		_set_status("Error: no se pudo abrir %s" % path, true)
		return

	code_edit.text = file.get_as_text()
	file.close()
	_current_file_path = path
	file_name_label.text = path
	_set_status("Archivo cargado: %s" % path.get_file())


## Get the current script text from the editor.
func get_script_text() -> String:
	return code_edit.text


## Get the current file path (empty string if no file is open).
func get_current_path() -> String:
	return _current_file_path
