class_name MatchManager
extends RefCounted

## Orchestrates a tournament: matches, cutscenes, and simultaneous round-robin matches.

const SceneParserScript = preload("res://scene_scripts/parser/scene_parser.gd")
const GameRulesScript = preload("res://board/game_rules.gd")
const PlacementStyleScript = preload("res://board/placement_style.gd")

var _runner: RefCounted   # SceneRunner
var _board: Control       # Board
var _stage: Control       # CinematicStage
var _dialogue_box: Control # DialogueBox
var _events: Array = []
var _current: int = -1

# Simultaneous match state
signal _sim_resolved()
var _sim_result: Dictionary = {}
var _sim_reactions: Dictionary = {}  # opponent_id -> reactions dict


func setup(runner: RefCounted, board: Control, stage: Control) -> void:
	_runner = runner
	_board = board
	_stage = stage
	_dialogue_box = runner._dialogue_box


func add_match(config: Resource) -> void:
	_events.append({"type": "match", "config": config})


func add_cutscene(script_path: String) -> void:
	_events.append({"type": "cutscene", "script": script_path})


func add_simultaneous(configs: Array) -> void:
	_events.append({"type": "simultaneous", "configs": configs})


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
		"simultaneous":
			await _play_simultaneous(event.configs)

	_current += 1
	if _current < _events.size():
		await _stage.get_tree().create_timer(1.0).timeout
		await _play_event(_events[_current])
	else:
		EventBus.scene_script_finished.emit("tournament_complete")


func _play_cutscene(script_path: String) -> void:
	_runner.clear_reactions()
	var data = SceneParserScript.parse_file(script_path)
	await _runner.execute(data)


# ==== Regular Match ====

func _play_match(config: Resource) -> void:
	_configure_board(config)
	await _stage.get_tree().create_timer(0.3).timeout

	_runner.clear_reactions()
	if config.reactions_script != "":
		var data = SceneParserScript.parse_file(config.reactions_script)
		_runner.load_reactions(data.reactions)

	_board.pre_move_hook_enabled = true
	if not EventBus.before_ai_move.is_connected(_on_before_ai_move):
		EventBus.before_ai_move.connect(_on_before_ai_move)

	if config.intro_script != "":
		var data = SceneParserScript.parse_file(config.intro_script)
		await _runner.execute(data)

	var result = await EventBus.match_ended

	_board.pre_move_hook_enabled = false
	if EventBus.before_ai_move.is_connected(_on_before_ai_move):
		EventBus.before_ai_move.disconnect(_on_before_ai_move)

	match result:
		"win":
			await _runner.trigger_reaction("player_wins")
		"lose":
			await _runner.trigger_reaction("opponent_wins")
		"draw":
			await _runner.trigger_reaction("draw")

	GameState.record_match(config.opponent_id, result)


func _on_before_ai_move() -> void:
	await _stage.get_tree().process_frame
	await _runner.trigger_reaction("before_opponent_move")
	EventBus.pre_move_complete.emit()


# ==== Simultaneous Matches ====

func _play_simultaneous(configs: Array) -> void:
	var boards: Array = []
	for config in configs:
		boards.append({
			"config": config,
			"state": null,        # Saved board state (null = fresh)
			"finished": false,
			"result": "",
			"ai_pending": false,  # True if AI needs to respond on next visit
		})

	# Run intros for each opponent
	for i in range(boards.size()):
		var config = boards[i].config
		_configure_board(config)
		await _stage.get_tree().create_timer(0.3).timeout
		await _stage.get_tree().process_frame

		if config.intro_script != "":
			_runner.clear_reactions()
			var data = SceneParserScript.parse_file(config.intro_script)
			await _runner.execute(data)

		boards[i].state = _board.save_board_state()

	# Preload reactions per opponent
	_sim_reactions.clear()
	for entry in boards:
		var config = entry.config
		if config.reactions_script != "":
			var data = SceneParserScript.parse_file(config.reactions_script)
			_sim_reactions[config.opponent_id] = data.reactions
		else:
			_sim_reactions[config.opponent_id] = {}

	# Configure board for sim mode: no auto-AI, external input control
	_board.external_input_control = true
	_board.auto_ai_enabled = false
	_board.pre_move_hook_enabled = false

	var current_idx := 0
	var prev_idx := -1  # Track previous board to avoid redundant transitions
	while _sim_has_unfinished(boards):
		if boards[current_idx].finished:
			current_idx = _sim_next_index(current_idx, boards)
			continue

		var entry = boards[current_idx]
		var config = entry.config

		# --- Wait for any running dialogue/reactions to finish before transitioning ---
		await _wait_for_runner()

		# --- Skip visual transition if we're staying on the same board ---
		var needs_transition = (current_idx != prev_idx)

		if needs_transition:
			# Hide dialogue before rotation
			_dialogue_box.hide_dialogue()

			EventBus.sim_board_rotate.emit(config.opponent_id, current_idx, boards.size())
			await _stage.get_tree().create_timer(0.3).timeout

			# Show opponent on stage
			_stage.clear_stage()
			await _stage.get_tree().process_frame
			await _stage.enter_character(config.opponent_id, "right", "right")

			# Configure board visuals + load reactions
			_configure_board_visuals(config)
			_runner.clear_reactions()
			if _sim_reactions.has(config.opponent_id):
				_runner.load_reactions(_sim_reactions[config.opponent_id])

			# Load board state
			if entry.state:
				await _board.load_board_state(entry.state)
			else:
				await _board.full_reset(_resolve_rules(config.game_rules_preset))
				await _stage.get_tree().process_frame

		# --- If AI has a pending move from last visit, resolve it now ---
		if entry.ai_pending and not _board.logic.game_over:
			# Enable pre-move hook for AI reaction/dialogue
			_board.pre_move_hook_enabled = true
			if not EventBus.before_ai_move.is_connected(_on_before_ai_move):
				EventBus.before_ai_move.connect(_on_before_ai_move)

			# Listen for game end during AI turn
			var ai_ended := false
			var ai_end_result := ""
			var end_cb = func(result: String):
				ai_ended = true
				ai_end_result = result
			EventBus.match_ended.connect(end_cb)

			await _board.trigger_ai_turn()

			if EventBus.match_ended.is_connected(end_cb):
				EventBus.match_ended.disconnect(end_cb)
			_board.pre_move_hook_enabled = false
			if EventBus.before_ai_move.is_connected(_on_before_ai_move):
				EventBus.before_ai_move.disconnect(_on_before_ai_move)

			entry.ai_pending = false

			if ai_ended:
				entry.finished = true
				entry.result = ai_end_result
				await _run_end_reaction(ai_end_result)
				GameState.record_match(config.opponent_id, ai_end_result)
				await _wait_for_runner()
				await _stage.exit_character(config.opponent_id)
				prev_idx = current_idx
				current_idx = _sim_next_index(current_idx, boards)
				continue

		# --- Player turns ---
		var turns_left = config.turns_per_visit
		var visit_done := false

		for t in range(turns_left):
			if _board.logic.game_over:
				break

			# Enable input for player
			_board.input_enabled = true
			_board._update_input_state()

			# Wait for player's move (turn changes to "O") or game end
			var player_result = await _sim_wait_for_signal("O")

			_board.input_enabled = false
			_board._update_input_state()

			if player_result.game_over:
				entry.finished = true
				entry.result = player_result.result
				await _run_end_reaction(player_result.result)
				GameState.record_match(config.opponent_id, player_result.result)
				visit_done = true
				break

			# If NOT last turn of this visit, let AI respond within this visit
			if t < turns_left - 1:
				var ai_ended2 := false
				var ai_result2 := ""
				var end_cb2 = func(result: String):
					ai_ended2 = true
					ai_result2 = result
				EventBus.match_ended.connect(end_cb2)

				await _board.trigger_ai_turn()

				if EventBus.match_ended.is_connected(end_cb2):
					EventBus.match_ended.disconnect(end_cb2)

				if ai_ended2:
					entry.finished = true
					entry.result = ai_result2
					await _run_end_reaction(ai_result2)
					GameState.record_match(config.opponent_id, ai_result2)
					visit_done = true
					break

		# Save state and rotate (AI will respond when we come back)
		if not entry.finished:
			entry.state = _board.save_board_state()
			entry.ai_pending = true

		# Wait for any dialogue/reactions to finish before exiting
		await _wait_for_runner()
		_dialogue_box.hide_dialogue()

		# Only exit character if we'll actually switch to a different board
		var next_idx = _sim_next_index(current_idx, boards)
		if next_idx != current_idx or entry.finished:
			await _stage.exit_character(config.opponent_id)

		prev_idx = current_idx
		current_idx = next_idx

	# Restore normal board mode
	_board.external_input_control = false
	_board.auto_ai_enabled = true
	_board.pre_move_hook_enabled = false


func _sim_wait_for_signal(expected_turn: String) -> Dictionary:
	## Wait for turn_changed(expected_turn) or match_ended.
	_sim_result = {}

	var turn_cb = func(whose: String):
		if whose == expected_turn and _sim_result.is_empty():
			_sim_result = {"game_over": false, "result": ""}
			_sim_resolved.emit()
	var end_cb = func(result: String):
		if _sim_result.is_empty():
			_sim_result = {"game_over": true, "result": result}
			_sim_resolved.emit()

	EventBus.turn_changed.connect(turn_cb)
	EventBus.match_ended.connect(end_cb)

	await _sim_resolved

	if EventBus.turn_changed.is_connected(turn_cb):
		EventBus.turn_changed.disconnect(turn_cb)
	if EventBus.match_ended.is_connected(end_cb):
		EventBus.match_ended.disconnect(end_cb)

	return _sim_result


func _wait_for_runner() -> void:
	## Wait for any in-progress dialogue or scene runner execution to finish.
	while _runner._running:
		await _stage.get_tree().process_frame


func _run_end_reaction(result: String) -> void:
	match result:
		"win": await _runner.trigger_reaction("player_wins")
		"lose": await _runner.trigger_reaction("opponent_wins")
		"draw": await _runner.trigger_reaction("draw")


func _sim_has_unfinished(boards: Array) -> bool:
	for entry in boards:
		if not entry.finished:
			return true
	return false


func _sim_next_index(current: int, boards: Array) -> int:
	var count = boards.size()
	for i in range(1, count + 1):
		var idx = (current + i) % count
		if not boards[idx].finished:
			return idx
	return current


# ==== Shared helpers ====

func _configure_board_visuals(config: Resource) -> void:
	var opponent_data = _stage._character_registry.get(config.opponent_id)
	var player_data = _stage._character_registry.get("player")

	if player_data:
		_board.player_color = player_data.color
		_board.player_expressions = player_data.expressions
	if opponent_data:
		_board.opponent_color = opponent_data.color
		_board.opponent_expressions = opponent_data.expressions

	var p_style_name = config.player_style
	var o_style_name = config.opponent_style
	if o_style_name == "" and opponent_data and opponent_data.get("default_style"):
		o_style_name = opponent_data.default_style

	_board.set_player_style(_resolve_style(p_style_name))
	_board.set_opponent_style(_resolve_style(o_style_name))
	_board.ai.difficulty = config.ai_difficulty


func _configure_board(config: Resource) -> void:
	var rules = _resolve_rules(config.game_rules_preset)
	_configure_board_visuals(config)
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
