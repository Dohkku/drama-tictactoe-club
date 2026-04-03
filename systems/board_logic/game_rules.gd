class_name GameRules
extends Resource

## Configurable game rules. Supports 2-6 players on any board size.

## Number of players (2-6)
@export var num_players: int = 2

## Board dimensions (default 3x3)
@export var board_size: int = 3

## How many in a row to win
@export var win_length: int = 3

## Max pieces per player on the board at once. -1 = unlimited (standard rules)
## When exceeded, oldest piece is removed (rotation mode)
@export var max_pieces_per_player: int = -1

## What happens when max_pieces is reached
## "rotate": remove the oldest placed piece of that player
## "block": player can't place until a piece is freed
@export var overflow_mode: String = "rotate"

## Whether players can place on occupied cells (overwrite)
@export var allow_overwrite: bool = false

## Whether the game can end in a draw, or continues until someone wins
@export var allow_draw: bool = true

## Custom win patterns (empty = use standard rows/cols/diags)
## Each pattern is an Array of cell indices
@export var custom_win_patterns: Array = []

## Number of pieces per player. -1 = auto-distribute evenly.
## Array sized to num_players. Index 0 = player 1, index 1 = player 2, etc.
@export var pieces_per_player: Array[int] = [-1, -1]

## Additional flags for ability/DSL system to check
@export var flags: Dictionary = {}


func get_total_cells() -> int:
	return board_size * board_size


func get_pieces_for(player_id: int) -> int:
	## player_id is 1-based (1, 2, 3, ...)
	var idx = player_id - 1
	if idx >= 0 and idx < pieces_per_player.size() and pieces_per_player[idx] != -1:
		return pieces_per_player[idx]
	# Auto-distribute: total cells / num_players, first players get extra if uneven
	var total = get_total_cells()
	var base = total / num_players
	var remainder = total % num_players
	return base + (1 if idx < remainder else 0)


func get_win_patterns() -> Array:
	if not custom_win_patterns.is_empty():
		return custom_win_patterns
	return _generate_standard_patterns()


func _generate_standard_patterns() -> Array:
	var patterns: Array = []
	var s = board_size

	# Rows
	for row in range(s):
		for start_col in range(s - win_length + 1):
			var pattern: Array[int] = []
			for k in range(win_length):
				pattern.append(row * s + start_col + k)
			patterns.append(pattern)

	# Columns
	for col in range(s):
		for start_row in range(s - win_length + 1):
			var pattern: Array[int] = []
			for k in range(win_length):
				pattern.append((start_row + k) * s + col)
			patterns.append(pattern)

	# Diagonals (top-left to bottom-right)
	for row in range(s - win_length + 1):
		for col in range(s - win_length + 1):
			var pattern: Array[int] = []
			for k in range(win_length):
				pattern.append((row + k) * s + col + k)
			patterns.append(pattern)

	# Diagonals (top-right to bottom-left)
	for row in range(s - win_length + 1):
		for col in range(win_length - 1, s):
			var pattern: Array[int] = []
			for k in range(win_length):
				pattern.append((row + k) * s + col - k)
			patterns.append(pattern)

	return patterns


## Validate rules. Returns array of error strings (empty = valid).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if num_players < 2:
		errors.append("Mínimo 2 jugadores (actual: %d)" % num_players)
	if num_players > 6:
		errors.append("Máximo 6 jugadores (actual: %d)" % num_players)
	if board_size < 3:
		errors.append("Tamaño mínimo 3 (actual: %d)" % board_size)
	if win_length > board_size:
		errors.append("Fichas para ganar (%d) no puede ser mayor que tamaño (%d)" % [win_length, board_size])
	if win_length < 3:
		errors.append("Mínimo 3 en raya para ganar (actual: %d)" % win_length)
	if num_players > get_total_cells():
		errors.append("Más jugadores (%d) que celdas (%d)" % [num_players, get_total_cells()])
	if max_pieces_per_player > 0 and max_pieces_per_player < win_length:
		errors.append("Máx fichas (%d) menor que fichas para ganar (%d) — imposible ganar" % [max_pieces_per_player, win_length])
	return errors


## Presets

static func standard() -> Resource:
	return load("res://systems/board_logic/game_rules.gd").new()


static func rotating_3() -> Resource:
	var r = load("res://systems/board_logic/game_rules.gd").new()
	r.max_pieces_per_player = 3
	r.overflow_mode = "rotate"
	r.allow_draw = false
	return r


static func big_board() -> Resource:
	var r = load("res://systems/board_logic/game_rules.gd").new()
	r.board_size = 5
	r.win_length = 4
	return r


func duplicate_rules() -> Resource:
	var r = load("res://systems/board_logic/game_rules.gd").new()
	r.num_players = num_players
	r.board_size = board_size
	r.win_length = win_length
	r.max_pieces_per_player = max_pieces_per_player
	r.overflow_mode = overflow_mode
	r.allow_overwrite = allow_overwrite
	r.allow_draw = allow_draw
	r.custom_win_patterns = custom_win_patterns.duplicate(true)
	r.pieces_per_player = pieces_per_player.duplicate()
	r.flags = flags.duplicate(true)
	return r
