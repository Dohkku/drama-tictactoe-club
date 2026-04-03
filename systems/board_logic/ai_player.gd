class_name AIPlayer
extends RefCounted

## AI player using paranoid minimax search.
## For N players: maximizes own score, treats ALL other players as adversaries.

var difficulty: float = 0.5
var max_search_depth_override: int = -1

const WIN_SCORE := 10000


func choose_move(board) -> int:
	var valid_moves = board.get_valid_moves()
	if valid_moves.is_empty():
		return -1

	# Random chance based on difficulty (lower difficulty = more random)
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
		var score := _minimax(board, 1, ai_piece, max_depth)
		board.load_state(snapshot)

		if score > best_score:
			best_score = score
			best_move = move

	return best_move


func _minimax(board, depth: int, ai_piece: int, max_depth: int) -> int:
	## Paranoid search: maximize when it's AI's turn, minimize for ALL other players.
	if board.game_over:
		return _score_game_over(board, ai_piece, depth)
	if depth >= max_depth:
		return _evaluate_position(board, ai_piece)

	var is_ai_turn: bool = (board.current_turn == ai_piece)

	if is_ai_turn:
		var best := -WIN_SCORE * 2
		for move in board.get_valid_moves():
			var snapshot = board.get_state()
			var move_result = board.make_move(move)
			if move_result.success:
				best = maxi(best, _minimax(board, depth + 1, ai_piece, max_depth))
			board.load_state(snapshot)
		if best <= -WIN_SCORE * 2:
			return _evaluate_position(board, ai_piece)
		return best
	else:
		# Any opponent's turn: minimize AI's score (paranoid assumption)
		var best := WIN_SCORE * 2
		for move in board.get_valid_moves():
			var snapshot = board.get_state()
			var move_result = board.make_move(move)
			if move_result.success:
				best = mini(best, _minimax(board, depth + 1, ai_piece, max_depth))
			board.load_state(snapshot)
		if best >= WIN_SCORE * 2:
			return _evaluate_position(board, ai_piece)
		return best


func _score_game_over(board, ai_piece: int, depth: int) -> int:
	if board.winner == ai_piece:
		return WIN_SCORE - depth
	if board.winner != 0:  # Some other player won = bad for AI
		return depth - WIN_SCORE
	return 0  # Draw


func _evaluate_position(board, ai_piece: int) -> int:
	var score := 0
	var win_length: int = board.rules.win_length

	# Tactical: near wins for AI vs near wins for any opponent
	score += board._count_near_wins(ai_piece) * 90
	for p in board.get_all_players():
		if p != ai_piece:
			score -= board._count_near_wins(p) * 110

	# Strategic: line control
	for pattern in board.rules.get_win_patterns():
		var ai_count := 0
		var opponent_count := 0
		for idx in pattern:
			if board.cells[idx] == ai_piece:
				ai_count += 1
			elif board.cells[idx] != 0:
				opponent_count += 1

		if ai_count > 0 and opponent_count > 0:
			continue
		if ai_count > 0:
			score += _line_score(ai_count, win_length)
		elif opponent_count > 0:
			score -= _line_score(opponent_count, win_length)

	# Favor center on odd boards
	var bsize = board.rules.board_size
	if bsize % 2 == 1:
		var center = int((bsize * bsize) / 2)
		if board.cells[center] == ai_piece:
			score += 8
		elif board.cells[center] != 0:
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

	var cell_count = board.cells.size()
	var np = board.rules.num_players

	# More players = shallower search (branching factor stays same but game tree is deeper)
	var base_depth: int
	if cell_count <= 9 and np == 2 and board.rules.max_pieces_per_player <= 0:
		return 9  # Solve 3x3 2-player completely
	elif cell_count <= 9:
		base_depth = 5
	elif cell_count <= 16:
		base_depth = 4
	else:
		base_depth = 3

	# Reduce depth for more players (game tree grows)
	if np > 2:
		base_depth = max(2, base_depth - (np - 2))

	if board.rules.max_pieces_per_player > 0:
		base_depth = min(base_depth, 4)

	var bonus = int(round(difficulty * 2.0))
	return clampi(base_depth + bonus, 2, 7)
