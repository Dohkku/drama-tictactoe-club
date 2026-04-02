class_name GameRules
extends Resource

## Configurable game rules. Each match/board can have different rules.

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

## Number of pieces per player. -1 = auto (ceil(board_size^2 / 2) for first, floor for second)
@export var pieces_per_player: Array[int] = [-1, -1]  # [player_x, player_o]

## Additional flags for ability/DSL system to check
@export var flags: Dictionary = {}


func get_total_cells() -> int:
	return board_size * board_size


func get_pieces_for(piece: int) -> int:
	# piece 1 = X (first player), piece 2 = O (second player)
	var idx = 0 if piece == 1 else 1
	if pieces_per_player[idx] == -1:
		if piece == 1:
			return ceili(float(get_total_cells()) / 2.0)
		else:
			return floori(float(get_total_cells()) / 2.0)
	return pieces_per_player[idx]


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


## Presets

static func standard() -> Resource:
	return load("res://board/game_rules.gd").new()


static func rotating_3() -> Resource:
	## Each player can only have 3 pieces on the board.
	## When placing a 4th, the oldest one disappears.
	var r = load("res://board/game_rules.gd").new()
	r.max_pieces_per_player = 3
	r.overflow_mode = "rotate"
	r.allow_draw = false  # Can't draw if pieces rotate
	return r


static func big_board() -> Resource:
	## 5x5 board, need 4 in a row
	var r = load("res://board/game_rules.gd").new()
	r.board_size = 5
	r.win_length = 4
	return r
