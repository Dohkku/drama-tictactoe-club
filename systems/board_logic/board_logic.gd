class_name BoardLogic
extends RefCounted

## Pure game logic for N-player tic-tac-toe.
## Cells: 0 = empty, -1 = blocked, 1..N = players.
## Returns MoveResult from make_move() with typed events for other systems.

const GameRulesScript = preload("res://systems/board_logic/game_rules.gd")
const MoveResultScript = preload("res://systems/board_logic/move_result.gd")

const EMPTY := 0
const BLOCKED := -1

const PIECE_LABELS := ["", "X", "O", "△", "□", "◇", "★"]
const PIECE_COLORS := [
	Color.TRANSPARENT,
	Color(0.3, 0.6, 1.0),
	Color(1.0, 0.3, 0.3),
	Color(0.3, 0.9, 0.4),
	Color(0.8, 0.3, 0.9),
	Color(1.0, 0.6, 0.2),
	Color(0.2, 0.9, 0.9),
]

enum SpecialEffect { NONE, EXTRA_TURN, SKIP_NEXT }

var rules: Resource
var cells: Array[int] = []
var current_turn: int = 1
var game_over: bool = false
var winner: int = EMPTY
var move_count: int = 0
var winning_pattern: Array[int] = []
var move_history: Dictionary = {}     # {player_id: Array[int]}
var global_history: Array[Dictionary] = []
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _win_patterns: Array = []
var _pending_effect: int = SpecialEffect.NONE


func _init(custom_rules: Resource = null) -> void:
	rules = custom_rules if custom_rules else GameRulesScript.new()
	_setup()


func _setup() -> void:
	cells.resize(rules.get_total_cells())
	cells.fill(EMPTY)
	for idx in rules.blocked_cells:
		if idx >= 0 and idx < cells.size():
			cells[idx] = BLOCKED
	_win_patterns = rules.get_win_patterns()
	move_history.clear()
	for p in range(1, rules.num_players + 1):
		move_history[p] = [] as Array[int]
	global_history.clear()
	winning_pattern.clear()
	_undo_stack.clear()
	_redo_stack.clear()
	_pending_effect = SpecialEffect.NONE


## Execute a move. Returns MoveResult with success/failure and all events.
func make_move(index: int) -> RefCounted:
	var result = MoveResultScript.new()
	result.player = current_turn
	result.cell = index

	# Validate
	if game_over:
		result.fail_reason = "game_over"
		return result
	if index < 0 or index >= cells.size():
		result.fail_reason = "out_of_bounds"
		return result
	if cells[index] == BLOCKED:
		result.fail_reason = "blocked"
		return result
	if cells[index] != EMPTY and not rules.allow_overwrite:
		result.fail_reason = "occupied"
		return result

	# Save for undo
	_undo_stack.append(get_state())
	_redo_stack.clear()

	var piece := current_turn
	var history: Array = move_history.get(piece, [])

	# Rotation: remove oldest if at max
	if rules.max_pieces_per_player > 0 and history.size() >= rules.max_pieces_per_player:
		if rules.overflow_mode == GameRulesScript.OVERFLOW_ROTATE:
			var oldest: int = history.pop_front()
			cells[oldest] = EMPTY
			result.removed_cell = oldest
			result.add_event(MoveResultScript.PIECE_ROTATED, {
				"player": piece, "removed_cell": oldest, "new_cell": index,
			})
		else:  # block
			_undo_stack.pop_back()
			result.fail_reason = "max_pieces_blocked"
			return result

	# Place
	cells[index] = piece
	history.append(index)
	move_history[piece] = history
	move_count += 1
	result.success = true
	result.add_event(MoveResultScript.PIECE_PLACED, {"player": piece, "cell": index})

	# Global history
	global_history.append({
		"player": piece, "cell": index,
		"move_number": move_count, "removed_cell": result.removed_cell,
	})

	# Special cell effects
	var special = rules.get_special_cell(index)
	if not special.is_empty():
		_apply_special_cell(result, special, piece)

	# Detect positional events (near wins, forks, center/corner)
	_detect_events(result, index, piece)

	# Check victory
	var win_pat := _find_winning_pattern(piece)
	if not win_pat.is_empty():
		game_over = true
		winner = piece
		winning_pattern = win_pat
		result.is_win = true
		result.winning_pattern = win_pat
		result.add_event(MoveResultScript.WIN, {"player": piece, "pattern": win_pat})
	elif rules.win_condition == GameRulesScript.WIN_MOST_PIECES and _is_board_full():
		_resolve_most_pieces(result)
	elif _check_draw():
		game_over = true
		winner = EMPTY
		result.is_draw = true
		result.add_event(MoveResultScript.DRAW, {})
	else:
		var prev := current_turn
		_advance_turn(result)
		result.add_event(MoveResultScript.TURN_CHANGED, {"from": prev, "to": current_turn})

	return result


func _apply_special_cell(result: RefCounted, special: Dictionary, piece: int) -> void:
	var cell_type: String = special.get("type", "")
	match cell_type:
		GameRulesScript.SPECIAL_BONUS:
			_pending_effect = SpecialEffect.EXTRA_TURN
			result.add_event(MoveResultScript.BONUS_TURN, {"player": piece})
			result.add_event(MoveResultScript.SPECIAL_CELL, {
				"cell": result.cell, "type": cell_type, "effect": "extra_turn",
			})
		GameRulesScript.SPECIAL_TRAP:
			_pending_effect = SpecialEffect.SKIP_NEXT
			result.add_event(MoveResultScript.SKIP_TURN, {"player": piece})
			result.add_event(MoveResultScript.SPECIAL_CELL, {
				"cell": result.cell, "type": cell_type, "effect": "skip_opponent",
			})
		# "wild" has no active effect — handled in _find_winning_pattern


func _advance_turn(result: RefCounted) -> void:
	match _pending_effect:
		SpecialEffect.EXTRA_TURN:
			_pending_effect = SpecialEffect.NONE
			# Don't advance — same player goes again
		SpecialEffect.SKIP_NEXT:
			_pending_effect = SpecialEffect.NONE
			# Advance twice: skip the next player
			current_turn = (current_turn % rules.num_players) + 1
			current_turn = (current_turn % rules.num_players) + 1
		_:
			current_turn = (current_turn % rules.num_players) + 1


func _detect_events(result: RefCounted, index: int, piece: int) -> void:
	var w: int = rules.get_width()
	var h: int = rules.get_height()

	# Center
	if w % 2 == 1 and h % 2 == 1:
		if index == (h / 2) * w + (w / 2):
			result.add_event(MoveResultScript.CENTER_TAKEN, {"player": piece})

	# Corner
	if index in rules.get_corners():
		result.add_event(MoveResultScript.CORNER_TAKEN, {"player": piece})

	# Near wins + forks (cached per player to avoid duplicate work)
	for p in get_all_players():
		var nears := get_near_wins(p)
		for nw in nears:
			result.add_event(MoveResultScript.NEAR_WIN, {
				"player": p, "pattern": nw.pattern, "missing_cell": nw.missing_cell,
			})
		if nears.size() >= 2:
			result.add_event(MoveResultScript.FORK, {"player": p, "count": nears.size()})


func _resolve_most_pieces(result: RefCounted) -> void:
	var counts := {}
	for p in get_all_players():
		counts[p] = 0
	for c in cells:
		if c > 0 and counts.has(c):
			counts[c] += 1
	var best_player := 0
	var best_count := 0
	for p in counts:
		if counts[p] > best_count:
			best_count = counts[p]
			best_player = p
	game_over = true
	winner = best_player
	result.is_win = true
	result.add_event(MoveResultScript.WIN, {"player": best_player, "pattern": []})


func _is_board_full() -> bool:
	for c in cells:
		if c == EMPTY:
			return false
	return true


# ── Public API ──

func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	_redo_stack.append(get_state())
	load_state(_undo_stack.pop_back())
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
	current_turn = 1
	game_over = false
	winner = EMPTY
	move_count = 0
	_setup()


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
		"pending_effect": _pending_effect,
	}


func load_state(state: Dictionary) -> void:
	cells.assign(state.cells)
	current_turn = state.current_turn
	game_over = state.game_over
	winner = state.winner
	move_count = state.move_count
	winning_pattern.assign(state.get("winning_pattern", []))
	_pending_effect = state.get("pending_effect", SpecialEffect.NONE)
	move_history.clear()
	for p in state.get("move_history", {}):
		move_history[p] = (state.move_history[p] as Array).duplicate()
	global_history = state.get("global_history", []).duplicate(true)


func piece_to_string(piece: int) -> String:
	if piece == BLOCKED:
		return "■"
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


## Returns near-win situations: [{pattern: Array[int], missing_cell: int}]
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


## Legacy compat: returns string pattern names for the scene runner.
func detect_patterns(last_move: int, piece: int) -> Array[String]:
	var patterns: Array[String] = []
	var w: int = rules.get_width()
	var h: int = rules.get_height()
	if w % 2 == 1 and h % 2 == 1:
		if last_move == (h / 2) * w + (w / 2):
			patterns.append("center_taken_by_%d" % piece)
			if rules.num_players == 2:
				patterns.append("center_taken_by_%s" % ("player" if piece == 1 else "opponent"))
	if last_move in rules.get_corners():
		patterns.append("corner_taken_by_%d" % piece)
		if rules.num_players == 2:
			patterns.append("corner_taken_by_%s" % ("player" if piece == 1 else "opponent"))
	for p in get_all_players():
		if not get_near_wins(p).is_empty():
			patterns.append("player_%d_near_win" % p)
	if rules.num_players == 2:
		if not get_near_wins(1).is_empty():
			patterns.append("player_near_win")
		if not get_near_wins(2).is_empty():
			patterns.append("opponent_near_win")
	if get_near_wins(piece).size() >= 2:
		patterns.append("player_%d_fork" % piece)
		if rules.num_players == 2:
			patterns.append("%s_fork" % ("player" if piece == 1 else "opponent"))
	patterns.append("move_count_%d" % move_count)
	return patterns


func _find_winning_pattern(piece: int) -> Array[int]:
	for pattern in _win_patterns:
		var all_match := true
		for idx in pattern:
			var cv := cells[idx]
			if cv == piece:
				continue
			if rules.get_special_cell(idx).get("type", "") == GameRulesScript.SPECIAL_WILD and cv > 0:
				continue
			all_match = false
			break
		if all_match:
			var result: Array[int] = []
			result.assign(pattern)
			return result
	return [] as Array[int]


func _check_draw() -> bool:
	if not rules.allow_draw:
		return false
	if rules.win_condition == GameRulesScript.WIN_MOST_PIECES:
		return false
	return _is_board_full()


func _count_near_wins(piece: int) -> int:
	return get_near_wins(piece).size()
