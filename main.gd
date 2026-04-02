extends Control

const CharacterDataScript = preload("res://characters/character_data.gd")
const SceneRunnerScript = preload("res://scene_scripts/scene_runner.gd")
const MatchConfigScript = preload("res://match_system/match_config.gd")
const MatchManagerScript = preload("res://match_system/match_manager.gd")

@onready var cinematic_stage = %CinematicStage
@onready var board = %Board
@onready var dialogue_box = %DialogueBox
@onready var split_container: BoxContainer = %SplitContainer
@onready var cinematic_panel: PanelContainer = %CinematicPanel
@onready var board_panel: PanelContainer = %BoardPanel
@onready var debug_log: Label = %DebugLog

const VERTICAL_THRESHOLD := 800
const LAYOUT_TRANSITION_DURATION := 0.8
var _debug_lines: Array[String] = []
var _current_layout: String = "split"  # "split", "fullscreen", "board_only"
var runner: RefCounted = null
var match_manager: RefCounted = null


func _ready() -> void:
	_register_characters()
	_setup_runner()
	_setup_tournament()
	_connect_events()
	_update_layout()
	get_tree().get_root().size_changed.connect(_update_layout)

	# Start in fullscreen mode since prologue is a pure cutscene
	board_panel.size_flags_stretch_ratio = 0.001
	_current_layout = "fullscreen"

	await get_tree().create_timer(0.5).timeout
	await match_manager.start()


func _log_debug(text: String) -> void:
	_debug_lines.append(text)
	if _debug_lines.size() > 8:
		_debug_lines.pop_front()
	debug_log.text = "\n".join(_debug_lines)


func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	split_container.vertical = viewport_size.x < VERTICAL_THRESHOLD


func _register_characters() -> void:
	# Akira — aggressive, flashy, club champion
	var akira = CharacterDataScript.new()
	akira.character_id = "akira"
	akira.display_name = "Akira"
	akira.color = Color(0.9, 0.2, 0.2)
	akira.default_style = "spinning"
	akira.default_pose = "idle"
	akira.default_look = "center"
	akira.expressions = {
		"neutral": Color(0.9, 0.2, 0.2),
		"smirk": Color(0.95, 0.3, 0.15),
		"confident": Color(1.0, 0.4, 0.1),
		"angry": Color(0.8, 0.1, 0.1),
		"surprised": Color(1.0, 0.5, 0.3),
		"intense": Color(0.7, 0.05, 0.05),
		"sweating": Color(0.8, 0.4, 0.4),
		"shocked": Color(1.0, 0.6, 0.5),
		"triumphant": Color(1.0, 0.25, 0.0),
	}
	akira.poses = {
		"idle": {"energy": 0.3, "openness": 0.5},
		"confident": {"energy": 0.5, "openness": 0.8},
		"arms_crossed": {"energy": 0.4, "openness": 0.2},
		"leaning_forward": {"energy": 0.7, "openness": 0.6},
		"excited": {"energy": 0.9, "openness": 0.9},
		"tense": {"energy": 0.8, "openness": 0.1},
		"defeated": {"energy": 0.1, "openness": 0.3},
	}
	cinematic_stage.register_character(akira)

	# Mei — calm, analytical, club vice-president
	var mei = CharacterDataScript.new()
	mei.character_id = "mei"
	mei.display_name = "Mei"
	mei.color = Color(0.6, 0.3, 0.9)
	mei.default_style = "gentle"
	mei.default_pose = "idle"
	mei.default_look = "center"
	mei.expressions = {
		"neutral": Color(0.6, 0.3, 0.9),
		"calm": Color(0.55, 0.35, 0.85),
		"analytical": Color(0.5, 0.25, 0.95),
		"focused": Color(0.45, 0.2, 1.0),
		"surprised": Color(0.7, 0.45, 0.95),
		"respect": Color(0.65, 0.5, 0.9),
	}
	mei.poses = {
		"idle": {"energy": 0.2, "openness": 0.4},
		"thinking": {"energy": 0.3, "openness": 0.3},
		"arms_crossed": {"energy": 0.2, "openness": 0.1},
		"leaning_forward": {"energy": 0.4, "openness": 0.5},
		"surprised": {"energy": 0.5, "openness": 0.7},
	}
	cinematic_stage.register_character(mei)

	# Player
	var player = CharacterDataScript.new()
	player.character_id = "player"
	player.display_name = "Tú"
	player.color = Color(0.2, 0.5, 1.0)
	player.default_style = "slam"
	player.expressions = {
		"neutral": Color(0.2, 0.5, 1.0),
		"determined": Color(0.1, 0.4, 1.0),
		"nervous": Color(0.4, 0.5, 0.8),
		"happy": Color(0.3, 0.7, 1.0),
	}
	cinematic_stage.register_character(player)


func _setup_runner() -> void:
	runner = SceneRunnerScript.new()
	runner.setup(cinematic_stage, board, dialogue_box)


func _setup_tournament() -> void:
	match_manager = MatchManagerScript.new()
	match_manager.setup(runner, board, cinematic_stage)

	# Prologue cutscene — pure dialogue, no board
	match_manager.add_cutscene("res://scene_scripts/scripts/prologue.dscn")

	# Match 1: vs Akira — aggressive, easy
	var m1 = MatchConfigScript.new()
	m1.match_id = "match_01"
	m1.opponent_id = "akira"
	m1.ai_difficulty = 0.3
	m1.game_rules_preset = "standard"
	m1.intro_script = "res://scene_scripts/scripts/match_01_intro.dscn"
	m1.reactions_script = "res://scene_scripts/scripts/match_01_reactions.dscn"
	m1.player_style = "slam"
	m1.opponent_style = "spinning"
	match_manager.add_match(m1)

	# Match 2: vs Mei — calm, harder
	var m2 = MatchConfigScript.new()
	m2.match_id = "match_02"
	m2.opponent_id = "mei"
	m2.ai_difficulty = 0.6
	m2.game_rules_preset = "standard"
	m2.intro_script = "res://scene_scripts/scripts/match_02_intro.dscn"
	m2.reactions_script = "res://scene_scripts/scripts/match_02_reactions.dscn"
	m2.player_style = "slam"
	m2.opponent_style = "gentle"
	match_manager.add_match(m2)

	_log_debug("Tournament: %d events" % match_manager.get_event_count())


func _connect_events() -> void:
	EventBus.specific_pattern.connect(_on_pattern)
	EventBus.effect_triggered.connect(_on_effect)
	EventBus.move_made.connect(_on_move_debug)
	EventBus.scene_script_finished.connect(_on_script_finished)
	EventBus.layout_transition_requested.connect(_on_layout_transition)


func _on_effect(effect_name: String, intensity: float) -> void:
	_log_debug("FX: %s (x%.1f)" % [effect_name, intensity])


func _on_move_debug(cell_index: int, piece: String) -> void:
	_log_debug("MOVE: %s -> celda %d" % [piece, cell_index])


func _on_pattern(pattern_name: String) -> void:
	if runner.has_reaction(pattern_name):
		await runner.trigger_reaction(pattern_name)


func _on_script_finished(script_id: String) -> void:
	if script_id == "tournament_complete":
		_log_debug("Tournament complete!")


# --- Layout transitions ---

func _on_layout_transition(mode: String) -> void:
	# Always yield one frame first so the runner's await is ready
	await get_tree().process_frame
	match mode:
		"fullscreen":
			await _transition_to_fullscreen()
		"split":
			await _transition_to_split()
		"board_only":
			await _transition_to_board_only()
	EventBus.layout_transition_finished.emit()


func _transition_to_fullscreen() -> void:
	if _current_layout == "fullscreen":
		return
	_current_layout = "fullscreen"

	cinematic_panel.visible = true
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(board_panel, "size_flags_stretch_ratio", 0.001, LAYOUT_TRANSITION_DURATION)
	tween.parallel().tween_property(cinematic_panel, "size_flags_stretch_ratio", 1.0, LAYOUT_TRANSITION_DURATION)
	await tween.finished
	_log_debug("Layout: fullscreen")


func _transition_to_split() -> void:
	if _current_layout == "split":
		return
	_current_layout = "split"

	board_panel.visible = true
	cinematic_panel.visible = true
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(board_panel, "size_flags_stretch_ratio", 1.0, LAYOUT_TRANSITION_DURATION)
	tween.parallel().tween_property(cinematic_panel, "size_flags_stretch_ratio", 1.0, LAYOUT_TRANSITION_DURATION)
	await tween.finished
	_log_debug("Layout: split")


func _transition_to_board_only() -> void:
	if _current_layout == "board_only":
		return
	_current_layout = "board_only"

	board_panel.visible = true
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(cinematic_panel, "size_flags_stretch_ratio", 0.001, LAYOUT_TRANSITION_DURATION)
	tween.parallel().tween_property(board_panel, "size_flags_stretch_ratio", 1.0, LAYOUT_TRANSITION_DURATION)
	await tween.finished
	_log_debug("Layout: board_only")
