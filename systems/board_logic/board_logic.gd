class_name BoardLogic
extends RefCounted

## Pure game logic for N-player tic-tac-toe.
## Players: 0 = empty, -1 = blocked, 1..N = players.

const GameRulesScript = preload("res://systems/board_logic/game_rules.gd")
const MoveResultScript = preload("res://systems/board_logic/move_result.gd")

const EMPTY := 0
const BLOCKED := -1

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

var rules: Resource
var cells: Array[int] = []
var current_turn: int = 1
var game_over: bool = false
var winner: int = EMPTY
var move_count: int = 0
var winning_pattern: Array[int] = []
var move_history: Dictionary = {}
var global_history: Array[Dictionary] = []
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _win_patterns: Array = []
var _skip_next_turn: bool = false


func _init(custom_rules: Resource = null) -> void:
	rules = custom_rules if custom_rules else GameRulesScript.new()
	_setup()


func _setup() -> void:
	var total = rules.get_total_cells()
	cells.resize(total)
	cells.fill(EMPTY)
	# Mark blocked cells
	for idx in rules.blocked_cells:
		if idx >= 0 and idx < total:
			cells[idx] = BLOCKED
	_win_patterns = rules.get_win_patterns()
	move_history.clear()
	for p in range(1, rules.num_players + 1):
		move_history[p] = [] as Array[int]
	global_history.clear()
	winning_pattern.clear()
	_undo_stack.clear()
	_redo_stack.clear()
	_skip_next_turn = false


func make_move(index: int) -> RefCounted:
	## Returns MoveResult with success status and all events that occurred.
	var result = MoveResultScript.new()

	if game_over or index < 0 or index >= cells.size():
		return result
	if cells[index] == BLOCKED:
		return result
	if cells[index] != EMPTY and not rules.allow_overwrite:
		return result

	_undo_stack.append(get_state())
	_redo_stack.clear()

	var piece = current_turn
	result.player = piece
	result.cell = index
	var history: Array = move_history.get(piece, [])

	# Rotation
	if rules.max_pieces_per_player > 0 and history.size() >= rules.max_pieces_per_player:
		if rules.overflow_mode == "rotate":
			var oldest = history.pop_front()
			cells[oldest] = EMPTY
			result.removed_cell = oldest
			result.add_event(MoveResultScript.PIECE_ROTATED, {
				"player": piece, "removed_cell": oldest, "new_cell": index
			})
		elif rules.overflow_mode == "block":
			_undo_stack.pop_back()
			return result

	# Place piece
	cells[index] = piece
	history.append(index)
	move_history[piece] = history
	move_count += 1
	result.success = true
	result.add_event(MoveResultScript.PIECE_PLACED, {"player": piece, "cell": index})

	# Record global history
	global_history.append({
		"player": piece, "cell": index,
		"move_number": move_count, "removed_cell": result.removed_cell,
	})

	# Special cell effects
	var special = rules.get_special_cell(index)
	if not special.is_empty():
		var effect = _apply_special_cell(special, piece)
		result.add_event(MoveResultScript.SPECIAL_CELL, {
			"cell": index, "type": special.get("type", ""), "effect": effect
		})

	# Detect positional events
	_detect_events(result, index, piece)

	# Check win/draw
	var win_pat = _find_winning_pattern(piece)
	if not win_pat.is_empty():
		game_over = true
		winner = piece
		winning_pattern = win_pat
		result.is_win = true
		result.winning_pattern = win_pat
		result.add_event(MoveResultScript.WIN, {"player": piece, "pattern": win_pat})
	elif _check_most_pieces_win():
		pass  # handled inside _check_most_pieces_win
	elif _check_draw():
		game_over = true
		winner = EMPTY
		result.is_draw = true
		result.add_event(MoveResultScript.DRAW, {})
	else:
		var prev_turn = current_turn
		_advance_turn()
		result.add_event(MoveResultScript.TURN_CHANGED, {"from": prev_turn, "to": current_turn})

	return result


func _detect_events(result: RefCounted, index: int, piece: int) -> void:
	var w = rules.get_width()
	var h = rules.get_height()

	# Center
	if w % 2 == 1 and h % 2 == 1:
		var center = (h / 2) * w + (w / 2)
		if index == center:
			result.add_event(MoveResultScript.CENTER_TAKEN, {"player": piece})

	# Corner
	var corners = rules.get_corners()
	if index in corners:
		result.add_event(MoveResultScript.CORNER_TAKEN, {"player": piece})

	# Near wins for all players
	for p in get_all_players():
		var nears = get_near_wins(p)
		for nw in nears:
			result.add_event(MoveResultScript.NEAR_WIN, {
				"player": p, "pattern": nw.pattern, "missing_cell": nw.missing_cell
			})

	# Forks
	for p in get_all_players():
		var fork_count = get_near_wins(p).size()
		if fork_count >= 2:
			result.add_event(MoveResultScript.FORK, {"player": p, "count": fork_count})


func _apply_special_cell(special: Dictionary, piece: int) -> String:
	var cell_type = special.get("type", "")
	match cell_type:
		"bonus":
			_skip_next_turn = true  # Will skip the advance_turn
			return "extra_turn"
		"trap":
			# After this player's turn, skip the NEXT player
			# Handled in _advance_turn
			_skip_next_turn = true
			return "skip_opponent"
	return ""


func _advance_turn() -> void:
	current_turn = (current_turn % rules.num_players) + 1
	if _skip_next_turn:
		_skip_next_turn = false
		# Skip this player's turn (advance again)
		current_turn = (current_turn % rules.num_players) + 1


func _check_most_pieces_win() -> bool:
	if rules.win_condition != "most_pieces":
		return false
	# Check if board is full (excluding blocked)
	for c in cells:
		if c == EMPTY:
			return false
	# Count pieces per player
	var counts := {}
	for p in get_all_players():
		counts[p] = 0
	for c in cells:
		if c > 0 and counts.has(c):
			counts[c] += 1
	# Find max
	var max_count := 0
	var max_player := 0
	for p in counts:
		if counts[p] > max_count:
			max_count = counts[p]
			max_player = p
	game_over = true
	winner = max_player
	winning_pattern.clear()
	return true


# --- Public API ---

func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	_redo_stack.append(get_state())
	load_state(_undo_stack.pop_back())
	if not global_history.is_empty():
		global_history.pop_back()
	return true

func redo() -> bool:
	if _redo_stack.is_empty():
		return false
	_undo_stack.append(get_state())
	load_state(_redo_stack.pop_back())
	return true

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func get_valid_moves() -> Array[int]:
	var moves: Array[int] = []
	for i in range(cells.size()):
		if cells[i] == EMPTY:
			moves.append(i)
		elif rules.allow_overwrite and cells[i] > 0 and cells[i] != current_turn:
			moves.append(i)
	return moves

func reset() -> void:
	_setup()
	current_turn = 1
	game_over = false
	winner = EMPTY
	move_count = 0

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
		"skip_next_turn": _skip_next_turn,
	}

func load_state(state: Dictionary) -> void:
	cells.assign(state.cells)
	current_turn = state.current_turn
	game_over = state.game_over
	winner = state.winner
	move_count = state.move_count
	winning_pattern.assign(state.get("winning_pattern", []))
	_skip_next_turn = state.get("skip_next_turn", false)
	move_history.clear()
	for p in state.get("move_history", {}):
		move_history[p] = (state.move_history[p] as Array).duplicate()
	global_history = state.get("global_history", []).duplicate(true)
	if move_history.is_empty() and state.has("move_history_x"):
		move_history[1] = (state.move_history_x as Array).duplicate()
		move_history[2] = (state.move_history_o as Array).duplicate()

func piece_to_string(piece: int) -> String:
	if piece == BLOCKED: return "■"
	if piece >= 0 and piece < PIECE_LABELS.size(): return PIECE_LABELS[piece]
	return "P%d" % piece

static func piece_color(piece: int) -> Color:
	if piece >= 0 and piece < PIECE_COLORS.size(): return PIECE_COLORS[piece]
	return Color.WHITE

func get_all_players() -> Array[int]:
	var players: Array[int] = []
	for p in range(1, rules.num_players + 1):
		players.append(p)
	return players

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
	## Legacy compatibility — returns string pattern names.
	var patterns: Array[String] = []
	var w = rules.get_width()
	var h = rules.get_height()
	if w % 2 == 1 and h % 2 == 1:
		var center = (h / 2) * w + (w / 2)
		if last_move == center:
			patterns.append("center_taken_by_%d" % piece)
			if rules.num_players == 2:
				patterns.append("center_taken_by_%s" % ("player" if piece == 1 else "opponent"))
	var corners = rules.get_corners()
	if last_move in corners:
		patterns.append("corner_taken_by_%d" % piece)
		if rules.num_players == 2:
			patterns.append("corner_taken_by_%s" % ("player" if piece == 1 else "opponent"))
	for p in get_all_players():
		if not get_near_wins(p).is_empty():
			patterns.append("player_%d_near_win" % p)
	if rules.num_players == 2:
		if not get_near_wins(1).is_empty(): patterns.append("player_near_win")
		if not get_near_wins(2).is_empty(): patterns.append("opponent_near_win")
	if get_near_wins(piece).size() >= 2:
		patterns.append("player_%d_fork" % piece)
		if rules.num_players == 2:
			patterns.append("%s_fork" % ("player" if piece == 1 else "opponent"))
	patterns.append("move_count_%d" % move_count)
	if rules.max_pieces_per_player > 0:
		var hist: Array = move_history.get(piece, [])
		if hist.size() >= rules.max_pieces_per_player:
			patterns.append("player_%d_piece_rotated" % piece)
			if rules.num_players == 2:
				patterns.append("%s_piece_rotated" % ("player" if piece == 1 else "opponent"))
	return patterns


func _find_winning_pattern(piece: int) -> Array[int]:
	for pattern in _win_patterns:
		var all_match := true
		for idx in pattern:
			var cell_val = cells[idx]
			# "wild" special cells count as any player
			if cell_val == piece:
				continue
			if rules.get_special_cell(idx).get("type", "") == "wild" and cell_val > 0:
				continue
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
	if not rules.allow_draw: return false
	if rules.win_condition == "most_pieces": return false
	for cell in cells:
		if cell == EMPTY: return false
	return true

func _has_near_win(piece: int) -> bool:
	return not get_near_wins(piece).is_empty()

func _count_near_wins(piece: int) -> int:
	return get_near_wins(piece).size()
