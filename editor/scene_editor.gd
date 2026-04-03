extends HSplitContainer

## Scene Script Editor — visual editor for .dscn cutscene/reaction scripts.
## Left: file list + CodeEdit + command palette.
## Right: live preview with SubViewport + CinematicStage + playback controls.

const CinematicStageScene = preload("res://systems/cinematic/cinematic_stage.tscn")
const CharacterDataScript = preload("res://characters/character_data.gd")
const SceneParserScript = preload("res://scene_scripts/parser/scene_parser.gd")
const SCRIPTS_DIR := "res://scene_scripts/scripts/"

# --- UI nodes (built in _ready) ---
var code_edit: CodeEdit
var file_name_label: Label
var file_list: ItemList
var preview_viewport: SubViewport
var preview_stage: Control
var speed_slider: HSlider
var status_label: Label
var play_button: Button
var step_button: Button
var stop_button: Button

# --- File state ---
var _current_file_path: String = ""
var _available_files: Array[String] = []

# --- Playback ---
var _parsed_data: Dictionary = {}
var _runner: RefCounted = null
var _playing: bool = false
var _paused: bool = false
var _command_index: int = 0
var _preview_characters: Array = []


func _ready() -> void:
	split_offset = 800
	_build_ui()
	_scan_script_files()
	_setup_default_preview_characters()
	# Load first script automatically if available
	if not _available_files.is_empty():
		_load_file(_available_files[0])


# ============================================================
# UI CONSTRUCTION
# ============================================================

func _build_ui() -> void:
	# --- LEFT PANEL ---
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(left_panel)

	# Top bar: file operations
	var file_bar = HBoxContainer.new()
	file_bar.add_theme_constant_override("separation", 6)
	left_panel.add_child(file_bar)

	var new_btn = _make_btn("Nuevo", Color(0.4, 0.7, 0.4))
	new_btn.pressed.connect(_on_new_pressed)
	file_bar.add_child(new_btn)

	var save_btn = _make_btn("Guardar", Color(0.4, 0.6, 0.9))
	save_btn.pressed.connect(_on_save_pressed)
	file_bar.add_child(save_btn)

	file_name_label = Label.new()
	file_name_label.text = "(sin archivo)"
	file_name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	file_name_label.add_theme_font_size_override("font_size", 12)
	file_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	file_name_label.clip_text = true
	file_bar.add_child(file_name_label)

	# File list (scripts found in project)
	var list_label = Label.new()
	list_label.text = "Scripts del proyecto:"
	list_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	list_label.add_theme_font_size_override("font_size", 12)
	left_panel.add_child(list_label)

	file_list = ItemList.new()
	file_list.custom_minimum_size = Vector2(0, 110)
	file_list.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	file_list.add_theme_font_size_override("font_size", 13)
	file_list.item_selected.connect(_on_file_selected)
	left_panel.add_child(file_list)

	# CodeEdit
	code_edit = CodeEdit.new()
	code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_edit.add_theme_font_size_override("font_size", 14)
	code_edit.add_theme_color_override("background_color", Color(0.09, 0.1, 0.13))
	code_edit.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
	code_edit.gutters_draw_line_numbers = true
	code_edit.indent_automatic = true
	code_edit.indent_size = 1
	left_panel.add_child(code_edit)
	_setup_highlighting()

	# Command palette
	var palette_label = Label.new()
	palette_label.text = "Insertar:"
	palette_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	palette_label.add_theme_font_size_override("font_size", 11)
	left_panel.add_child(palette_label)

	var palette_scroll = ScrollContainer.new()
	palette_scroll.custom_minimum_size = Vector2(0, 36)
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	palette_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(palette_scroll)

	var palette = HBoxContainer.new()
	palette.add_theme_constant_override("separation", 4)
	palette_scroll.add_child(palette)

	var commands = [
		["Diálogo", "akira \"neutral\": texto aquí"],
		["Entrar", "[enter akira center]"],
		["Salir", "[exit akira]"],
		["Mover", "[move akira center]"],
		["Esperar", "[wait 1.0]"],
		["Shake", "[shake 0.5 0.3]"],
		["Flash", "[flash white 0.3]"],
		["Fullscreen", "[fullscreen]"],
		["Split", "[split]"],
		["Close-up", "[close_up akira 1.4 0.5]"],
		["Pose", "[pose akira idle]"],
		["Mirada", "[look_at akira player]"],
		["Elegir", "[choose]\n> opción -> flag\n[end_choose]"],
		["Si/Flag", "[if flag nombre]\n[else]\n[end_if]"],
		["Set Flag", "[set_flag nombre]"],
		["Emoción", "[set_emotion player neutral]"],
		["Efecto", "akira: texto con {shake}énfasis{/shake}"],
		["Trigger", "akira: texto {trigger:ai_move}aquí"],
	]
	for cmd in commands:
		var btn = Button.new()
		btn.text = cmd[0]
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		var insert_text: String = cmd[1]
		btn.pressed.connect(_insert_at_cursor.bind(insert_text))
		_style_palette_button(btn)
		palette.add_child(btn)

	# --- RIGHT PANEL ---
	var right_panel = VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(350, 0)
	add_child(right_panel)

	var preview_label = Label.new()
	preview_label.text = "Vista Previa"
	preview_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	preview_label.add_theme_font_size_override("font_size", 13)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_panel.add_child(preview_label)

	var preview_container = PanelContainer.new()
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.06, 0.06, 0.1)
	preview_style.border_color = Color(0.2, 0.2, 0.3)
	preview_style.set_border_width_all(1)
	preview_container.add_theme_stylebox_override("panel", preview_style)
	right_panel.add_child(preview_container)

	var viewport_container = SubViewportContainer.new()
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	preview_container.add_child(viewport_container)

	preview_viewport = SubViewport.new()
	preview_viewport.transparent_bg = true
	preview_viewport.handle_input_locally = false
	viewport_container.add_child(preview_viewport)

	# Instance CinematicStage inside SubViewport
	preview_stage = CinematicStageScene.instantiate()
	preview_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_viewport.add_child(preview_stage)

	# Playback controls
	var controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	right_panel.add_child(controls)

	play_button = _make_btn("▶ Reproducir", Color(0.3, 0.8, 0.4))
	play_button.pressed.connect(_on_play_pressed)
	controls.add_child(play_button)

	step_button = _make_btn("⏭ Paso", Color(0.6, 0.6, 0.9))
	step_button.pressed.connect(_on_step_pressed)
	controls.add_child(step_button)

	stop_button = _make_btn("⏹ Detener", Color(0.9, 0.4, 0.4))
	stop_button.pressed.connect(_on_stop_pressed)
	controls.add_child(stop_button)

	var speed_label = Label.new()
	speed_label.text = "Vel:"
	speed_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	speed_label.add_theme_font_size_override("font_size", 12)
	controls.add_child(speed_label)

	speed_slider = HSlider.new()
	speed_slider.min_value = 0.5
	speed_slider.max_value = 3.0
	speed_slider.value = 1.0
	speed_slider.step = 0.25
	speed_slider.custom_minimum_size = Vector2(80, 0)
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(speed_slider)

	status_label = Label.new()
	status_label.text = "Listo"
	status_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.clip_text = true
	right_panel.add_child(status_label)


func _setup_highlighting() -> void:
	var h = CodeHighlighter.new()
	h.add_color_region("#", "", Color(0.45, 0.47, 0.52), true)
	h.add_color_region("[", "]", Color(0.3, 0.82, 0.82))
	h.add_color_region("\"", "\"", Color(0.42, 0.82, 0.42))
	h.add_color_region("{", "}", Color(0.95, 0.82, 0.3))
	for kw in ["@scene", "@reactions", "@on", "@end_on", "@end", "@background"]:
		h.keyword_colors[kw] = Color(0.65, 0.42, 0.95)
	for ch_name in ["akira", "mei", "player", "hiro", "yuki", "sensei"]:
		h.keyword_colors[ch_name] = Color(0.95, 0.65, 0.3)
	code_edit.syntax_highlighter = h


func _make_btn(text: String, color: Color = Color(0.7, 0.7, 0.8)) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", color)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.16, 0.22)
	style.border_color = Color(0.3, 0.3, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	return btn


func _style_palette_button(btn: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.19)
	style.border_color = Color(0.25, 0.25, 0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)


# ============================================================
# FILE MANAGEMENT
# ============================================================

func _scan_script_files() -> void:
	_available_files.clear()
	file_list.clear()
	var dir = DirAccess.open(SCRIPTS_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".dscn"):
			_available_files.append(SCRIPTS_DIR + fname)
			file_list.add_item(fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _on_file_selected(index: int) -> void:
	if index < 0 or index >= _available_files.size():
		return
	_load_file(_available_files[index])


func _load_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		_set_status("Error: no se pudo abrir %s" % path)
		return
	code_edit.text = file.get_as_text()
	file.close()
	_current_file_path = path
	file_name_label.text = path.get_file()
	_set_status("Cargado: %s" % path.get_file())
	# Highlight the selected file in the list
	var idx = _available_files.find(path)
	if idx >= 0:
		file_list.select(idx)


func _on_new_pressed() -> void:
	code_edit.text = "# Nuevo script\n@scene mi_escena\n\n\n@end\n"
	_current_file_path = ""
	file_name_label.text = "(sin archivo)"
	_set_status("Nuevo archivo")


func _on_save_pressed() -> void:
	if _current_file_path == "":
		_set_status("Asigna un nombre de archivo primero")
		return
	var normalized_path := _normalize_script_path(_current_file_path)
	if normalized_path == "":
		_set_status("Ruta invalida para guardar")
		return
	var file = FileAccess.open(normalized_path, FileAccess.WRITE)
	if not file:
		_set_status("Error al guardar")
		return
	file.store_string(code_edit.text)
	file.close()
	_current_file_path = normalized_path
	file_name_label.text = normalized_path.get_file()
	_set_status("Guardado: %s" % normalized_path.get_file())


# ============================================================
# PREVIEW & PLAYBACK
# ============================================================

func _setup_default_preview_characters() -> void:
	var defaults = [
		{"id": "akira", "name": "Akira", "color": Color(0.95, 0.3, 0.3),
		 "bg": Color(0.15, 0.08, 0.08, 0.9), "border": Color(0.8, 0.3, 0.3)},
		{"id": "mei",   "name": "Mei",   "color": Color(0.3, 0.7, 0.95),
		 "bg": Color(0.08, 0.1, 0.18, 0.9), "border": Color(0.3, 0.5, 0.9)},
		{"id": "player","name": "Tú",    "color": Color(0.8, 0.8, 0.9),
		 "bg": Color(0.1, 0.1, 0.15, 0.9), "border": Color(0.5, 0.5, 0.6)},
	]
	for def in defaults:
		var data = CharacterDataScript.new()
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
			"neutral": def.color, "confident": def.color.lightened(0.2),
			"nervous": def.color.darkened(0.2), "surprised": Color(0.9, 0.8, 0.3),
			"angry": Color(0.9, 0.2, 0.2), "happy": Color(0.3, 0.9, 0.4),
		}
		_preview_characters.append(data)
		# Register once stage is ready
		call_deferred("_register_preview_character", data)


func _register_preview_character(data: Resource) -> void:
	if is_instance_valid(preview_stage):
		preview_stage.register_character(data)


func _on_play_pressed() -> void:
	_stop_playback()
	var text = code_edit.text
	if text.strip_edges() == "":
		_set_status("El script está vacío")
		return
	_parsed_data = SceneParserScript.parse(text)
	_command_index = 0
	_playing = true
	play_button.disabled = true
	_set_status("Reproduciendo...")
	_clear_stage()
	_play_all()


func _on_step_pressed() -> void:
	if not _playing:
		# Start parse if not started
		var text = code_edit.text
		_parsed_data = SceneParserScript.parse(text)
		_command_index = 0
		_playing = true
		_paused = true
		_clear_stage()
	_step_one()


func _on_stop_pressed() -> void:
	_stop_playback()
	_clear_stage()
	_set_status("Detenido")


func _stop_playback() -> void:
	_playing = false
	_paused = false
	_command_index = 0
	play_button.disabled = false


func _clear_stage() -> void:
	if is_instance_valid(preview_stage):
		preview_stage.clear_stage()


func _play_all() -> void:
	if not _playing:
		return
	var cmds: Array = []
	if _parsed_data.get("type") == "reactions":
		# For reactions scripts, play all reactions sequentially
		for key in _parsed_data.reactions:
			for c in _parsed_data.reactions[key]:
				cmds.append(c)
	else:
		cmds = _parsed_data.get("commands", [])

	_exec_commands(cmds)


func _step_one() -> void:
	var cmds: Array = []
	if _parsed_data.get("type") == "reactions":
		var event_names: Array = _parsed_data.reactions.keys()
		if event_names.is_empty():
			_set_status("Sin reacciones")
			return
		if _command_index >= event_names.size():
			_set_status("Fin de reacciones")
			_stop_playback()
			return
		var event_name: String = event_names[_command_index]
		cmds = _parsed_data.reactions[event_name]
		_set_status("Reacción: '%s' (%d/%d)" % [event_name, _command_index + 1, event_names.size()])
		_command_index += 1
	else:
		cmds = _parsed_data.get("commands", [])
		if _command_index >= cmds.size():
			_set_status("Fin del script")
			_stop_playback()
			return
		var cmd = cmds[_command_index]
		cmds = [cmd]
		_set_status("Paso %d/%d: %s" % [_command_index + 1, cmds.size(), cmd.get("type", "?")])
		_command_index += 1

	_exec_commands(cmds)


func _exec_commands(cmds: Array) -> void:
	var spd = speed_slider.value if is_instance_valid(speed_slider) else 1.0
	_exec_next(cmds, 0, spd)


func _exec_next(cmds: Array, idx: int, spd: float) -> void:
	if not _playing or idx >= cmds.size():
		if _playing and not _paused:
			_stop_playback()
			_set_status("Reproducción completa")
		return
	var cmd = cmds[idx]
	var wait_time := 0.0

	match cmd.get("type", ""):
		"enter":
			if is_instance_valid(preview_stage):
				preview_stage.enter_character(cmd.character, cmd.get("position", "center"), "")
			wait_time = 0.3 / spd
		"exit":
			if is_instance_valid(preview_stage):
				preview_stage.exit_character(cmd.character, cmd.get("direction", ""))
			wait_time = 0.3 / spd
		"dialogue":
			_set_status("%s: %s" % [cmd.character, cmd.get("text", "")])
			wait_time = max(0.5, cmd.get("text", "").length() * 0.04) / spd
		"wait":
			wait_time = cmd.get("duration", 1.0) / spd
		"pose":
			if is_instance_valid(preview_stage):
				preview_stage.set_body_state(cmd.character, cmd.state)
		"expression":
			if is_instance_valid(preview_stage):
				preview_stage.set_character_expression(cmd.character, cmd.expression)
		"look_at":
			if is_instance_valid(preview_stage):
				preview_stage.set_look_at(cmd.character, cmd.target)
		"shake":
			if is_instance_valid(preview_stage):
				preview_stage.camera_effects.shake(cmd.intensity, cmd.get("duration", 0.3))
		"close_up":
			if is_instance_valid(preview_stage):
				preview_stage.camera_close_up(cmd.character, cmd.get("zoom", 1.4), cmd.get("duration", 0.5))
			wait_time = cmd.get("duration", 0.5) / spd
		"camera_reset":
			if is_instance_valid(preview_stage):
				preview_stage.camera_reset(cmd.get("duration", 0.4))
			wait_time = cmd.get("duration", 0.4) / spd
		_:
			pass  # board/layout commands skipped in preview

	if wait_time > 0:
		get_tree().create_timer(wait_time).timeout.connect(
			func(): _exec_next(cmds, idx + 1, spd), CONNECT_ONE_SHOT)
	else:
		_exec_next(cmds, idx + 1, spd)


# ============================================================
# HELPERS
# ============================================================

func _insert_at_cursor(text: String) -> void:
	code_edit.insert_text_at_caret(text)
	code_edit.grab_focus()


func _set_status(msg: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = msg


## Called by the editor shell to pass current project's characters for preview
func set_preview_characters(chars: Array) -> void:
	_preview_characters.clear()
	_clear_stage()
	for ch in chars:
		_preview_characters.append(ch)
		_register_preview_character(ch)


func get_script_text() -> String:
	return code_edit.text if is_instance_valid(code_edit) else ""


func get_current_path() -> String:
	return _current_file_path


func _normalize_script_path(path: String) -> String:
	var p = path.strip_edges()
	if p == "":
		return ""
	# Normalize windows-style separators when users paste paths.
	p = p.replace("\\", "/")
	if p.begins_with("res://"):
		return p
	if p.begins_with("user://"):
		return p
	if p.begins_with("/"):
		return p
	return SCRIPTS_DIR + p
