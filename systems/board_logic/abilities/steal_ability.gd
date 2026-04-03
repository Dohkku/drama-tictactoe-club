extends "res://systems/board_logic/abilities/special_ability.gd"

## "Steal" — Convert one of an opponent's pieces to yours.
## Can only be used once per match, and only if an opponent has at least one piece.
## Supports N-player games: steals from any opponent, not just player 2.


func _init() -> void:
	ability_name = "Robo"
	description = "Convierte una pieza del oponente en tuya"
	uses_per_match = 1


func _can_use_impl(board_logic, _board_state: Dictionary) -> bool:
	# Need at least one opponent piece on the board
	var current = board_logic.current_turn
	for cell in board_logic.cells:
		if cell > 0 and cell != current:
			return true
	return false


func _apply_impl(board_logic, _board_state: Dictionary) -> Dictionary:
	var current = board_logic.current_turn

	# Find all opponent pieces (any player that isn't current)
	var opponent_cells: Array[int] = []
	for i in range(board_logic.cells.size()):
		var cv = board_logic.cells[i]
		if cv > 0 and cv != current:
			opponent_cells.append(i)

	if opponent_cells.is_empty():
		return {}

	# Steal a random opponent piece
	var target = opponent_cells[randi() % opponent_cells.size()]
	var from_piece = board_logic.cells[target]
	board_logic.cells[target] = current

	return {
		"type": "steal",
		"cells_affected": [target],
		"from_piece": from_piece,
		"to_piece": current,
		"description": "¡Pieza robada en casilla %d!" % target,
	}
