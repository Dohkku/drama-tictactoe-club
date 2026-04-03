extends "res://systems/board_logic/abilities/special_ability.gd"

## "Double Play" — Place two pieces in one turn.
## The second piece must be placed on a valid cell.
## Can only be used once per match.


func _init() -> void:
	ability_name = "Doble Jugada"
	description = "Coloca dos piezas en un solo turno"
	uses_per_match = 1


func _can_use_impl(board_logic, _board_state: Dictionary) -> bool:
	# Need at least 2 empty cells
	var empty_count := 0
	for cell in board_logic.cells:
		if cell == 0:
			empty_count += 1
	return empty_count >= 2


func _apply_impl(_board_logic, _board_state: Dictionary) -> Dictionary:
	# Grant an extra turn by NOT switching the current turn after this move
	# The board.gd will check this flag
	return {
		"type": "double_play",
		"cells_affected": [],
		"skip_turn_switch": true,
		"description": "¡Doble jugada! Coloca otra pieza.",
	}
