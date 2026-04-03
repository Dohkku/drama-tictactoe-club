extends Control

## Interactive sandbox for the Cinematic system.
## Tests: characters, camera, expressions, poses, dialogue, effects, backgrounds.

const CinematicStageScene = preload("res://systems/cinematic/cinematic_stage.tscn")
const DialogueBoxScene = preload("res://systems/cinematic/dialogue_box.tscn")
const DialogueAudioScript = preload("res://systems/cinematic/dialogue_audio.gd")
const CharacterDataScript = preload("res://characters/character_data.gd")

var stage: Control  # CinematicStage
var dialogue_box: Control
var dialogue_audio: Node

# Character data loaded from project
var _characters: Array[Resource] = []
var _character_ids: PackedStringArray = PackedStringArray()
var _on_stage: PackedStringArray = PackedStringArray()

# UI references
var char_option: OptionButton
var position_option: OptionButton
var expression_option: OptionButton
var pose_option: OptionButton
var look_option: OptionButton
var enter_dir_option: OptionButton
var camera_mode_option: OptionButton
var on_stage_label: Label
var dialogue_edit: TextEdit
var bg_color_picker: ColorPickerButton
var log_label: RichTextLabel
var log_lines: Array[String] = []

const POSITIONS := ["far_left", "left", "center_left", "center", "center_right", "right", "far_right"]
const POSITION_LABELS := ["Lejos izq.", "Izquierda", "Centro izq.", "Centro", "Centro der.", "Derecha", "Lejos der."]
const POSES := ["idle", "thinking", "arms_crossed", "leaning_forward", "leaning_back", "excited", "tense", "confident", "defeated"]
const LOOKS := ["left", "right", "center", "away"]
const EXPRESSIONS := ["neutral", "happy", "angry", "sad", "nervous", "serious", "surprised", "focused", "thinking", "cold", "intense"]


func _ready() -> void:
	_load_characters()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://systems/dev_menu.tscn")


func _load_characters() -> void:
	var dir := "res://characters/data/"
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	for f in files:
		if f.ends_with(".tres"):
			var res: Resource = load(dir + f)
			if res and res.get("character_id") != null:
				_characters.append(res)
				_character_ids.append(res.character_id)
	if _characters.is_empty():
		# Fallback: create a test character
		var test: Resource = CharacterDataScript.new()
		test.character_id = "test"
		test.display_name = "Test"
		test.color = Color(0.4, 0.7, 1.0)
		test.voice_pitch = 260.0
		test.voice_waveform = "sine"
		_characters.append(test)
		_character_ids.append("test")


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# ── LEFT: Controls ──
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 0.25
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 5)
	left_scroll.add_child(left)

	var back := Button.new()
	back.text = "< Dev Menu (Esc)"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://systems/dev_menu.tscn"))
	left.add_child(back)

	_lbl(left, "CINEMATIC STAGE", 16, Color(0.6, 0.3, 0.9))
	left.add_child(HSeparator.new())

	# Character selection
	_lbl(left, "Personaje", 13, Color(0.6, 0.6, 0.75))
	char_option = OptionButton.new()
	for c in _characters:
		char_option.add_item("%s (%s)" % [c.display_name, c.character_id])
	char_option.select(0)
	left.add_child(char_option)

	# Position
	_lbl(left, "Posición", 13, Color(0.6, 0.6, 0.75))
	position_option = OptionButton.new()
	for p in POSITION_LABELS:
		position_option.add_item(p)
	position_option.select(3)  # Center
	left.add_child(position_option)

	# Enter direction
	_lbl(left, "Dirección entrada/salida", 11, Color(0.55, 0.55, 0.65))
	enter_dir_option = OptionButton.new()
	enter_dir_option.add_item("Automática")
	enter_dir_option.add_item("Desde izquierda")
	enter_dir_option.add_item("Desde derecha")
	enter_dir_option.select(0)
	left.add_child(enter_dir_option)

	# Enter / Exit / Move
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	left.add_child(btn_row)

	var enter_btn := Button.new()
	enter_btn.text = "Entrar"
	enter_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enter_btn.pressed.connect(_on_enter)
	_style_btn(enter_btn, Color(0.2, 0.5, 0.3))
	btn_row.add_child(enter_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Salir"
	exit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_btn.pressed.connect(_on_exit)
	_style_btn(exit_btn, Color(0.5, 0.2, 0.2))
	btn_row.add_child(exit_btn)

	var move_btn := Button.new()
	move_btn.text = "Mover"
	move_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_btn.pressed.connect(_on_move)
	_style_btn(move_btn, Color(0.3, 0.4, 0.5))
	btn_row.add_child(move_btn)

	# On-stage indicator
	on_stage_label = Label.new()
	on_stage_label.add_theme_font_size_override("font_size", 11)
	on_stage_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	on_stage_label.text = "En escena: —"
	left.add_child(on_stage_label)

	left.add_child(HSeparator.new())

	# Expression
	_lbl(left, "Expresión", 13, Color(0.6, 0.6, 0.75))
	expression_option = OptionButton.new()
	for e in EXPRESSIONS:
		expression_option.add_item(e)
	expression_option.item_selected.connect(func(_i: int): _on_expression())
	left.add_child(expression_option)

	# Pose
	_lbl(left, "Pose", 13, Color(0.6, 0.6, 0.75))
	pose_option = OptionButton.new()
	for p in POSES:
		pose_option.add_item(p)
	pose_option.item_selected.connect(func(_i: int): _on_pose())
	left.add_child(pose_option)

	# Look direction
	_lbl(left, "Mirada", 13, Color(0.6, 0.6, 0.75))
	look_option = OptionButton.new()
	for l in LOOKS:
		look_option.add_item(l)
	look_option.select(2)  # center
	look_option.item_selected.connect(func(_i: int): _on_look())
	left.add_child(look_option)

	var focus_btn := Button.new()
	focus_btn.text = "Focus"
	focus_btn.pressed.connect(_on_focus)
	_style_btn(focus_btn, Color(0.4, 0.3, 0.5))
	left.add_child(focus_btn)

	var clear_focus_btn := Button.new()
	clear_focus_btn.text = "Clear Focus"
	clear_focus_btn.pressed.connect(func(): stage.clear_focus(); _log("Focus cleared"))
	_style_btn(clear_focus_btn, Color(0.3, 0.3, 0.4))
	left.add_child(clear_focus_btn)

	left.add_child(HSeparator.new())

	# Camera
	_lbl(left, "Cámara", 13, Color(0.6, 0.6, 0.75))
	camera_mode_option = OptionButton.new()
	camera_mode_option.add_item("smooth")
	camera_mode_option.add_item("snappy")
	camera_mode_option.item_selected.connect(func(idx: int): stage.set_camera_mode("snappy" if idx == 1 else "smooth"))
	left.add_child(camera_mode_option)

	var close_up_btn := Button.new()
	close_up_btn.text = "Close-Up"
	close_up_btn.pressed.connect(_on_close_up)
	_style_btn(close_up_btn, Color(0.3, 0.3, 0.5))
	left.add_child(close_up_btn)

	var pull_back_btn := Button.new()
	pull_back_btn.text = "Pull Back"
	pull_back_btn.pressed.connect(_on_pull_back)
	_style_btn(pull_back_btn, Color(0.3, 0.3, 0.5))
	left.add_child(pull_back_btn)

	var snap_btn := Button.new()
	snap_btn.text = "Camera Snap"
	snap_btn.pressed.connect(_on_camera_snap)
	_style_btn(snap_btn, Color(0.5, 0.3, 0.3))
	left.add_child(snap_btn)

	var reset_cam_btn := Button.new()
	reset_cam_btn.text = "Camera Reset"
	reset_cam_btn.pressed.connect(func(): stage.camera_reset(); _log("Camera reset"))
	_style_btn(reset_cam_btn, Color(0.3, 0.3, 0.4))
	left.add_child(reset_cam_btn)

	left.add_child(HSeparator.new())

	# Effects
	_lbl(left, "Efectos", 13, Color(0.6, 0.6, 0.75))
	var shake_btn := Button.new()
	shake_btn.text = "Shake"
	shake_btn.pressed.connect(func(): stage.camera_effects.shake(0.5, 0.3); _log("Shake"))
	_style_btn(shake_btn, Color(0.5, 0.4, 0.2))
	left.add_child(shake_btn)

	var flash_btn := Button.new()
	flash_btn.text = "Flash"
	flash_btn.pressed.connect(func(): stage.camera_effects.flash(Color.WHITE, 0.2); _log("Flash"))
	_style_btn(flash_btn, Color(0.5, 0.5, 0.3))
	left.add_child(flash_btn)

	left.add_child(HSeparator.new())
	_lbl(left, "Transiciones", 13, Color(0.6, 0.6, 0.75))

	_lbl(left, "Fade", 11, Color(0.55, 0.55, 0.65))
	var fade_row := HBoxContainer.new()
	fade_row.add_theme_constant_override("separation", 4)
	left.add_child(fade_row)
	var ftb := Button.new()
	ftb.text = "To Black"
	ftb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ftb.pressed.connect(func(): stage.camera_effects.fade_to_black(0.3); _log("Fade to black"))
	_style_btn(ftb, Color(0.15, 0.15, 0.2))
	fade_row.add_child(ftb)
	var ffb := Button.new()
	ffb.text = "From Black"
	ffb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ffb.pressed.connect(func(): stage.camera_effects.fade_from_black(0.3); _log("Fade from black"))
	_style_btn(ffb, Color(0.25, 0.25, 0.3))
	fade_row.add_child(ffb)

	var fade_row2 := HBoxContainer.new()
	fade_row2.add_theme_constant_override("separation", 4)
	left.add_child(fade_row2)
	var ftw := Button.new()
	ftw.text = "To White"
	ftw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ftw.pressed.connect(func(): stage.camera_effects.fade_to_white(0.2); _log("Fade to white"))
	_style_btn(ftw, Color(0.4, 0.4, 0.45))
	fade_row2.add_child(ftw)
	var ffw := Button.new()
	ffw.text = "From White"
	ffw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ffw.pressed.connect(func(): stage.camera_effects.fade_from_white(0.3); _log("Fade from white"))
	_style_btn(ffw, Color(0.45, 0.45, 0.5))
	fade_row2.add_child(ffw)

	_lbl(left, "Speed lines", 11, Color(0.55, 0.55, 0.65))
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 4)
	left.add_child(speed_row)
	for dir in ["left", "right", "radial"]:
		var sb := Button.new()
		sb.text = dir
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var d: String = dir
		sb.pressed.connect(func(): stage.camera_effects.speed_lines(d, 0.3); _log("Speed: %s" % d))
		_style_btn(sb, Color(0.4, 0.35, 0.2))
		speed_row.add_child(sb)

	_lbl(left, "Telón cerrar", 11, Color(0.55, 0.55, 0.65))
	var wipe_in_row := HBoxContainer.new()
	wipe_in_row.add_theme_constant_override("separation", 4)
	left.add_child(wipe_in_row)
	for dir in ["left", "right", "down", "up"]:
		var wb := Button.new()
		wb.text = dir
		wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var d: String = dir
		wb.pressed.connect(func(): stage.camera_effects.wipe(d, 0.3); _log("Telón cerrar: %s" % d))
		_style_btn(wb, Color(0.3, 0.3, 0.45))
		wipe_in_row.add_child(wb)

	_lbl(left, "Telón abrir", 11, Color(0.55, 0.55, 0.65))
	var wipe_out_row := HBoxContainer.new()
	wipe_out_row.add_theme_constant_override("separation", 4)
	left.add_child(wipe_out_row)
	for dir in ["left", "right", "down", "up"]:
		var wb := Button.new()
		wb.text = dir
		wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var d: String = dir
		wb.pressed.connect(func(): stage.camera_effects.wipe_out(d, 0.3); _log("Telón abrir: %s" % d))
		_style_btn(wb, Color(0.35, 0.35, 0.5))
		wipe_out_row.add_child(wb)

	left.add_child(HSeparator.new())

	# Background
	_lbl(left, "Fondo", 13, Color(0.6, 0.6, 0.75))
	bg_color_picker = ColorPickerButton.new()
	bg_color_picker.color = Color(0.1, 0.1, 0.15)
	bg_color_picker.custom_minimum_size = Vector2(0, 28)
	bg_color_picker.color_changed.connect(func(c: Color): stage.set_background(c); _log("BG: %s" % c))
	left.add_child(bg_color_picker)

	left.add_child(HSeparator.new())

	# Dialogue
	_lbl(left, "Diálogo", 13, Color(0.6, 0.6, 0.75))
	dialogue_edit = TextEdit.new()
	dialogue_edit.custom_minimum_size = Vector2(0, 60)
	dialogue_edit.placeholder_text = "Texto del diálogo..."
	dialogue_edit.add_theme_font_size_override("font_size", 12)
	left.add_child(dialogue_edit)

	var say_btn := Button.new()
	say_btn.text = "Hablar"
	say_btn.pressed.connect(_on_say)
	_style_btn(say_btn, Color(0.3, 0.4, 0.5))
	left.add_child(say_btn)

	left.add_child(HSeparator.new())

	# Title Card
	var title_btn := Button.new()
	title_btn.text = "Title Card"
	title_btn.pressed.connect(func(): stage.show_title_card("Capítulo 1", "El comienzo", 2.0); _log("Title card"))
	_style_btn(title_btn, Color(0.4, 0.3, 0.5))
	left.add_child(title_btn)

	left.add_child(HSeparator.new())
	_lbl(left, "Debug", 13, Color(0.6, 0.6, 0.75))
	var markers_check := CheckBox.new()
	markers_check.text = "Mostrar posiciones"
	markers_check.button_pressed = true
	markers_check.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	markers_check.toggled.connect(func(on: bool): stage.set_show_markers(on))
	left.add_child(markers_check)

	var clear_btn := Button.new()
	clear_btn.text = "LIMPIAR ESCENA"
	clear_btn.pressed.connect(_on_clear)
	_style_btn(clear_btn, Color(0.5, 0.15, 0.15))
	left.add_child(clear_btn)

	# ── CENTER: Stage ──
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 0.55
	root.add_child(center)

	_lbl(center, "Escenario", 14, Color(0.7, 0.7, 0.8))

	# Instantiate the cinematic stage inside a SubViewportContainer for isolation
	var stage_container := PanelContainer.new()
	stage_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stage_style := StyleBoxFlat.new()
	stage_style.bg_color = Color(0.1, 0.1, 0.15)
	stage_style.set_corner_radius_all(4)
	stage_container.add_theme_stylebox_override("panel", stage_style)
	center.add_child(stage_container)

	stage = CinematicStageScene.instantiate()
	# Override FULL_RECT anchors to work inside PanelContainer
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_container.add_child(stage)

	# Register characters
	for c in _characters:
		stage.register_character(c)

	# Show position markers by default
	stage.set_show_markers(true)

	# Dialogue box below the stage
	dialogue_box = DialogueBoxScene.instantiate()
	dialogue_box.custom_minimum_size = Vector2(0, 80)
	center.add_child(dialogue_box)

	# Dialogue audio
	dialogue_audio = Node.new()
	dialogue_audio.set_script(DialogueAudioScript)
	add_child(dialogue_audio)

	# ── RIGHT: Log ──
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.2
	root.add_child(right_col)
	_lbl(right_col, "Eventos", 14, Color(0.7, 0.7, 0.8))
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 11)
	log_label.add_theme_color_override("default_color", Color(0.65, 0.65, 0.7))
	right_col.add_child(log_label)


# ── Actions ──

func _selected_id() -> String:
	return _character_ids[char_option.selected]


func _selected_pos() -> String:
	return POSITIONS[position_option.selected]


func _get_enter_dir() -> String:
	match enter_dir_option.selected:
		1: return "left"
		2: return "right"
	return ""  # auto


func _update_on_stage_label() -> void:
	if _on_stage.is_empty():
		on_stage_label.text = "En escena: —"
	else:
		on_stage_label.text = "En escena: %s" % ", ".join(PackedStringArray(_on_stage))


func _on_enter() -> void:
	var cid: String = _selected_id()
	var pos: String = _selected_pos()
	var dir: String = _get_enter_dir()
	stage.enter_character(cid, pos, dir)
	if cid not in _on_stage:
		_on_stage.append(cid)
	_update_on_stage_label()
	var dir_label: String = dir if dir != "" else "auto"
	_log("[color=green]%s entra → %s (desde %s)[/color]" % [cid, pos, dir_label])


func _on_move() -> void:
	var cid: String = _selected_id()
	var pos: String = _selected_pos()
	if cid not in _on_stage:
		_log("[color=red]%s no está en escena[/color]" % cid)
		return
	stage.move_character(cid, pos)
	_log("%s → %s" % [cid, pos])


func _on_exit() -> void:
	var cid: String = _selected_id()
	if cid not in _on_stage:
		_log("[color=red]%s no está en escena[/color]" % cid)
		return
	var dir: String = _get_enter_dir()
	stage.exit_character(cid, dir)
	var new_arr := PackedStringArray()
	for s in _on_stage:
		if s != cid:
			new_arr.append(s)
	_on_stage = new_arr
	_update_on_stage_label()
	_log("[color=yellow]%s sale[/color]" % cid)


func _on_expression() -> void:
	var cid: String = _selected_id()
	var expr: String = EXPRESSIONS[expression_option.selected]
	if cid not in _on_stage:
		return
	stage.set_character_expression(cid, expr)
	_log("%s expresión: %s" % [cid, expr])


func _on_pose() -> void:
	var cid: String = _selected_id()
	var pose: String = POSES[pose_option.selected]
	if cid not in _on_stage:
		return
	stage.set_body_state(cid, pose)
	_log("%s pose: %s" % [cid, pose])


func _on_look() -> void:
	var cid: String = _selected_id()
	var look: String = LOOKS[look_option.selected]
	if cid not in _on_stage:
		return
	stage.set_look_at(cid, look)
	_log("%s mira: %s" % [cid, look])


func _on_focus() -> void:
	var cid: String = _selected_id()
	if cid not in _on_stage:
		return
	stage.set_focus(cid)
	_log("Focus → %s" % cid)


func _on_close_up() -> void:
	var cid: String = _selected_id()
	if cid not in _on_stage:
		return
	stage.camera_close_up(cid)
	_log("Close-up → %s" % cid)


func _on_pull_back() -> void:
	var cid: String = _selected_id()
	if cid not in _on_stage:
		return
	stage.camera_pull_back(cid)
	_log("Pull back → %s" % cid)


func _on_camera_snap() -> void:
	var cid: String = _selected_id()
	if cid not in _on_stage:
		return
	stage.camera_snap_to(cid)
	_log("Snap → %s" % cid)


func _on_say() -> void:
	var cid: String = _selected_id()
	var text: String = dialogue_edit.text.strip_edges()
	if text.is_empty():
		text = "¡Hola! Esto es una prueba del sistema de diálogo."
	if cid not in _on_stage:
		_log("[color=red]%s no está en escena[/color]" % cid)
		return
	var data: Resource = _characters[char_option.selected]
	stage.set_character_speaking(cid, true)
	dialogue_box.show_dialogue(data.display_name, text, data.color, data)
	_log("%s dice: %s" % [cid, text.left(40)])
	# Wait for dialogue to finish, then stop speaking
	await get_tree().create_timer(0.5 + text.length() * 0.03).timeout
	if cid in _on_stage:
		stage.set_character_speaking(cid, false)


func _on_clear() -> void:
	stage.clear_stage()
	_on_stage.clear()
	_update_on_stage_label()
	_log("Escena limpiada")


# ── Helpers ──

func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 80:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
	await get_tree().process_frame
	log_label.scroll_to_line(log_label.get_line_count() - 1)


func _lbl(parent: Control, text: String, sz: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)


func _style_btn(btn: Button, color: Color) -> void:
	btn.custom_minimum_size = Vector2(0, 32)
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = color
	hover.set_corner_radius_all(4)
	hover.content_margin_left = 8
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 13)
