class_name BoardLogic
extends RefCounted

const GameRulesScript = preload("res://board/game_rules.gd")

enum Piece { EMPTY = 0, X = 1, O = 2 }

var rules: Resource  # GameRules
var cells: Array[int] = []
var current_turn: int = Piece.X
var game_over: bool = false
var winner: int = Piece.EMPTY
var move_count: int = 0

# Track move order per player for rotation mode
var move_history_x: Array[int] = []  # cell indices in order placed
var move_history_o: Array[int] = []

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
	cells.fill(Piece.EMPTY)
	_win_patterns = rules.get_win_patterns()


func make_move(index: int) -> Dictionary:
	## Returns {success: bool, removed_cell: int (-1 if none)}
	var result = {"success": false, "removed_cell": -1}

	if game_over:
		return result
	if index < 0 or index >= cells.size():
		return result
	if cells[index] != Piece.EMPTY and not rules.allow_overwrite:
		return result

	var piece = current_turn
	var history = move_history_x if piece == Piece.X else move_history_o

	# Check rotation: remove oldest if at max
	if rules.max_pieces_per_player > 0 and history.size() >= rules.max_pieces_per_player:
		if rules.overflow_mode == "rotate":
			var oldest = history.pop_front()
			cells[oldest] = Piece.EMPTY
			result.removed_cell = oldest
		elif rules.overflow_mode == "block":
			return result  # Can't place

	cells[index] = piece
	history.append(index)
	move_count += 1

	if _check_winner(piece):
		game_over = true
		winner = piece
	elif _check_draw():
		game_over = true
		winner = Piece.EMPTY
	else:
		current_turn = Piece.O if current_turn == Piece.X else Piece.X

	result.success = true
	return result


func get_valid_moves() -> Array[int]:
	var moves: Array[int] = []
	for i in range(cells.size()):
		if cells[i] == Piece.EMPTY:
			moves.append(i)
		elif rules.allow_overwrite and cells[i] != current_turn:
			moves.append(i)
	return moves


func reset() -> void:
	var total = rules.get_total_cells()
	cells.resize(total)
	cells.fill(Piece.EMPTY)
	current_turn = Piece.X
	game_over = false
	winner = Piece.EMPTY
	move_count = 0
	move_history_x.clear()
	move_history_o.clear()


func piece_to_string(piece: int) -> String:
	match piece:
		Piece.X: return "X"
		Piece.O: return "O"
		_: return ""


func detect_patterns(last_move: int, piece: int) -> Array[String]:
	var patterns: Array[String] = []
	var piece_name := "player" if piece == Piece.X else "opponent"
	var s = rules.board_size

	# Center taken (only for odd-sized boards)
	if s % 2 == 1:
		var center = (s * s) / 2
		if last_move == center:
			patterns.append("center_taken_by_%s" % piece_name)

	# Corner taken
	var corners = [0, s - 1, s * (s - 1), s * s - 1]
	if last_move in corners:
		patterns.append("corner_taken_by_%s" % piece_name)

	# Near win
	if _has_near_win(Piece.X):
		patterns.append("player_near_win")
	if _has_near_win(Piece.O):
		patterns.append("opponent_near_win")

	# Fork
	if _count_near_wins(piece) >= 2:
		patterns.append("%s_fork" % piece_name)

	# Move count
	patterns.append("move_count_%d" % move_count)

	# Rotation happened
	if rules.max_pieces_per_player > 0:
		var history = move_history_x if piece == Piece.X else move_history_o
		if history.size() >= rules.max_pieces_per_player:
			patterns.append("%s_piece_rotated" % piece_name)

	return patterns


func _check_winner(piece: int) -> bool:
	for pattern in _win_patterns:
		var match_count := true
		for idx in pattern:
			if cells[idx] != piece:
				match_count = false
				break
		if match_count:
			return true
	return false


func _check_draw() -> bool:
	if not rules.allow_draw:
		return false
	for cell in cells:
		if cell == Piece.EMPTY:
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
			elif cells[idx] == Piece.EMPTY:
				empty_count += 1
		if piece_count == rules.win_length - 1 and empty_count == 1:
			count += 1
	return count
