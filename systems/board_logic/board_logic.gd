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

## Move history per player: { player_id: Array[int] of cell indices }
var move_history: Dictionary = {}

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


func make_move(index: int) -> Dictionary:
	## Returns {success: bool, removed_cell: int (-1 if none)}
	var result = {"success": false, "removed_cell": -1}

	if game_over:
		return result
	if index < 0 or index >= cells.size():
		return result
	if cells[index] != EMPTY and not rules.allow_overwrite:
		return result

	var piece = current_turn
	var history: Array = move_history.get(piece, [])

	# Check rotation: remove oldest if at max
	if rules.max_pieces_per_player > 0 and history.size() >= rules.max_pieces_per_player:
		if rules.overflow_mode == "rotate":
			var oldest = history.pop_front()
			cells[oldest] = EMPTY
			result.removed_cell = oldest
		elif rules.overflow_mode == "block":
			return result

	cells[index] = piece
	history.append(index)
	move_history[piece] = history
	move_count += 1

	if _check_winner(piece):
		game_over = true
		winner = piece
	elif _check_draw():
		game_over = true
		winner = EMPTY
	else:
		_advance_turn()

	result.success = true
	return result


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
	move_history.clear()
	for p in range(1, rules.num_players + 1):
		move_history[p] = [] as Array[int]


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
	}


func load_state(state: Dictionary) -> void:
	cells.assign(state.cells)
	current_turn = state.current_turn
	game_over = state.game_over
	winner = state.winner
	move_count = state.move_count
	move_history.clear()
	var hist: Dictionary = state.get("move_history", {})
	for p in hist:
		move_history[p] = (hist[p] as Array).duplicate()
	# Backward compat: old saves with move_history_x / move_history_o
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


func detect_patterns(last_move: int, piece: int) -> Array[String]:
	var patterns: Array[String] = []
	var s = rules.board_size

	# Center taken (only for odd-sized boards)
	if s % 2 == 1:
		var center = (s * s) / 2
		if last_move == center:
			patterns.append("center_taken_by_%d" % piece)
			# 2-player compat
			if rules.num_players == 2:
				patterns.append("center_taken_by_%s" % ("player" if piece == 1 else "opponent"))

	# Corner taken
	var corners = [0, s - 1, s * (s - 1), s * s - 1]
	if last_move in corners:
		patterns.append("corner_taken_by_%d" % piece)
		if rules.num_players == 2:
			patterns.append("corner_taken_by_%s" % ("player" if piece == 1 else "opponent"))

	# Near win per player
	for p in get_all_players():
		if _has_near_win(p):
			patterns.append("player_%d_near_win" % p)
	# 2-player compat
	if rules.num_players == 2:
		if _has_near_win(1):
			patterns.append("player_near_win")
		if _has_near_win(2):
			patterns.append("opponent_near_win")

	# Fork
	if _count_near_wins(piece) >= 2:
		patterns.append("player_%d_fork" % piece)
		if rules.num_players == 2:
			patterns.append("%s_fork" % ("player" if piece == 1 else "opponent"))

	# Move count
	patterns.append("move_count_%d" % move_count)

	# Rotation happened
	if rules.max_pieces_per_player > 0:
		var history: Array = move_history.get(piece, [])
		if history.size() >= rules.max_pieces_per_player:
			patterns.append("player_%d_piece_rotated" % piece)
			if rules.num_players == 2:
				patterns.append("%s_piece_rotated" % ("player" if piece == 1 else "opponent"))

	return patterns


func _check_winner(piece: int) -> bool:
	for pattern in _win_patterns:
		var all_match := true
		for idx in pattern:
			if cells[idx] != piece:
				all_match = false
				break
		if all_match:
			return true
	return false


func _check_draw() -> bool:
	if not rules.allow_draw:
		return false
	for cell in cells:
		if cell == EMPTY:
			return false
	return true


func _has_near_win(piece: int) -> bool:
	return _count_near_wins(piece) > 0


func _count_near_wins(piece: int) -> int:
	var count := 0
	for pattern in _win_patterns:
		var piece_count := 0
		var empty_count := 0
		for idx in pattern:
			if cells[idx] == piece:
				piece_count += 1
			elif cells[idx] == EMPTY:
				empty_count += 1
		if piece_count == rules.win_length - 1 and empty_count == 1:
			count += 1
	return count
