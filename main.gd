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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if _escape_dialog and is_instance_valid(_escape_dialog) and _escape_dialog.visible:
					_escape_dialog.hide()
					return
				_show_exit_confirmation()
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
		var default_res: Resource = load("res://data/resources/tech_demo_project.tres")
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

	if project_data.board_config == null:
		project_data.board_config = load("res://data/board_config.gd").create_default()
	else:
		project_data.board_config.get_rules()

	board.apply_board_config(project_data.board_config)

	match_manager = MatchManagerScript.new()
	match_manager.setup(runner, board, cinematic_stage, project_data.board_config)

	var sorted_events: Array[Resource] = project_data.events.duplicate()
	sorted_events.sort_custom(func(a: Resource, b: Resource) -> bool: return a.order_index < b.order_index)

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


func _load_project_data() -> bool:
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
