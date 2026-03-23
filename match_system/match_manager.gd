class_name MatchManager
extends RefCounted

## Orchestrates a tournament: a sequence of matches and cutscenes.
## Events can be:
##   {"type": "match", "config": MatchConfig}
##   {"type": "cutscene", "script": "res://path.dscn"}

const SceneParserScript = preload("res://scene_scripts/parser/scene_parser.gd")
const GameRulesScript = preload("res://board/game_rules.gd")
const PlacementStyleScript = preload("res://board/placement_style.gd")

var _runner: RefCounted   # SceneRunner
var _board: Control       # Board
var _stage: Control       # CinematicStage
var _events: Array = []   # Sequence of match/cutscene events
var _current: int = -1


func setup(runner: RefCounted, board: Control, stage: Control) -> void:
	_runner = runner
	_board = board
	_stage = stage


func add_match(config: Resource) -> void:
	_events.append({"type": "match", "config": config})


func add_cutscene(script_path: String) -> void:
	_events.append({"type": "cutscene", "script": script_path})


func get_current_index() -> int:
	return _current


func get_event_count() -> int:
	return _events.size()


func start() -> void:
	_current = 0
	await _play_event(_events[0])


func _play_event(event: Dictionary) -> void:
	match event.type:
		"match":
			await _play_match(event.config)
		"cutscene":
			await _play_cutscene(event.script)

	# Advance to next event
	_current += 1
	if _current < _events.size():
		await _stage.get_tree().create_timer(1.0).timeout
		await _play_event(_events[_current])
	else:
		EventBus.scene_script_finished.emit("tournament_complete")


func _play_cutscene(script_path: String) -> void:
	_runner.clear_reactions()
	var data = SceneParserScript.parse_file(script_path)
	await _runner.execute(data.commands)


func _play_match(config: Resource) -> void:
	# 1. Configure board for this match
	_configure_board(config)

	# Small delay for board to rebuild
	await _stage.get_tree().create_timer(0.3).timeout

	# 2. Load reactions into runner
	_runner.clear_reactions()
	if config.reactions_script != "":
		var data = SceneParserScript.parse_file(config.reactions_script)
		_runner.load_reactions(data.reactions)

	# 3. Run intro cutscene
	if config.intro_script != "":
		var data = SceneParserScript.parse_file(config.intro_script)
		await _runner.execute(data.commands)

	# 4. Wait for the game to end
	var result = await EventBus.match_ended

	# 5. Run end-of-game reaction
	match result:
		"win":
			await _runner.trigger_reaction("player_wins")
		"lose":
			await _runner.trigger_reaction("opponent_wins")
		"draw":
			await _runner.trigger_reaction("draw")

	GameState.record_match(config.opponent_id, result)


func _configure_board(config: Resource) -> void:
	# Rules
	var rules = _resolve_rules(config.game_rules_preset)

	# Colors and expressions from character registry
	var opponent_data = _stage._character_registry.get(config.opponent_id)
	var player_data = _stage._character_registry.get("player")

	if player_data:
		_board.player_color = player_data.color
		_board.player_expressions = player_data.expressions
	if opponent_data:
		_board.opponent_color = opponent_data.color
		_board.opponent_expressions = opponent_data.expressions

	# Styles — use character default or match override
	var p_style_name = config.player_style
	var o_style_name = config.opponent_style
	if o_style_name == "" and opponent_data and opponent_data.get("default_style"):
		o_style_name = opponent_data.default_style

	_board.set_player_style(_resolve_style(p_style_name))
	_board.set_opponent_style(_resolve_style(o_style_name))

	# AI difficulty
	_board.ai.difficulty = config.ai_difficulty

	# Rebuild board with (possibly new) rules
	_board.full_reset(rules)


func _resolve_rules(preset: String) -> Resource:
	match preset:
		"rotating_3":
			return GameRulesScript.rotating_3()
		"big_board":
			return GameRulesScript.big_board()
		_:
			return GameRulesScript.standard()


func _resolve_style(name: String) -> Resource:
	match name:
		"gentle": return PlacementStyleScript.gentle()
		"slam": return PlacementStyleScript.slam()
		"spinning": return PlacementStyleScript.spinning()
		"dramatic": return PlacementStyleScript.dramatic()
		"nervous": return PlacementStyleScript.nervous()
	return PlacementStyleScript.gentle()
