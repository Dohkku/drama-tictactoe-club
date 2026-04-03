extends Resource

## "Double Play" — Place two pieces in one turn.
## The second piece must be placed on a valid cell.
## Can only be used once per match.

var ability_name: String = "Doble Jugada"
var description: String = "Coloca dos piezas en un solo turno"
var uses_per_match: int = 1
var _uses_remaining: int = 0


func reset() -> void:
	_uses_remaining = uses_per_match


func can_use(board_logic, _board_state: Dictionary) -> bool:
	if _uses_remaining <= 0:
		return false
	# Need at least 2 empty cells
	var empty_count := 0
	for cell in board_logic.cells:
		if cell == 0:
			empty_count += 1
	return empty_count >= 2


func apply(board_logic, _board_state: Dictionary) -> Dictionary:
	_uses_remaining -= 1

	# Grant an extra turn by NOT switching the current turn after this move
	# The board.gd will check this flag
	return {
		"type": "double_play",
		"cells_affected": [],
		"skip_turn_switch": true,
		"description": "¡Doble jugada! Coloca otra pieza.",
	}
