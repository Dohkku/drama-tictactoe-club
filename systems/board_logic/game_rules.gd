class_name GameRules
extends Resource

## Configurable game rules. Supports 2-6 players, non-square boards,
## blocked/special cells, and multiple win conditions.

## Number of players (2-6)
@export var num_players: int = 2

## Board dimensions — square shortcut
@export var board_size: int = 3
## Non-square override (0 = use board_size)
@export var board_width: int = 0
@export var board_height: int = 0

## How many in a row to win (for n_in_row condition)
@export var win_length: int = 3

## Max pieces per player on the board at once. -1 = unlimited
@export var max_pieces_per_player: int = -1

## What happens when max_pieces is reached: "rotate" or "block"
@export var overflow_mode: String = "rotate"

## Whether players can place on occupied cells
@export var allow_overwrite: bool = false

## Whether the game can end in a draw
@export var allow_draw: bool = true

## Win condition type: "n_in_row", "custom_patterns", "control_corners", "most_pieces"
@export var win_condition: String = "n_in_row"

## Custom win patterns (for "custom_patterns" or manual override)
@export var custom_win_patterns: Array = []

## Cells that are permanently blocked (indices)
@export var blocked_cells: Array[int] = []

## Special cells: {cell_index: {type: "bonus"|"trap"|"wild"}}
@export var special_cells: Dictionary = {}

## Pieces per player. -1 = auto-distribute.
@export var pieces_per_player: Array[int] = [-1, -1]

## Additional flags
@export var flags: Dictionary = {}


func get_width() -> int:
	return board_width if board_width > 0 else board_size

func get_height() -> int:
	return board_height if board_height > 0 else board_size

func get_total_cells() -> int:
	return get_width() * get_height()

func is_non_square() -> bool:
	return board_width > 0 and board_height > 0 and board_width != board_height


func get_pieces_for(player_id: int) -> int:
	var idx = player_id - 1
	if idx >= 0 and idx < pieces_per_player.size() and pieces_per_player[idx] != -1:
		return pieces_per_player[idx]
	var total = get_total_cells() - blocked_cells.size()
	var base = total / num_players
	var remainder = total % num_players
	return base + (1 if idx < remainder else 0)


func is_cell_blocked(index: int) -> bool:
	return index in blocked_cells


func get_special_cell(index: int) -> Dictionary:
	return special_cells.get(index, {})


func get_win_patterns() -> Array:
	match win_condition:
		"custom_patterns":
			return custom_win_patterns if not custom_win_patterns.is_empty() else _generate_standard_patterns()
		"control_corners":
			return _generate_corner_patterns()
		"most_pieces":
			return []  # No patterns — checked differently
		_:  # "n_in_row"
			if not custom_win_patterns.is_empty():
				return custom_win_patterns
			return _generate_standard_patterns()


func _generate_standard_patterns() -> Array:
	var patterns: Array = []
	var w = get_width()
	var h = get_height()

	# Rows
	for row in range(h):
		for start_col in range(w - win_length + 1):
			var pattern: Array[int] = []
			for k in range(win_length):
				pattern.append(row * w + start_col + k)
			if not _pattern_has_blocked(pattern):
				patterns.append(pattern)

	# Columns
	for col in range(w):
		for start_row in range(h - win_length + 1):
			var pattern: Array[int] = []
			for k in range(win_length):
				pattern.append((start_row + k) * w + col)
			if not _pattern_has_blocked(pattern):
				patterns.append(pattern)

	# Diagonals (top-left to bottom-right)
	for row in range(h - win_length + 1):
		for col in range(w - win_length + 1):
			var pattern: Array[int] = []
			for k in range(win_length):
				pattern.append((row + k) * w + col + k)
			if not _pattern_has_blocked(pattern):
				patterns.append(pattern)

	# Diagonals (top-right to bottom-left)
	for row in range(h - win_length + 1):
		for col in range(win_length - 1, w):
			var pattern: Array[int] = []
			for k in range(win_length):
				pattern.append((row + k) * w + col - k)
			if not _pattern_has_blocked(pattern):
				patterns.append(pattern)

	return patterns


func _generate_corner_patterns() -> Array:
	## Win by controlling all 4 corners
	var w = get_width()
	var h = get_height()
	var corners: Array[int] = [0, w - 1, (h - 1) * w, h * w - 1]
	# Filter out blocked corners
	var valid_corners: Array[int] = []
	for c in corners:
		if not is_cell_blocked(c):
			valid_corners.append(c)
	if valid_corners.size() < 4:
		return []  # Can't win by corners if some are blocked
	return [valid_corners]


func generate_square_patterns() -> Array:
	## Generate all possible 2x2 square patterns
	var patterns: Array = []
	var w = get_width()
	var h = get_height()
	for row in range(h - 1):
		for col in range(w - 1):
			var pattern: Array[int] = [
				row * w + col,
				row * w + col + 1,
				(row + 1) * w + col,
				(row + 1) * w + col + 1,
			]
			if not _pattern_has_blocked(pattern):
				patterns.append(pattern)
	return patterns


func _pattern_has_blocked(pattern: Array) -> bool:
	for idx in pattern:
		if is_cell_blocked(idx):
			return true
	return false


func get_corners() -> Array[int]:
	var w = get_width()
	var h = get_height()
	return [0, w - 1, (h - 1) * w, h * w - 1] as Array[int]


## Validate rules. Returns array of error strings (empty = valid).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if num_players < 2:
		errors.append("Mínimo 2 jugadores (actual: %d)" % num_players)
	if num_players > 6:
		errors.append("Máximo 6 jugadores (actual: %d)" % num_players)
	var w = get_width()
	var h = get_height()
	if w < 3 or h < 3:
		errors.append("Tamaño mínimo 3x3 (actual: %dx%d)" % [w, h])
	if win_condition == "n_in_row" and win_length > mini(w, h):
		errors.append("Fichas para ganar (%d) > dimensión menor (%d)" % [win_length, mini(w, h)])
	if win_length < 3 and win_condition == "n_in_row":
		errors.append("Mínimo 3 en raya (actual: %d)" % win_length)
	var playable = get_total_cells() - blocked_cells.size()
	if num_players > playable:
		errors.append("Más jugadores (%d) que celdas jugables (%d)" % [num_players, playable])
	if max_pieces_per_player > 0 and max_pieces_per_player < win_length and win_condition == "n_in_row":
		errors.append("Máx fichas (%d) < fichas para ganar (%d)" % [max_pieces_per_player, win_length])
	for bc in blocked_cells:
		if bc < 0 or bc >= get_total_cells():
			errors.append("Celda bloqueada %d fuera de rango (0-%d)" % [bc, get_total_cells() - 1])
	for sc_idx in special_cells:
		if sc_idx in blocked_cells:
			errors.append("Celda %d es bloqueada y especial a la vez" % sc_idx)
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

static func rectangular(w: int, h: int, win_len: int = 3) -> Resource:
	var r = load("res://systems/board_logic/game_rules.gd").new()
	r.board_width = w
	r.board_height = h
	r.win_length = win_len
	return r


func duplicate_rules() -> Resource:
	var r = load("res://systems/board_logic/game_rules.gd").new()
	r.num_players = num_players
	r.board_size = board_size
	r.board_width = board_width
	r.board_height = board_height
	r.win_length = win_length
	r.max_pieces_per_player = max_pieces_per_player
	r.overflow_mode = overflow_mode
	r.allow_overwrite = allow_overwrite
	r.allow_draw = allow_draw
	r.win_condition = win_condition
	r.custom_win_patterns = custom_win_patterns.duplicate(true)
	r.blocked_cells = blocked_cells.duplicate()
	r.special_cells = special_cells.duplicate(true)
	r.pieces_per_player = pieces_per_player.duplicate()
	r.flags = flags.duplicate(true)
	return r
