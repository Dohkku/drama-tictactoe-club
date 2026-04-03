class_name SpecialAbility
extends Resource

## Base class for special abilities that modify game rules.
## Extend this to create new abilities.

@export var ability_name: String = ""
@export var description: String = ""
@export var uses_per_match: int = 1  # -1 = unlimited

var _uses_remaining: int = 0


func reset() -> void:
	_uses_remaining = uses_per_match


func can_use(board_logic, board_state: Dictionary) -> bool:
	## Override this. board_state has: {move_count, last_move, current_turn, cells}
	if uses_per_match >= 0 and _uses_remaining <= 0:
		return false
	return _can_use_impl(board_logic, board_state)


func apply(board_logic, board_state: Dictionary) -> Dictionary:
	## Override this. Returns a dict describing what happened:
	## {type: "steal"|"double"|"block"|etc, cells_affected: [...], description: "..."}
	_uses_remaining -= 1
	return _apply_impl(board_logic, board_state)


## Override these in subclasses
func _can_use_impl(_board_logic, _board_state: Dictionary) -> bool:
	return false

func _apply_impl(_board_logic, _board_state: Dictionary) -> Dictionary:
	return {}
