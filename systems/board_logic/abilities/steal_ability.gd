extends Resource

## "Steal" — Convert one of the opponent's pieces to yours.
## Can only be used once per match, and only if the opponent has at least one piece.

const SpecialAbilityScript = preload("res://systems/board_logic/abilities/special_ability.gd")

var ability_name: String = "Robo"
var description: String = "Convierte una pieza del oponente en tuya"
var uses_per_match: int = 1
var _uses_remaining: int = 0


func reset() -> void:
	_uses_remaining = uses_per_match


func can_use(board_logic, _board_state: Dictionary) -> bool:
	if _uses_remaining <= 0:
		return false
	# Need at least one opponent piece on the board
	var opponent_piece = 1 if board_logic.current_turn == 2 else 2
	for cell in board_logic.cells:
		if cell == opponent_piece:
			return true
	return false


func apply(board_logic, _board_state: Dictionary) -> Dictionary:
	_uses_remaining -= 1
	var current = board_logic.current_turn
	var opponent = 1 if current == 2 else 2

	# Find opponent pieces
	var opponent_cells: Array[int] = []
	for i in range(board_logic.cells.size()):
		if board_logic.cells[i] == opponent:
			opponent_cells.append(i)

	if opponent_cells.is_empty():
		return {}

	# Steal a random opponent piece
	var target = opponent_cells[randi() % opponent_cells.size()]
	board_logic.cells[target] = current

	return {
		"type": "steal",
		"cells_affected": [target],
		"from_piece": opponent,
		"to_piece": current,
		"description": "¡Pieza robada en casilla %d!" % target,
	}
