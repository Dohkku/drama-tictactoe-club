extends Control

## Interactive sandbox for the Scene Runner system.
## Tests: .dscn script loading, parsing, execution, dialogue, camera, characters.

const CinematicStageScene: PackedScene = preload("res://systems/cinematic/cinematic_stage.tscn")
const DialogueBoxScene: PackedScene = preload("res://systems/cinematic/dialogue_box.tscn")
const DialogueAudioScript: GDScript = preload("res://systems/cinematic/dialogue_audio.gd")
const CharacterDataScript: GDScript = preload("res://characters/character_data.gd")
const SceneRunnerScript: GDScript = preload("res://systems/scene_runner/scene_runner.gd")
const SceneParserScript: GDScript = preload("res://systems/scene_runner/scene_parser.gd")

const SCRIPTS_DIR := "res://scene_scripts/scripts/"

var stage: Control
var dialogue_box: Control
var dialogue_audio: Node
var runner: RefCounted

# UI references
var script_list: ItemList
var load_btn: Button
var stop_btn: Button
var pause_btn: Button
var resume_btn: Button
var skip_btn: Button
var status_label: Label
var log_label: RichTextLabel
var log_lines: Array[String] = []

# State
var _script_paths: PackedStringArray = PackedStringArray()
var _running: bool = false
var _paused: bool = false


func _ready() -> void:
	_build_ui()
	_load_characters()
	_scan_scripts()
	_connect_events()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://systems/dev_menu.tscn")


func _connect_events() -> void:
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	EventBus.character_entered.connect(func(cid: String) -> void: _log("[color=green]ENTER: %s[/color]" % cid))
	EventBus.character_exited.connect(func(cid: String) -> void: _log("[color=yellow]EXIT: %s[/color]" % cid))
	EventBus.scene_script_finished.connect(func(sid: String) -> void: _log("[color=cyan]FINISHED: %s[/color]" % sid))
	EventBus.layout_transition_requested.connect(func(mode: String) -> void: _log("LAYOUT: %s" % mode))


func _on_dialogue_started(speaker: String, text: String) -> void:
	_log("[color=white]%s: %s[/color]" % [speaker, text.left(60)])


func _on_dialogue_finished() -> void:
	_log("[color=gray]-- dialogue finished --[/color]")


func _scan_scripts() -> void:
	script_list.clear()
	_script_paths.clear()
	var files: PackedStringArray = DirAccess.get_files_at(SCRIPTS_DIR)
	for f in files:
		if f.ends_with(".dscn"):
			_script_paths.append(SCRIPTS_DIR + f)
			script_list.add_item(f)
	if _script_paths.is_empty():
		script_list.add_item("(no .dscn files found)")
	_log("Found %d .dscn scripts" % _script_paths.size())


func _load_characters() -> void:
	var dir := "res://characters/data/"
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	for f in files:
		if f.ends_with(".tres"):
			var res: Resource = load(dir + f)
			if res and res.get("character_id") != null:
				stage.register_character(res)
				_log("Registered: %s" % str(res.get("character_id")))


func _on_load_pressed() -> void:
	var selected: PackedInt32Array = script_list.get_selected_items()
	if selected.is_empty():
		_log("[color=red]Select a script first[/color]")
		return
	var idx: int = selected[0]
	if idx >= _script_paths.size():
		return
	var path: String = _script_paths[idx]
	_log("Parsing: %s" % path)

	var data: Dictionary = SceneParserScript.parse_file(path)

	_log("Type: %s | Name: %s | Commands: %d" % [
		data.get("type", "?"),
		data.get("name", "?"),
		data.get("commands", []).size()
	])

	if data.get("type", "") == "reactions":
		var reactions: Dictionary = data.get("reactions", {})
		_log("Reactions mode: %d events" % reactions.size())
		for key in reactions:
			var cmds: Array = reactions[key]
			_log("  @on %s -> %d commands" % [key, cmds.size()])
		runner.load_reactions(reactions)
		_update_status("Reactions loaded: %s" % data.get("name", ""))
		return

	# Cutscene mode: execute
	_execute_script(data)


func _execute_script(data: Dictionary) -> void:
	if _running:
		_log("[color=red]Already running a script[/color]")
		return
	_running = true
	_update_status("Running: %s" % data.get("name", "script"))
	_update_button_states()

	# Log commands for visibility
	var commands: Array = data.get("commands", [])
	for i in range(mini(commands.size(), 5)):
		var cmd: Dictionary = commands[i]
		_log("  [%d] %s" % [i, cmd.get("type", "?")])
	if commands.size() > 5:
		_log("  ... +%d more commands" % (commands.size() - 5))

	await runner.execute(data)

	_running = false
	_update_status("Idle")
	_update_button_states()
	_log("[color=cyan]Execution complete[/color]")


func _on_stop_pressed() -> void:
	if not _running:
		return
	# SceneRunner doesn't have a formal stop, but we can clear the stage
	stage.clear_stage()
	dialogue_box.hide_dialogue()
	runner.clear_reactions()
	_running = false
	_paused = false
	_update_status("Stopped")
	_update_button_states()
	_log("[color=red]Execution stopped[/color]")


func _on_pause_pressed() -> void:
	if not _running or _paused:
		return
	# Pause the stage subtree only, not the whole tree
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	dialogue_box.process_mode = Node.PROCESS_MODE_DISABLED
	_paused = true
	_update_status("Paused")
	_update_button_states()
	_log("[color=yellow]Paused[/color]")


func _on_resume_pressed() -> void:
	if not _paused:
		return
	stage.process_mode = Node.PROCESS_MODE_INHERIT
	dialogue_box.process_mode = Node.PROCESS_MODE_INHERIT
	_paused = false
	_update_status("Running")
	_update_button_states()
	_log("[color=green]Resumed[/color]")


func _on_skip_pressed() -> void:
	# Emit dialogue_finished to advance past current dialogue
	EventBus.dialogue_finished.emit()
	_log("Skip -> dialogue_finished emitted")


func _update_status(text: String) -> void:
	status_label.text = "Estado: %s" % text


func _update_button_states() -> void:
	load_btn.disabled = _running
	stop_btn.disabled = not _running
	pause_btn.disabled = not _running or _paused
	resume_btn.disabled = not _paused
	skip_btn.disabled = not _running


# ---- UI construction ----

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

	# -- LEFT: Controls --
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
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://systems/dev_menu.tscn"))
	left.add_child(back)

	_lbl(left, "SCENE RUNNER", 16, Color(0.9, 0.3, 0.5))
	left.add_child(HSeparator.new())

	# Script list
	_lbl(left, "Scripts (.dscn)", 13, Color(0.6, 0.6, 0.75))
	script_list = ItemList.new()
	script_list.custom_minimum_size = Vector2(0, 180)
	script_list.add_theme_font_size_override("font_size", 12)
	script_list.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	left.add_child(script_list)

	# Load button
	load_btn = Button.new()
	load_btn.text = "Cargar y Ejecutar"
	load_btn.pressed.connect(_on_load_pressed)
	_style_btn(load_btn, Color(0.2, 0.5, 0.3))
	left.add_child(load_btn)

	left.add_child(HSeparator.new())

	# Playback controls
	_lbl(left, "Controles", 13, Color(0.6, 0.6, 0.75))

	var ctrl_row1 := HBoxContainer.new()
	ctrl_row1.add_theme_constant_override("separation", 4)
	left.add_child(ctrl_row1)

	pause_btn = Button.new()
	pause_btn.text = "Pausa"
	pause_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_btn.pressed.connect(_on_pause_pressed)
	pause_btn.disabled = true
	_style_btn(pause_btn, Color(0.5, 0.4, 0.2))
	ctrl_row1.add_child(pause_btn)

	resume_btn = Button.new()
	resume_btn.text = "Reanudar"
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_btn.pressed.connect(_on_resume_pressed)
	resume_btn.disabled = true
	_style_btn(resume_btn, Color(0.3, 0.5, 0.2))
	ctrl_row1.add_child(resume_btn)

	var ctrl_row2 := HBoxContainer.new()
	ctrl_row2.add_theme_constant_override("separation", 4)
	left.add_child(ctrl_row2)

	skip_btn = Button.new()
	skip_btn.text = "Skip"
	skip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip_btn.pressed.connect(_on_skip_pressed)
	skip_btn.disabled = true
	_style_btn(skip_btn, Color(0.4, 0.3, 0.5))
	ctrl_row2.add_child(skip_btn)

	stop_btn = Button.new()
	stop_btn.text = "Detener"
	stop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stop_btn.pressed.connect(_on_stop_pressed)
	stop_btn.disabled = true
	_style_btn(stop_btn, Color(0.5, 0.15, 0.15))
	ctrl_row2.add_child(stop_btn)

	left.add_child(HSeparator.new())

	# Status
	status_label = Label.new()
	status_label.text = "Estado: Idle"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	left.add_child(status_label)

	left.add_child(HSeparator.new())

	# Refresh button
	var refresh_btn := Button.new()
	refresh_btn.text = "Refrescar lista"
	refresh_btn.pressed.connect(_scan_scripts)
	_style_btn(refresh_btn, Color(0.3, 0.3, 0.5))
	left.add_child(refresh_btn)

	# Clear stage button
	var clear_btn := Button.new()
	clear_btn.text = "LIMPIAR ESCENA"
	clear_btn.pressed.connect(func() -> void:
		stage.clear_stage()
		dialogue_box.hide_dialogue()
		runner.clear_reactions()
		_log("Escena limpiada")
	)
	_style_btn(clear_btn, Color(0.5, 0.15, 0.15))
	left.add_child(clear_btn)

	# -- CENTER: Stage + Dialogue --
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 0.55
	root.add_child(center)

	_lbl(center, "Escenario", 14, Color(0.7, 0.7, 0.8))

	# Stage container
	var stage_container := PanelContainer.new()
	stage_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stage_style := StyleBoxFlat.new()
	stage_style.bg_color = Color(0.1, 0.1, 0.15)
	stage_style.set_corner_radius_all(4)
	stage_container.add_theme_stylebox_override("panel", stage_style)
	center.add_child(stage_container)

	stage = CinematicStageScene.instantiate()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_container.add_child(stage)

	# Show position markers for debugging
	stage.set_show_markers(true)

	# Dialogue box below stage
	dialogue_box = DialogueBoxScene.instantiate()
	dialogue_box.custom_minimum_size = Vector2(0, 80)
	center.add_child(dialogue_box)

	# Dialogue audio
	dialogue_audio = Node.new()
	dialogue_audio.set_script(DialogueAudioScript)
	add_child(dialogue_audio)

	# Create scene runner and wire it up (no board in sandbox)
	runner = SceneRunnerScript.new()
	runner.setup(stage, null, dialogue_box)

	# -- RIGHT: Log --
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.2
	root.add_child(right_col)
	_lbl(right_col, "Log", 14, Color(0.7, 0.7, 0.8))
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 11)
	log_label.add_theme_color_override("default_color", Color(0.65, 0.65, 0.7))
	right_col.add_child(log_label)

	var clear_log_btn := Button.new()
	clear_log_btn.text = "Limpiar log"
	clear_log_btn.pressed.connect(func() -> void:
		log_lines.clear()
		log_label.text = ""
	)
	_style_btn(clear_log_btn, Color(0.3, 0.3, 0.4))
	right_col.add_child(clear_log_btn)


# ---- Helpers ----

func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 120:
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
