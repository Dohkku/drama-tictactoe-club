class_name AIPlayer
extends RefCounted

const BL = preload("res://board/board_logic.gd")

var difficulty: float = 0.5


func choose_move(board) -> int:
	var valid_moves = board.get_valid_moves()
	if valid_moves.is_empty():
		return -1

	if randf() > difficulty:
		return valid_moves[randi() % valid_moves.size()]

	return _minimax_best_move(board)


func _minimax_best_move(board) -> int:
	var best_score := -999
	var best_move := -1
	var ai_piece = board.current_turn

	for move in board.get_valid_moves():
		board.cells[move] = ai_piece
		board.move_count += 1
		var score := _minimax(board, 0, false, ai_piece)
		board.cells[move] = BL.Piece.EMPTY
		board.move_count -= 1

		if score > best_score:
			best_score = score
			best_move = move

	return best_move


func _minimax(board, depth: int, is_maximizing: bool, ai_piece: int) -> int:
	var opponent_piece = BL.Piece.X if ai_piece == BL.Piece.O else BL.Piece.O

	if board._check_winner(ai_piece):
		return 10 - depth
	if board._check_winner(opponent_piece):
		return depth - 10
	if board.move_count >= board.cells.size():
		return 0

	if is_maximizing:
		var best := -999
		for move in board.get_valid_moves():
			board.cells[move] = ai_piece
			board.move_count += 1
			best = max(best, _minimax(board, depth + 1, false, ai_piece))
			board.cells[move] = BL.Piece.EMPTY
			board.move_count -= 1
		return best
	else:
		var best := 999
		for move in board.get_valid_moves():
			board.cells[move] = opponent_piece
			board.move_count += 1
			best = min(best, _minimax(board, depth + 1, true, ai_piece))
			board.cells[move] = BL.Piece.EMPTY
			board.move_count -= 1
		return best
