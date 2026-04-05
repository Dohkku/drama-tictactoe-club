class_name ScriptEditorWindow
extends RefCounted

## Floating Window for editing .dscn scripts with a contextual toolbox.
## Emits `script_saved(path)` so PreviewManager can hot-reload active previews.

signal script_saved(path: String)
signal window_closed(path: String)

const GraphThemeC = preload("res://editor/graph/graph_theme.gd")
const CmdNodeScript = preload("res://editor/graph/cinematic/cinematic_command_node.gd")
const CinematicStageScript = preload("res://systems/cinematic/cinematic_stage.gd")
const CharacterNodeScript = preload("res://editor/graph/nodes/character_node.gd")

var _main: Control  # GraphEditorMain
var _path: String = ""
var _window: Window = null
var _code: TextEdit = null
var _title_label: Label = null
var _dirty: bool = false
var _original_text: String = ""
var _help_label: RichTextLabel = null
var _code_font_size: int = 12
var _help_font_size: int = 11
const MIN_FONT_SIZE: int = 8
const MAX_FONT_SIZE: int = 32


func _init(main: Control, path: String) -> void:
	_main = main
	_path = path


func get_path_ref() -> String:
	return _path


func is_open() -> bool:
	return _window != null and is_instance_valid(_window)


func focus() -> void:
	if is_open():
		_window.grab_focus()


func open() -> void:
	if is_open():
		focus()
		return

	_window = Window.new()
	_window.title = "Editor de script"
	_window.size = Vector2i(1100, 650)
	_window.unresizable = false
	_window.wrap_controls = true
	_window.close_requested.connect(_on_close_requested)
	_window.window_input.connect(_on_window_input)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)

	root.add_child(_build_header())
	root.add_child(_build_body())
	root.add_child(_build_footer())

	_window.add_child(root)

	_main.get_viewport().set_embedding_subwindows(false)
	_main.get_tree().root.add_child(_window)
	_window.popup_centered()
	_window.position += Vector2i(40, 20)

	_load_from_disk()


func _build_header() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.15, 0.19)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	_title_label = Label.new()
	_title_label.text = _path.get_file() if _path != "" else "sin archivo"
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_title_label)

	var save_btn := _make_toolbar_button("Guardar (Ctrl+S)", Color(0.3, 0.7, 0.4))
	save_btn.pressed.connect(save_now)
	hbox.add_child(save_btn)

	panel.add_child(hbox)
	return panel


func _build_body() -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 6)

	# Linux dead-key layouts (accent keys) can freeze/crash CodeEdit in Godot 4.6.x.
	# Use TextEdit there as a stable fallback for the advanced script editor.
	if OS.get_name() == "Linux":
		_code = TextEdit.new()
	else:
		var code_edit := CodeEdit.new()
		code_edit.minimap_draw = true
		code_edit.auto_brace_completion_enabled = true
		_code = code_edit
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.add_theme_font_size_override("font_size", _code_font_size)
	_code.gutters_draw_line_numbers = true
	_code.draw_tabs = true
	_code.text_changed.connect(_on_text_changed)
	hbox.add_child(_code)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(340, 0)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(_build_commands_tab())
	tabs.add_child(_build_resources_tab())
	tabs.add_child(_build_help_tab())
	hbox.add_child(tabs)

	return hbox


func _build_footer() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.14)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var hint := Label.new()
	hint.text = "Ctrl+S guarda (recarga preview automáticamente) · Ctrl+Rueda: zoom"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(hint)

	panel.add_child(hbox)
	return panel


# ── Tab: Comandos ──────────────────────────────────────────────────────

func _build_commands_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Comandos"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	for cat_key in CmdNodeScript.CATEGORIES:
		var cat: Dictionary = CmdNodeScript.CATEGORIES[cat_key]
		vbox.add_child(_make_section_header(cat.label, cat.color))

		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		vbox.add_child(grid)

		for cmd_key in cat.commands:
			var params: Dictionary = cat.commands[cmd_key]
			var template: String = _template_for(cmd_key, params)
			var btn := Button.new()
			btn.text = cmd_key
			btn.add_theme_font_size_override("font_size", 10)
			btn.tooltip_text = template
			var t_ref: String = template
			btn.pressed.connect(func(): _insert_at_caret(t_ref + "\n"))
			grid.add_child(btn)

	return scroll


func _template_for(cmd_key: String, params: Dictionary) -> String:
	# Rebuild the .dscn bracket syntax for a command using its param names as
	# placeholders. Special cases mirror the parser / node renderer.
	match cmd_key:
		"layout_fullscreen": return "[fullscreen]"
		"layout_split": return "[split]"
		"layout_board_only": return "[board_only]"
		"dialogue": return "char: texto"
		"choose": return "[choose]\n> Opcion -> flag\n[end_choose]"
		"if_flag": return "[if flag nombre]"
	var parts: Array[String] = [cmd_key]
	for p_name in params:
		var p_type: String = params[p_name]
		parts.append(_placeholder_for(p_name, p_type))
	return "[" + " ".join(parts) + "]"


func _placeholder_for(p_name: String, p_type: String) -> String:
	if p_type.begins_with("float"):
		var segs: PackedStringArray = p_type.split(":")
		if segs.size() >= 2:
			return segs[1]
		return "0.5"
	if p_type.begins_with("option:"):
		var opts: String = p_type.substr(7)
		return opts.split(",")[0]
	match p_type:
		"position": return "center"
		"direction": return "left"
		"char", "char_opt": return "char"
		"expr": return "neutral"
		"text", "text_short": return p_name.to_upper()
		"flag": return "flag_name"
		"pose_select": return "idle"
		"audio_music": return "bgm_chill.mp3"
		"audio_sfx": return "click.mp3"
	return p_name.to_upper()


# ── Tab: Recursos ──────────────────────────────────────────────────────

func _build_resources_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Recursos"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Personajes
	vbox.add_child(_make_section_header("Personajes", Color(1.0, 0.65, 0.2)))
	var chars := _list_characters()
	if chars.is_empty():
		vbox.add_child(_make_dim_label("(sin personajes en el grafo)"))
	for ch in chars:
		var char_id: String = ch.get("id", "")
		var display: String = ch.get("name", char_id)
		var btn := _make_resource_button("%s  (%s)" % [display, char_id], char_id)
		vbox.add_child(btn)

	# Posiciones
	vbox.add_child(_make_section_header("Posiciones de stage", Color(0.9, 0.45, 0.6)))
	for pos_name in CinematicStageScript.POSITIONS:
		vbox.add_child(_make_resource_button(pos_name, pos_name))

	# Music
	vbox.add_child(_make_section_header("Musica (res://audio/music)", Color(0.2, 0.7, 0.65)))
	for track in _list_audio_dir("res://audio/music"):
		vbox.add_child(_make_resource_button(track, "[music %s]" % track))

	# SFX
	vbox.add_child(_make_section_header("SFX (res://audio/sfx)", Color(0.2, 0.7, 0.65)))
	for snd in _list_audio_dir("res://audio/sfx"):
		vbox.add_child(_make_resource_button(snd, "[sfx %s]" % snd))

	# Backgrounds
	vbox.add_child(_make_section_header("Fondos (res://assets/backgrounds)", Color(0.85, 0.75, 0.2)))
	for bg in _list_files("res://assets/backgrounds", ["png", "jpg", "jpeg", "webp"]):
		var full: String = "res://assets/backgrounds/%s" % bg
		vbox.add_child(_make_resource_button(bg, "[background %s]" % full))

	return scroll


func _list_characters() -> Array:
	var out: Array = []
	if _main == null or _main.graph_edit == null:
		return out
	for child in _main.graph_edit.get_children():
		if child is CharacterNodeScript and child.character_data:
			var cd: Resource = child.character_data
			out.append({
				"id": cd.character_id,
				"name": cd.display_name if cd.display_name != "" else cd.character_id,
			})
	return out


func _list_audio_dir(dir_path: String) -> Array[String]:
	return _list_files(dir_path, ["mp3", "wav", "ogg"])


func _list_files(dir_path: String, extensions: Array) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and not fname.ends_with(".import") and not fname.begins_with("."):
			var ext: String = fname.get_extension().to_lower()
			if extensions.has(ext):
				result.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


# ── Tab: Ayuda ──────────────────────────────────────────────────────────

func _build_help_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Ayuda"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_help_label = RichTextLabel.new()
	_help_label.bbcode_enabled = true
	_help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_help_label.fit_content = true
	_apply_help_font_size()

	_help_label.text = _help_bbcode()
	scroll.add_child(_help_label)
	return scroll


func _help_bbcode() -> String:
	return "[b]Estructura[/b]\n" + \
		"[code]@scene nombre[/code]   — escena (cutscene)\n" + \
		"[code]@reactions nombre[/code]   — reacciones\n" + \
		"[code]@on evento[/code] ... [code]@end[/code]   — bloque de reaccion\n\n" + \
		"[b]Dialogo[/b]\n" + \
		"[code]char \"expr\": texto[/code]\n" + \
		"[code]char \"expr\" -> otro: texto dirigido[/code]\n\n" + \
		"[b]Flow[/b]\n" + \
		"[code][if flag nombre][/code] ... [code][else][/code] ... [code][end_if][/code]\n" + \
		"[code][set_flag X][/code]  [code][clear_flag X][/code]\n\n" + \
		"[b]Board[/b]\n" + \
		"[code][board_enable][/code] [code][board_disable][/code]\n" + \
		"[code][set_difficulty 1.0][/code]  — dificultad IA en vivo\n" + \
		"[code][board_cheat opponent_wins][/code]\n\n" + \
		"[b]Ver DSL Reference.md[/b] para lista completa."


# ── Helpers ────────────────────────────────────────────────────────────

func _make_toolbar_button(text: String, color: Color) -> Button:
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


func _make_section_header(text: String, color: Color) -> Control:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_dim_label(text: String) -> Control:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	return lbl


func _make_resource_button(label: String, insert_text: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 10)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	var t_ref: String = insert_text
	btn.pressed.connect(func(): _insert_at_caret(t_ref))
	return btn


func _insert_at_caret(text: String) -> void:
	if _code == null:
		return
	_code.insert_text_at_caret(text)
	_code.grab_focus()


# ── Load / Save / Dirty ────────────────────────────────────────────────

func _load_from_disk() -> void:
	if _path == "" or not FileAccess.file_exists(_path):
		if _code:
			_code.text = ""
		_original_text = ""
		_dirty = false
		_refresh_title()
		return
	var text: String = FileAccess.get_file_as_string(_path)
	_original_text = text
	if _code:
		_code.text = text
	_dirty = false
	_refresh_title()


func save_now() -> void:
	if _path == "":
		return
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		push_error("ScriptEditorWindow: cannot write %s" % _path)
		return
	f.store_string(_code.text)
	f.close()
	_original_text = _code.text
	_dirty = false
	_refresh_title()
	script_saved.emit(_path)


func _on_text_changed() -> void:
	var new_dirty: bool = _code.text != _original_text
	if new_dirty != _dirty:
		_dirty = new_dirty
		_refresh_title()


func _refresh_title() -> void:
	if _title_label == null:
		return
	var marker: String = "*" if _dirty else ""
	var fname: String = _path.get_file() if _path != "" else "sin archivo"
	_title_label.text = "%s%s" % [fname, marker]
	if is_open():
		_window.title = "Editor — %s%s" % [fname, marker]


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S and event.ctrl_pressed:
			save_now()
			_window.set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_bump_fonts(1)
			_window.set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_bump_fonts(-1)
			_window.set_input_as_handled()


func _bump_fonts(delta: int) -> void:
	_code_font_size = clampi(_code_font_size + delta, MIN_FONT_SIZE, MAX_FONT_SIZE)
	_help_font_size = clampi(_help_font_size + delta, MIN_FONT_SIZE, MAX_FONT_SIZE)
	if _code:
		_code.add_theme_font_size_override("font_size", _code_font_size)
	_apply_help_font_size()


func _apply_help_font_size() -> void:
	if _help_label == null:
		return
	_help_label.add_theme_font_size_override("normal_font_size", _help_font_size)
	_help_label.add_theme_font_size_override("bold_font_size", _help_font_size)
	_help_label.add_theme_font_size_override("mono_font_size", _help_font_size)
	_help_label.add_theme_font_size_override("italics_font_size", _help_font_size)


func _on_close_requested() -> void:
	close()


func close() -> void:
	var path_emit: String = _path
	if _window and is_instance_valid(_window):
		_window.queue_free()
	_window = null
	if _main and is_instance_valid(_main):
		_main.get_viewport().set_embedding_subwindows(true)
	window_closed.emit(path_emit)
