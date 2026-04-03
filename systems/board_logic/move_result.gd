class_name MoveResult
extends RefCounted

## Structured result from BoardLogic.make_move().
## Contains everything that happened during the move, as a list of events
## that other systems (visuals, sound, scene runner) can map to actions.

var success: bool = false
var player: int = 0
var cell: int = -1
var events: Array[Dictionary] = []

# Convenience accessors (populated from events)
var removed_cell: int = -1
var is_win: bool = false
var is_draw: bool = false
var winning_pattern: Array[int] = []


func add_event(type: String, data: Dictionary = {}) -> void:
	events.append({"type": type, "data": data})


func has_event(type: String) -> bool:
	for e in events:
		if e.type == type:
			return true
	return false


func get_events_of_type(type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e in events:
		if e.type == type:
			result.append(e)
	return result


## Event type constants for type safety
const PIECE_PLACED := "piece_placed"           # {player, cell}
const PIECE_ROTATED := "piece_rotated"         # {player, removed_cell, new_cell}
const NEAR_WIN := "near_win"                   # {player, pattern, missing_cell}
const FORK := "fork"                           # {player, count}
const WIN := "win"                             # {player, pattern}
const DRAW := "draw"                           # {}
const CENTER_TAKEN := "center_taken"           # {player}
const CORNER_TAKEN := "corner_taken"           # {player}
const TURN_CHANGED := "turn_changed"           # {from, to}
const SPECIAL_CELL := "special_cell_triggered" # {cell, type, effect}
const SKIP_TURN := "skip_turn"                 # {player} — caused by trap cell
const BONUS_TURN := "bonus_turn"               # {player} — caused by bonus cell
