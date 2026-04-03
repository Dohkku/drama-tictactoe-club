class_name BoardLogic
extends RefCounted

## Pure game logic for N-player tic-tac-toe.
## Players are identified by integers: 0 = empty, 1..N = players.

const GameRulesScript = preload("res://systems/board_logic/game_rules.gd")

const EMPTY := 0

const PIECE_LABELS := ["", "X", "O", "△", "□", "◇", "★"]
const PIECE_COLORS := [
	Color.TRANSPARENT,
	Color(0.3, 0.6, 1.0),   # Player 1: Blue
	Color(1.0, 0.3, 0.3),   # Player 2: Red
	Color(0.3, 0.9, 0.4),   # Player 3: Green
	Color(0.8, 0.3, 0.9),   # Player 4: Purple
	Color(1.0, 0.6, 0.2),   # Player 5: Orange
	Color(0.2, 0.9, 0.9),   # Player 6: Cyan
]

var rules: Resource  # GameRules
var cells: Array[int] = []
var current_turn: int = 1  # Player 1 starts
var game_over: bool = false
var winner: int = EMPTY
var move_count: int = 0

## Cells that formed the winning line (empty if no winner yet)
var winning_pattern: Array[int] = []

## Move history per player: { player_id: Array[int] of cell indices }
var move_history: Dictionary = {}

## Global ordered history: [{player: int, cell: int, move_number: int, removed_cell: int}]
var global_history: Array[Dictionary] = []

## Undo stack: array of full states for undo/redo
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []

var _win_patterns: Array = []


func _init(custom_rules: Resource = null) -> void:
	if custom_rules:
		rules = custom_rules
	else:
		rules = GameRulesScript.new()
	_setup()


func _setup() -> void:
	var total = rules.get_total_cells()
	cells.resize(total)
	cells.fill(EMPTY)
	_win_patterns = rules.get_win_patterns()
	move_history.clear()
	for p in range(1, rules.num_players + 1):
		move_history[p] = [] as Array[int]
	global_history.clear()
	winning_pattern.clear()
	_undo_stack.clear()
	_redo_stack.clear()


func make_move(index: int) -> Dictionary:
	## Returns {success, removed_cell, winning_pattern (if game won)}
	var result = {"success": false, "removed_cell": -1}

	if game_over:
		return result
	if index < 0 or index >= cells.size():
		return result
	if cells[index] != EMPTY and not rules.allow_overwrite:
		return result

	# Save state for undo before modifying
	_undo_stack.append(get_state())
	_redo_stack.clear()

	var piece = current_turn
	var history: Array = move_history.get(piece, [])

	# Check rotation: remove oldest if at max
	if rules.max_pieces_per_player > 0 and history.size() >= rules.max_pieces_per_player:
		if rules.overflow_mode == "rotate":
			var oldest = history.pop_front()
			cells[oldest] = EMPTY
			result.removed_cell = oldest
		elif rules.overflow_mode == "block":
			_undo_stack.pop_back()  # Remove saved state since move failed
			return result

	cells[index] = piece
	history.append(index)
	move_history[piece] = history
	move_count += 1

	# Record in global history
	global_history.append({
		"player": piece,
		"cell": index,
		"move_number": move_count,
		"removed_cell": result.removed_cell,
	})

	var win_pat = _find_winning_pattern(piece)
	if not win_pat.is_empty():
		game_over = true
		winner = piece
		winning_pattern = win_pat
		result["winning_pattern"] = win_pat
	elif _check_draw():
		game_over = true
		winner = EMPTY
	else:
		_advance_turn()

	result.success = true
	return result


## Undo the last move. Returns true if successful.
func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	_redo_stack.append(get_state())
	var prev = _undo_stack.pop_back()
	load_state(prev)
	# Remove last global_history entry (it's part of the state but we restore separately)
	if not global_history.is_empty():
		global_history.pop_back()
	return true


## Redo a previously undone move. Returns true if successful.
func redo() -> bool:
	if _redo_stack.is_empty():
		return false
	_undo_stack.append(get_state())
	var next = _redo_stack.pop_back()
	load_state(next)
	return true


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func _advance_turn() -> void:
	current_turn = (current_turn % rules.num_players) + 1


func get_valid_moves() -> Array[int]:
	var moves: Array[int] = []
	for i in range(cells.size()):
		if cells[i] == EMPTY:
			moves.append(i)
		elif rules.allow_overwrite and cells[i] != current_turn:
			moves.append(i)
	return moves


func reset() -> void:
	var total = rules.get_total_cells()
	cells.resize(total)
	cells.fill(EMPTY)
	current_turn = 1
	game_over = false
	winner = EMPTY
	move_count = 0
	winning_pattern.clear()
	move_history.clear()
	for p in range(1, rules.num_players + 1):
		move_history[p] = [] as Array[int]
	global_history.clear()
	_undo_stack.clear()
	_redo_stack.clear()


func get_state() -> Dictionary:
	var hist_copy := {}
	for p in move_history:
		hist_copy[p] = (move_history[p] as Array).duplicate()
	return {
		"cells": cells.duplicate(),
		"current_turn": current_turn,
		"game_over": game_over,
		"winner": winner,
		"move_count": move_count,
		"move_history": hist_copy,
		"winning_pattern": winning_pattern.duplicate(),
		"global_history": global_history.duplicate(true),
	}


func load_state(state: Dictionary) -> void:
	cells.assign(state.cells)
	current_turn = state.current_turn
	game_over = state.game_over
	winner = state.winner
	move_count = state.move_count
	winning_pattern.assign(state.get("winning_pattern", []))
	move_history.clear()
	var hist: Dictionary = state.get("move_history", {})
	for p in hist:
		move_history[p] = (hist[p] as Array).duplicate()
	global_history = state.get("global_history", []).duplicate(true)
	# Backward compat
	if move_history.is_empty() and state.has("move_history_x"):
		move_history[1] = (state.move_history_x as Array).duplicate()
		move_history[2] = (state.move_history_o as Array).duplicate()


func piece_to_string(piece: int) -> String:
	if piece >= 0 and piece < PIECE_LABELS.size():
		return PIECE_LABELS[piece]
	return "P%d" % piece


static func piece_color(piece: int) -> Color:
	if piece >= 0 and piece < PIECE_COLORS.size():
		return PIECE_COLORS[piece]
	return Color.WHITE


func get_all_players() -> Array[int]:
	var players: Array[int] = []
	for p in range(1, rules.num_players + 1):
		players.append(p)
	return players


## Returns all near-win situations for a player.
## Each entry: {pattern: Array[int], missing_cell: int}
func get_near_wins(piece: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for pattern in _win_patterns:
		var piece_count := 0
		var empty_count := 0
		var empty_cell := -1
		for idx in pattern:
			if cells[idx] == piece:
				piece_count += 1
			elif cells[idx] == EMPTY:
				empty_count += 1
				empty_cell = idx
		if piece_count == rules.win_length - 1 and empty_count == 1:
			results.append({"pattern": Array(pattern, TYPE_INT, "", null), "missing_cell": empty_cell})
	return results


func detect_patterns(last_move: int, piece: int) -> Array[String]:
	var patterns: Array[String] = []
	var s = rules.board_size

	# Center taken
	if s % 2 == 1:
		var center = (s * s) / 2
		if last_move == center:
			patterns.append("center_taken_by_%d" % piece)
			if rules.num_players == 2:
				patterns.append("center_taken_by_%s" % ("player" if piece == 1 else "opponent"))

	# Corner taken
	var corners = [0, s - 1, s * (s - 1), s * s - 1]
	if last_move in corners:
		patterns.append("corner_taken_by_%d" % piece)
		if rules.num_players == 2:
			patterns.append("corner_taken_by_%s" % ("player" if piece == 1 else "opponent"))

	# Near win per player (with detail)
	for p in get_all_players():
		var near = get_near_wins(p)
		if not near.is_empty():
			patterns.append("player_%d_near_win" % p)
	if rules.num_players == 2:
		if _has_near_win(1):
			patterns.append("player_near_win")
		if _has_near_win(2):
			patterns.append("opponent_near_win")

	# Fork
	var near_count = get_near_wins(piece).size()
	if near_count >= 2:
		patterns.append("player_%d_fork" % piece)
		if rules.num_players == 2:
			patterns.append("%s_fork" % ("player" if piece == 1 else "opponent"))

	# Move count
	patterns.append("move_count_%d" % move_count)

	# Rotation
	if rules.max_pieces_per_player > 0:
		var hist: Array = move_history.get(piece, [])
		if hist.size() >= rules.max_pieces_per_player:
			patterns.append("player_%d_piece_rotated" % piece)
			if rules.num_players == 2:
				patterns.append("%s_piece_rotated" % ("player" if piece == 1 else "opponent"))

	return patterns


## Find the winning pattern for a piece. Returns the cell indices or empty array.
func _find_winning_pattern(piece: int) -> Array[int]:
	for pattern in _win_patterns:
		var all_match := true
		for idx in pattern:
			if cells[idx] != piece:
				all_match = false
				break
		if all_match:
			var result: Array[int] = []
			result.assign(pattern)
			return result
	return [] as Array[int]


func _check_winner(piece: int) -> bool:
	return not _find_winning_pattern(piece).is_empty()


func _check_draw() -> bool:
	if not rules.allow_draw:
		return false
	for cell in cells:
		if cell == EMPTY:
			return false
	return true


func _has_near_win(piece: int) -> bool:
	return not get_near_wins(piece).is_empty()


func _count_near_wins(piece: int) -> int:
	return get_near_wins(piece).size()
