class_name MoveResult
extends RefCounted

## Structured result from BoardLogic.make_move().
## Contains the player, cell, and a list of typed events describing
## everything that happened. Other systems map events to sounds/visuals.

var success: bool = false
var player: int = 0
var cell: int = -1
var removed_cell: int = -1
var is_win: bool = false
var is_draw: bool = false
var winning_pattern: Array[int] = []
var events: Array[Dictionary] = []

## Why the move failed (empty if success)
var fail_reason: String = ""


func add_event(type: String, data: Dictionary = {}) -> void:
	events.append({"type": type, "data": data})


func has_event(type: String) -> bool:
	for e in events:
		if e.type == type:
			return true
	return false


func get_events_of_type(type: String) -> Array[Dictionary]:
	## Returns all events matching the given type string.
	var result: Array[Dictionary] = []
	for e in events:
		if e.type == type:
			result.append(e)
	return result


# ── Event type constants ──
const PIECE_PLACED := "piece_placed"
const PIECE_ROTATED := "piece_rotated"
const NEAR_WIN := "near_win"
const FORK := "fork"
const WIN := "win"
const DRAW := "draw"
const CENTER_TAKEN := "center_taken"
const CORNER_TAKEN := "corner_taken"
const TURN_CHANGED := "turn_changed"
const SPECIAL_CELL := "special_cell_triggered"
const BONUS_TURN := "bonus_turn"
const SKIP_TURN := "skip_turn"
