extends Control

const CharacterDataScript = preload("res://characters/character_data.gd")
const SceneRunnerScript = preload("res://systems/scene_runner/scene_runner.gd")
const MatchConfigScript = preload("res://match_system/match_config.gd")
const MatchManagerScript = preload("res://match_system/match_manager.gd")
const ProjectDataScript = preload("res://data/project_data.gd")
const TournamentEventScript = preload("res://data/tournament_event.gd")
const LayoutManagerScript = preload("res://systems/layout/layout_manager.gd")

@onready var cinematic_stage = %CinematicStage
@onready var board = %Board
@onready var dialogue_box = %DialogueBox
@onready var split_container: Control = %SplitContainer
@onready var cinematic_panel: PanelContainer = %CinematicPanel
@onready var board_panel: PanelContainer = %BoardPanel
@onready var debug_log: Label = %DebugLog
@onready var cinematic_highlight: Control = %CinematicHighlight
@onready var board_highlight: Control = %BoardHighlight
@onready var panel_separator: Control = %PanelSeparator

var _debug_lines: Array[String] = []
var runner: RefCounted = null
var match_manager: RefCounted = null
var layout: RefCounted = null
var _dialogue_active: bool = false
var _escape_dialog: AcceptDialog = null


var _debug_mode: bool = false
var _audio_panel: PanelContainer = null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if _audio_panel and _audio_panel.visible:
					_audio_panel.visible = false
					return
				if _escape_dialog and is_instance_valid(_escape_dialog) and _escape_dialog.visible:
					_escape_dialog.hide()
					return
				_show_exit_confirmation()
			KEY_F2:
				_toggle_audio_panel()
			KEY_F3:
				_debug_mode = not _debug_mode
				cinematic_stage.set_show_markers(_debug_mode)
				debug_log.visible = _debug_mode
				_log_debug("Debug: %s" % ("ON" if _debug_mode else "OFF"))


func _show_exit_confirmation() -> void:
	if _escape_dialog and is_instance_valid(_escape_dialog):
		_escape_dialog.queue_free()
	var dialog := ConfirmationDialog.new()
	dialog.title = "Salir"
	dialog.dialog_text = "¿Volver al menú principal?"
	dialog.ok_button_text = "Sí"
	dialog.cancel_button_text = "No"
	dialog.confirmed.connect(_return_to_menu)
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	add_child(dialog)
	dialog.popup_centered()
	_escape_dialog = dialog


func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://systems/dev_menu.tscn")


func _ready() -> void:
	# Layout manager
	layout = LayoutManagerScript.new()
	layout.setup(split_container, cinematic_panel, board_panel, panel_separator)
	layout.transition_finished.connect(_on_layout_finished)
	layout.set_instant("fullscreen")
	debug_log.visible = false
	cinematic_stage.set_show_markers(true)

	_setup_runner()
	var loaded := _load_project_data()
	if not loaded:
		var default_res: Resource = load("res://data/resources/demo_story_project.tres")
		if default_res == null:
			default_res = load("res://data/resources/tech_demo_project.tres")
		if default_res:
			_apply_project_data(default_res)
		else:
			push_error("Main: Failed to load default_project.tres")

	_connect_events()

	await get_tree().create_timer(0.5).timeout
	if match_manager:
		await match_manager.start()
	else:
		push_error("Main: match_manager is null, cannot start tournament")


func _apply_project_data(project_data: Resource) -> void:
	for character in project_data.characters:
		if character is CharacterDataScript:
			cinematic_stage.register_character(character)

	# Apply stage settings from editor if present
	if project_data.has_meta("stage_height_ratio"):
		cinematic_stage.char_height_ratio = project_data.get_meta("stage_height_ratio")
	if project_data.has_meta("stage_aspect"):
		cinematic_stage.char_aspect = project_data.get_meta("stage_aspect")
	if project_data.has_meta("stage_max_width"):
		cinematic_stage.char_max_width_frac = project_data.get_meta("stage_max_width")

	if project_data.board_config == null:
		project_data.board_config = load("res://data/board_config.gd").create_default()
	else:
		project_data.board_config.get_rules()

	board.apply_board_config(project_data.board_config)

	match_manager = MatchManagerScript.new()
	match_manager.setup(runner, board, cinematic_stage, project_data.board_config)

	var sorted_events: Array[Resource] = project_data.events.duplicate()
	sorted_events.sort_custom(_compare_events_by_order)

	for event in sorted_events:
		if not (event is TournamentEventScript):
			continue
		match event.event_type:
			"match":
				if event.match_config != null:
					match_manager.add_match(event.match_config)
			"cutscene":
				if event.cutscene_script_path != "":
					match_manager.add_cutscene(event.cutscene_script_path)
			"simultaneous":
				if event.simultaneous_configs.size() > 0:
					match_manager.add_simultaneous(event.simultaneous_configs)

	_log_debug("Project '%s': %d chars, %d events" % [
		project_data.project_name,
		project_data.characters.size(),
		match_manager.get_event_count()
	])


func _compare_events_by_order(a: Resource, b: Resource) -> bool:
	return a.order_index < b.order_index


func _log_debug(text: String) -> void:
	_debug_lines.append(text)
	if _debug_lines.size() > 8:
		_debug_lines.pop_front()
	debug_log.text = "\n".join(_debug_lines)


## ── Editor preview bridge ─────────────────────────────────────────────
## Minimal public API so the editor's PreviewManager can drive this
## embedded main.tscn instance: pause/resume, step, snapshots, reload.

func preview_pause() -> void:
	if runner:
		runner.pause()
	if board:
		board.input_enabled = false
		if board.game_controller:
			board.game_controller.update_input_state()


func preview_resume() -> void:
	if runner:
		runner.resume()


func preview_is_paused() -> bool:
	return runner != null and runner.paused


func preview_save_state() -> Dictionary:
	## Capture a snapshot of board + stage + dialogue + runner + flags.
	var snap := {}
	if board and board.has_method("save_board_state"):
		snap["board"] = board.save_board_state()
	if cinematic_stage and cinematic_stage.has_method("save_state"):
		snap["stage"] = cinematic_stage.save_state()
	if dialogue_box and dialogue_box.has_method("save_state"):
		snap["dialogue"] = dialogue_box.save_state()
	if runner and runner.has_method("save_runner_state"):
		snap["runner"] = runner.save_runner_state()
	if board and board.ai:
		snap["ai_difficulty"] = board.ai.difficulty
	snap["flags"] = GameState.flags.duplicate()
	snap["label"] = runner.current_context if runner else ""
	return snap


func preview_load_state(snap: Dictionary) -> void:
	if runner:
		runner.pause()
	if snap.has("board") and board and board.has_method("load_board_state"):
		await board.load_board_state(snap.board)
	if snap.has("stage") and cinematic_stage and cinematic_stage.has_method("load_state"):
		cinematic_stage.load_state(snap.stage)
	if snap.has("dialogue") and dialogue_box and dialogue_box.has_method("load_state"):
		dialogue_box.load_state(snap.dialogue)
	if snap.has("runner") and runner and runner.has_method("load_runner_state"):
		runner.load_runner_state(snap.runner)
	if snap.has("ai_difficulty") and board and board.ai:
		board.ai.difficulty = snap.ai_difficulty
	if snap.has("flags"):
		GameState.flags = snap.flags.duplicate()


## Called from the editor preview manager when a ScriptEditorWindow saved a
## .dscn file. Reloads reactions live if it matches the current match's
## reactions_script, or restarts the current match if it matches the intro.
func on_script_saved(path: String) -> void:
	if match_manager == null or runner == null:
		return
	var config: Resource = match_manager.get_current_config()
	if config == null:
		return
	if config.reactions_script != "" and path == config.reactions_script:
		var parser = load("res://systems/scene_runner/scene_parser.gd")
		var data = parser.parse_file(path)
		runner.clear_reactions()
		runner.load_reactions(data.reactions)
		_log_debug("Reacciones recargadas: %s" % path.get_file())
		return
	if config.intro_script != "" and path == config.intro_script:
		_log_debug("Intro cambio — reiniciando partida")
		match_manager.restart_current()


func _load_project_data() -> bool:
	# Editor "Preview este nodo" path: one-shot override injected by the editor
	# before opening the preview Window. Consume it so a later real play
	# doesn't keep using the stub project.
	if GameState.preview_project_override != null:
		var override: Resource = GameState.preview_project_override
		GameState.preview_project_override = null
		if override is ProjectDataScript:
			_apply_project_data(override)
			return true
	if not ResourceLoader.exists("user://current_project.tres"):
		return false
	var project_data: Resource = ResourceLoader.load("user://current_project.tres")
	if project_data == null or not (project_data is ProjectDataScript):
		return false
	_apply_project_data(project_data)
	return true


func _setup_runner() -> void:
	runner = SceneRunnerScript.new()
	runner.setup(cinematic_stage, board, dialogue_box)


func _connect_events() -> void:
	EventBus.specific_pattern.connect(_on_pattern)
	EventBus.effect_triggered.connect(_on_effect)
	EventBus.move_made.connect(_on_move_debug)
	EventBus.scene_script_finished.connect(_on_script_finished)
	EventBus.layout_transition_requested.connect(_on_layout_transition)
	EventBus.sim_board_rotate.connect(_on_sim_rotate)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	EventBus.board_input_enabled.connect(_on_board_input_changed)


func _on_effect(effect_name: String, intensity: float) -> void:
	_log_debug("FX: %s (x%.1f)" % [effect_name, intensity])


func _on_move_debug(cell_index: int, piece: String) -> void:
	_log_debug("MOVE: %s -> celda %d" % [piece, cell_index])


func _on_pattern(pattern_name: String) -> void:
	if runner.has_reaction(pattern_name):
		await runner.trigger_reaction(pattern_name)


func _on_sim_rotate(opponent_id: String, match_index: int, total: int) -> void:
	var display_name: String = opponent_id
	if cinematic_stage._character_registry.has(opponent_id):
		display_name = cinematic_stage._character_registry[opponent_id].display_name
	_log_debug("Tablero %d/%d: vs %s" % [match_index + 1, total, display_name])


func _on_script_finished(script_id: String) -> void:
	if script_id == "tournament_complete":
		_log_debug("Tournament complete!")


# --- Layout ---

func _on_layout_transition(mode: String) -> void:
	await get_tree().process_frame
	layout.transition_to(mode)


func _on_layout_finished(_mode: String) -> void:
	_update_panel_highlights()
	EventBus.layout_transition_finished.emit()


# --- Panel highlights ---

func _on_dialogue_started(_speaker: String, _text: String) -> void:
	_dialogue_active = true
	_update_panel_highlights()


func _on_dialogue_finished() -> void:
	_dialogue_active = false
	_update_panel_highlights()


func _on_board_input_changed(_enabled: bool) -> void:
	_update_panel_highlights()


func _update_panel_highlights() -> void:
	# Only show highlights in split mode
	if layout.get_current_mode() != "split":
		cinematic_highlight.set_highlighted(false)
		board_highlight.set_highlighted(false)
		return
	if board and board.input_enabled and not _dialogue_active:
		cinematic_highlight.set_highlighted(false)
		board_highlight.set_highlighted(true)
	elif _dialogue_active:
		cinematic_highlight.set_highlighted(true)
		board_highlight.set_highlighted(false)
	else:
		cinematic_highlight.set_highlighted(false)
		board_highlight.set_highlighted(false)


func _toggle_audio_panel() -> void:
	if _audio_panel and is_instance_valid(_audio_panel):
		_audio_panel.visible = not _audio_panel.visible
		return

	_audio_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.3, 0.3, 0.4, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_audio_panel.add_theme_stylebox_override("panel", style)
	_audio_panel.set_anchors_preset(Control.PRESET_CENTER)
	_audio_panel.offset_left = -160
	_audio_panel.offset_right = 160
	_audio_panel.offset_top = -120
	_audio_panel.offset_bottom = 120
	add_child(_audio_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_audio_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Audio (F2)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	vbox.add_child(title)

	_add_vol_slider(vbox, "Master", Settings.master_volume, func(v: float) -> void:
		Settings.master_volume = v; Settings._apply_audio())
	_add_vol_slider(vbox, "Música", Settings.music_volume, func(v: float) -> void:
		Settings.music_volume = v; Settings.volumes_changed.emit())
	_add_vol_slider(vbox, "SFX", Settings.sfx_volume, func(v: float) -> void:
		Settings.sfx_volume = v; Settings.volumes_changed.emit())
	_add_vol_slider(vbox, "Voces", Settings.voice_volume, func(v: float) -> void:
		Settings.voice_volume = v; Settings.volumes_changed.emit())

	var save_btn := Button.new()
	save_btn.text = "Guardar"
	save_btn.pressed.connect(func() -> void: Settings.save_settings())
	vbox.add_child(save_btn)


func _add_vol_slider(parent: VBoxContainer, lbl_text: String, initial: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size = Vector2(60, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(initial * 100)
	val_lbl.custom_minimum_size = Vector2(40, 0)
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	slider.value_changed.connect(func(v: float) -> void: val_lbl.text = "%d%%" % int(v * 100))
	row.add_child(val_lbl)
