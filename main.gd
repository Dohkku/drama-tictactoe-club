extends Control

const CharacterDataScript = preload("res://characters/character_data.gd")
const SceneRunnerScript = preload("res://scene_scripts/scene_runner.gd")
const MatchConfigScript = preload("res://match_system/match_config.gd")
const MatchManagerScript = preload("res://match_system/match_manager.gd")
const ProjectDataScript = preload("res://data/project_data.gd")
const TournamentEventScript = preload("res://data/tournament_event.gd")

@onready var cinematic_stage = %CinematicStage
@onready var board = %Board
@onready var dialogue_box = %DialogueBox
@onready var split_container: BoxContainer = %SplitContainer
@onready var cinematic_panel: PanelContainer = %CinematicPanel
@onready var board_panel: PanelContainer = %BoardPanel
@onready var debug_log: Label = %DebugLog
@onready var cinematic_highlight: Control = %CinematicHighlight
@onready var board_highlight: Control = %BoardHighlight
@onready var panel_separator: Control = %PanelSeparator

const LAYOUT_TRANSITION_DURATION := 0.8
var _debug_lines: Array[String] = []
var _current_layout: String = "split"  # "split", "fullscreen", "board_only"
var _layout_tween: Tween = null
var _transitioning: bool = false
var runner: RefCounted = null
var match_manager: RefCounted = null
var _dialogue_active: bool = false


var _escape_dialog: AcceptDialog = null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _escape_dialog and is_instance_valid(_escape_dialog) and _escape_dialog.visible:
			_escape_dialog.hide()
			return
		_show_exit_confirmation()


func _show_exit_confirmation() -> void:
	if _escape_dialog and is_instance_valid(_escape_dialog):
		_escape_dialog.queue_free()

	var dialog = ConfirmationDialog.new()
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
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _ready() -> void:
	_setup_runner()
	var loaded := _load_project_data()
	if not loaded:
		# Fallback to default project resource
		var default_res = load("res://data/resources/default_project.tres")
		if default_res:
			_apply_project_data(default_res)
		else:
			push_error("Main: Failed to load default_project.tres")

	_connect_events()
	_update_layout()
	get_tree().get_root().size_changed.connect(_update_layout)

	# Start in fullscreen mode since prologue is a pure cutscene
	_current_layout = "fullscreen"
	_apply_layout_instant()

	await get_tree().create_timer(0.5).timeout
	if match_manager:
		await match_manager.start()
	else:
		push_error("Main: match_manager is null, cannot start tournament")


func _apply_project_data(project_data: ProjectDataScript) -> void:
	# Register characters from project data
	for character in project_data.characters:
		if character is CharacterDataScript:
			cinematic_stage.register_character(character)

	# Migrate: ensure board_config exists with game_rules
	if project_data.board_config == null:
		project_data.board_config = load("res://data/board_config.gd").create_default()
	else:
		# Ensure game_rules sub-resource is populated
		project_data.board_config.get_rules()

	board.apply_board_config(project_data.board_config)

	# Set up tournament from project data events
	match_manager = MatchManagerScript.new()
	match_manager.setup(runner, board, cinematic_stage, project_data.board_config)

	# Sort events by order_index before processing
	var sorted_events: Array[Resource] = project_data.events.duplicate()
	sorted_events.sort_custom(func(a, b): return a.order_index < b.order_index)

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


func _log_debug(text: String) -> void:
	_debug_lines.append(text)
	if _debug_lines.size() > 8:
		_debug_lines.pop_front()
	debug_log.text = "\n".join(_debug_lines)


func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var is_portrait = viewport_size.y > viewport_size.x
	split_container.vertical = is_portrait

	if is_portrait and board_panel.get_index() < cinematic_panel.get_index():
		split_container.move_child(cinematic_panel, 0)
	elif not is_portrait and cinematic_panel.get_index() > board_panel.get_index():
		split_container.move_child(cinematic_panel, 0)

	# Keep the separator between the two panels
	var first_idx := cinematic_panel.get_index()
	var second_idx := board_panel.get_index()
	var between := mini(first_idx, second_idx) + 1
	if panel_separator.get_index() != between:
		split_container.move_child(panel_separator, between)

	# Re-enforce current layout state on resize (no animation)
	if not _transitioning:
		_apply_layout_instant()


func _apply_layout_instant() -> void:
	## Snap panels to match _current_layout without animation.
	var is_portrait = get_viewport_rect().size.y > get_viewport_rect().size.x
	match _current_layout:
		"fullscreen":
			board_panel.size_flags_stretch_ratio = 0.001
			cinematic_panel.size_flags_stretch_ratio = 1.0
			board_panel.visible = false
			cinematic_panel.visible = true
			panel_separator.visible = false
		"split":
			board_panel.size_flags_stretch_ratio = 1.0
			cinematic_panel.size_flags_stretch_ratio = 1.0
			board_panel.visible = true
			cinematic_panel.visible = true
			panel_separator.visible = true
		"board_only":
			cinematic_panel.size_flags_stretch_ratio = 0.001
			board_panel.size_flags_stretch_ratio = 1.0
			cinematic_panel.visible = false
			board_panel.visible = true
			panel_separator.visible = false


func _load_project_data() -> bool:
	## Tries to load project data from user://current_project.tres.
	## Returns true if data was loaded successfully, false to use hardcoded fallback.
	if not ResourceLoader.exists("user://current_project.tres"):
		return false

	var project_data = ResourceLoader.load("user://current_project.tres")
	if project_data == null or not (project_data is ProjectDataScript):
		push_warning("ProjectData: failed to load or invalid type at user://current_project.tres")
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
	var name = opponent_id
	if cinematic_stage._character_registry.has(opponent_id):
		name = cinematic_stage._character_registry[opponent_id].display_name
	_log_debug("Tablero %d/%d: vs %s" % [match_index + 1, total, name])


func _on_script_finished(script_id: String) -> void:
	if script_id == "tournament_complete":
		_log_debug("Tournament complete!")


# --- Panel highlight management ---

func _on_dialogue_started(_speaker: String, _text: String) -> void:
	_dialogue_active = true
	_update_panel_highlights()


func _on_dialogue_finished() -> void:
	_dialogue_active = false
	_update_panel_highlights()


func _on_board_input_changed(_enabled: bool) -> void:
	_update_panel_highlights()


func _update_panel_highlights() -> void:
	## Decide which panel (if any) should glow based on current game state.
	## Priority: board input enabled  ->  highlight board
	##           dialogue active       ->  highlight cinematic
	##           otherwise             ->  both inactive
	if board and board.input_enabled and not _dialogue_active:
		cinematic_highlight.set_highlighted(false)
		board_highlight.set_highlighted(true)
	elif _dialogue_active:
		cinematic_highlight.set_highlighted(true)
		board_highlight.set_highlighted(false)
	else:
		cinematic_highlight.set_highlighted(false)
		board_highlight.set_highlighted(false)


# --- Layout transitions ---

func _on_layout_transition(mode: String) -> void:
	await get_tree().process_frame
	# Kill any in-progress layout tween
	if _layout_tween and _layout_tween.is_valid():
		_layout_tween.kill()
	_transitioning = true
	match mode:
		"fullscreen":
			await _transition_to_fullscreen()
		"split":
			await _transition_to_split()
		"board_only":
			await _transition_to_board_only()
	_transitioning = false
	EventBus.layout_transition_finished.emit()


func _transition_to_fullscreen() -> void:
	if _current_layout == "fullscreen":
		return
	_current_layout = "fullscreen"

	cinematic_panel.visible = true
	board_panel.visible = true  # Keep visible during tween
	_layout_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_layout_tween.tween_property(board_panel, "size_flags_stretch_ratio", 0.001, LAYOUT_TRANSITION_DURATION)
	_layout_tween.parallel().tween_property(cinematic_panel, "size_flags_stretch_ratio", 1.0, LAYOUT_TRANSITION_DURATION)
	await _layout_tween.finished
	board_panel.visible = false  # Hide after animation completes
	panel_separator.visible = false
	_log_debug("Layout: fullscreen")


func _transition_to_split() -> void:
	if _current_layout == "split":
		return
	_current_layout = "split"

	board_panel.visible = true
	cinematic_panel.visible = true
	panel_separator.visible = true
	_layout_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_layout_tween.tween_property(board_panel, "size_flags_stretch_ratio", 1.0, LAYOUT_TRANSITION_DURATION)
	_layout_tween.parallel().tween_property(cinematic_panel, "size_flags_stretch_ratio", 1.0, LAYOUT_TRANSITION_DURATION)
	await _layout_tween.finished
	_log_debug("Layout: split")


func _transition_to_board_only() -> void:
	if _current_layout == "board_only":
		return
	_current_layout = "board_only"

	board_panel.visible = true
	cinematic_panel.visible = true
	_layout_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_layout_tween.tween_property(cinematic_panel, "size_flags_stretch_ratio", 0.001, LAYOUT_TRANSITION_DURATION)
	_layout_tween.parallel().tween_property(board_panel, "size_flags_stretch_ratio", 1.0, LAYOUT_TRANSITION_DURATION)
	await _layout_tween.finished
	cinematic_panel.visible = false
	panel_separator.visible = false
	_log_debug("Layout: board_only")
