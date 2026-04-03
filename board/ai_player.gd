class_name AIPlayer
extends RefCounted

const BL = preload("res://board/board_logic.gd")

var difficulty: float = 0.5
var max_search_depth_override: int = -1

const WIN_SCORE := 10000


func choose_move(board) -> int:
	var valid_moves = board.get_valid_moves()
	if valid_moves.is_empty():
		return -1

	if randf() > difficulty:
		return valid_moves[randi() % valid_moves.size()]

	var best_move = _minimax_best_move(board)
	if best_move < 0:
		return valid_moves[randi() % valid_moves.size()]
	return best_move


func _minimax_best_move(board) -> int:
	var best_score := -WIN_SCORE * 2
	var best_move := -1
	var ai_piece: int = board.current_turn
	var max_depth := _resolve_max_depth(board)

	for move in board.get_valid_moves():
		var snapshot = board.get_state()
		var move_result = board.make_move(move)
		if not move_result.success:
			board.load_state(snapshot)
			continue
		var score := _minimax(board, 1, false, ai_piece, max_depth)
		board.load_state(snapshot)

		if score > best_score:
			best_score = score
			best_move = move

	return best_move


func _minimax(board, depth: int, is_maximizing: bool, ai_piece: int, max_depth: int) -> int:
	if board.game_over:
		return _score_game_over(board, ai_piece, depth)
	if depth >= max_depth:
		return _evaluate_position(board, ai_piece)

	if is_maximizing:
		var best := -WIN_SCORE * 2
		for move in board.get_valid_moves():
			var snapshot = board.get_state()
			var move_result = board.make_move(move)
			if move_result.success:
				best = maxi(best, _minimax(board, depth + 1, false, ai_piece, max_depth))
			board.load_state(snapshot)
		if best <= -WIN_SCORE * 2:
			return _evaluate_position(board, ai_piece)
		return best
	else:
		var best := WIN_SCORE * 2
		for move in board.get_valid_moves():
			var snapshot = board.get_state()
			var move_result = board.make_move(move)
			if move_result.success:
				best = mini(best, _minimax(board, depth + 1, true, ai_piece, max_depth))
			board.load_state(snapshot)
		if best >= WIN_SCORE * 2:
			return _evaluate_position(board, ai_piece)
		return best


func _score_game_over(board, ai_piece: int, depth: int) -> int:
	var opponent_piece = BL.Piece.X if ai_piece == BL.Piece.O else BL.Piece.O
	if board.winner == ai_piece:
		return WIN_SCORE - depth
	if board.winner == opponent_piece:
		return depth - WIN_SCORE
	return 0


func _evaluate_position(board, ai_piece: int) -> int:
	var opponent_piece = BL.Piece.X if ai_piece == BL.Piece.O else BL.Piece.O
	var score := 0

	# Tactical pressure: near wins and near losses.
	score += board._count_near_wins(ai_piece) * 90
	score -= board._count_near_wins(opponent_piece) * 110

	# Strategic pressure: open lines with only one owner.
	var win_length: int = board.rules.win_length
	for pattern in board.rules.get_win_patterns():
		var ai_count := 0
		var opponent_count := 0
		for idx in pattern:
			if board.cells[idx] == ai_piece:
				ai_count += 1
			elif board.cells[idx] == opponent_piece:
				opponent_count += 1

		if ai_count > 0 and opponent_count > 0:
			continue
		if ai_count > 0:
			score += _line_score(ai_count, win_length)
		elif opponent_count > 0:
			score -= _line_score(opponent_count, win_length)

	# Favor center on odd boards.
	var size = board.rules.board_size
	if size % 2 == 1:
		var center = int((size * size) / 2)
		if board.cells[center] == ai_piece:
			score += 8
		elif board.cells[center] == opponent_piece:
			score -= 8

	return score


func _line_score(piece_count: int, win_length: int) -> int:
	if piece_count <= 0:
		return 0
	if piece_count >= win_length - 1:
		return 80
	return int(pow(3.0, piece_count)) * 4


func _resolve_max_depth(board) -> int:
	if max_search_depth_override > 0:
		return max_search_depth_override

	# Standard 3x3 tic-tac-toe can be solved to terminal states cheaply.
	var is_standard_small = (
		board.cells.size() <= 9
		and board.rules.max_pieces_per_player <= 0
		and not board.rules.allow_overwrite
	)
	if is_standard_small:
		return 9

	var base_depth: int
	if board.cells.size() <= 9:
		base_depth = 6
	elif board.cells.size() <= 16:
		base_depth = 4
	else:
		base_depth = 3

	# Rotating/overflow boards can cycle forever; cap a bit lower.
	if board.rules.max_pieces_per_player > 0:
		base_depth = min(base_depth, 5)

	var bonus = int(round(difficulty * 2.0))
	return clampi(base_depth + bonus, 2, 8)
