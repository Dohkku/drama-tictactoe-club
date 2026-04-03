class_name GameRules
extends Resource

## Configurable game rules for N-player tic-tac-toe.
## Supports non-square boards, blocked/special cells, and multiple win conditions.

# ── Constants ──
const OVERFLOW_ROTATE := "rotate"
const OVERFLOW_BLOCK := "block"
const WIN_N_IN_ROW := "n_in_row"
const WIN_CUSTOM := "custom_patterns"
const WIN_CORNERS := "control_corners"
const WIN_MOST_PIECES := "most_pieces"
const SPECIAL_BONUS := "bonus"
const SPECIAL_TRAP := "trap"
const SPECIAL_WILD := "wild"
const SPECIAL_TYPES := ["bonus", "trap", "wild"]

# ── Board shape ──
@export var num_players: int = 2
@export var board_size: int = 3           ## Square shortcut (used when width/height are 0)
@export var board_width: int = 0          ## Non-square override (0 = use board_size)
@export var board_height: int = 0         ## Non-square override (0 = use board_size)

# ── Victory ──
@export var win_length: int = 3           ## N-in-a-row length
@export var win_condition: String = WIN_N_IN_ROW
@export var custom_win_patterns: Array = []

# ── Pieces ──
@export var max_pieces_per_player: int = -1  ## -1 = unlimited
@export var overflow_mode: String = OVERFLOW_ROTATE
@export var allow_overwrite: bool = false
@export var allow_draw: bool = true
@export var pieces_per_player: Array[int] = [-1, -1]

# ── Special cells ──
@export var blocked_cells: Array[int] = []
@export var special_cells: Dictionary = {}  ## {cell_index: {type: String}}

# ── Misc ──
@export var flags: Dictionary = {}


func get_width() -> int:
	return board_width if board_width > 0 else board_size

func get_height() -> int:
	return board_height if board_height > 0 else board_size

func get_total_cells() -> int:
	return get_width() * get_height()

func get_playable_cells() -> int:
	return get_total_cells() - blocked_cells.size()

func is_cell_blocked(index: int) -> bool:
	return index in blocked_cells

func get_special_cell(index: int) -> Dictionary:
	return special_cells.get(index, {})

func get_corners() -> Array[int]:
	var w: int = get_width()
	var h: int = get_height()
	return [0, w - 1, (h - 1) * w, h * w - 1] as Array[int]


## Returns the number of pieces a player should have.
## Auto-distributes evenly if set to -1.
func get_pieces_for(player_id: int) -> int:
	var idx: int = player_id - 1
	if idx >= 0 and idx < pieces_per_player.size() and pieces_per_player[idx] != -1:
		return pieces_per_player[idx]
	var playable: int = get_playable_cells()
	var base: int = playable / num_players
	var remainder: int = playable % num_players
	return base + (1 if idx < remainder else 0)


## Returns win patterns based on the current win_condition.
func get_win_patterns() -> Array:
	match win_condition:
		WIN_CUSTOM:
			return custom_win_patterns if not custom_win_patterns.is_empty() else _generate_n_in_row_patterns()
		WIN_CORNERS:
			return _generate_corner_patterns()
		WIN_MOST_PIECES:
			return []  # Checked differently in board_logic
		_:
			if not custom_win_patterns.is_empty():
				return custom_win_patterns
			return _generate_n_in_row_patterns()


func _generate_n_in_row_patterns() -> Array:
	var patterns: Array = []
	var w: int = get_width()
	var h: int = get_height()
	# Rows
	for row in range(h):
		for start_col in range(w - win_length + 1):
			var pat: Array[int] = []
			for k in range(win_length):
				pat.append(row * w + start_col + k)
			if not _pattern_has_blocked(pat):
				patterns.append(pat)
	# Columns
	for col in range(w):
		for start_row in range(h - win_length + 1):
			var pat: Array[int] = []
			for k in range(win_length):
				pat.append((start_row + k) * w + col)
			if not _pattern_has_blocked(pat):
				patterns.append(pat)
	# Diagonal ↘
	for row in range(h - win_length + 1):
		for col in range(w - win_length + 1):
			var pat: Array[int] = []
			for k in range(win_length):
				pat.append((row + k) * w + col + k)
			if not _pattern_has_blocked(pat):
				patterns.append(pat)
	# Diagonal ↙
	for row in range(h - win_length + 1):
		for col in range(win_length - 1, w):
			var pat: Array[int] = []
			for k in range(win_length):
				pat.append((row + k) * w + col - k)
			if not _pattern_has_blocked(pat):
				patterns.append(pat)
	return patterns


func _generate_corner_patterns() -> Array:
	var corners := get_corners()
	var valid: Array[int] = []
	for c in corners:
		if not is_cell_blocked(c):
			valid.append(c)
	return [valid] if valid.size() >= 4 else []


func _pattern_has_blocked(pattern: Array[int]) -> bool:
	for idx in pattern:
		if is_cell_blocked(idx):
			return true
	return false


## Validate rules. Returns error messages (empty = valid).
func validate() -> Array[String]:
	var errors: Array[String] = []
	var w: int = get_width()
	var h: int = get_height()
	if num_players < 2 or num_players > 6:
		errors.append("Jugadores debe ser 2-6 (actual: %d)" % num_players)
	if w < 3 or h < 3:
		errors.append("Tamaño mínimo 3x3 (actual: %dx%d)" % [w, h])
	if win_condition == WIN_N_IN_ROW and win_length > mini(w, h):
		errors.append("Para ganar (%d) > dimensión menor (%d)" % [win_length, mini(w, h)])
	if win_condition == WIN_N_IN_ROW and win_length < 3:
		errors.append("Mínimo 3 en raya (actual: %d)" % win_length)
	if num_players > get_playable_cells():
		errors.append("Más jugadores (%d) que celdas jugables (%d)" % [num_players, get_playable_cells()])
	if max_pieces_per_player > 0 and max_pieces_per_player < win_length and win_condition == WIN_N_IN_ROW:
		errors.append("Máx fichas (%d) < para ganar (%d)" % [max_pieces_per_player, win_length])
	for bc in blocked_cells:
		if bc < 0 or bc >= get_total_cells():
			errors.append("Celda bloqueada %d fuera de rango" % bc)
	for sc_idx in special_cells:
		if sc_idx in blocked_cells:
			errors.append("Celda %d es bloqueada y especial" % sc_idx)
	return errors


# ── Presets ──

static func standard() -> Resource:
	return load("res://systems/board_logic/game_rules.gd").new()

static func rotating_3() -> Resource:
	var r = standard()
	r.max_pieces_per_player = 3
	r.overflow_mode = OVERFLOW_ROTATE
	r.allow_draw = false
	return r

static func big_board() -> Resource:
	var r = standard()
	r.board_size = 5
	r.win_length = 4
	return r

static func rectangular(w: int, h: int, win_len: int = 3) -> Resource:
	var r = standard()
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
	r.win_condition = win_condition
	r.max_pieces_per_player = max_pieces_per_player
	r.overflow_mode = overflow_mode
	r.allow_overwrite = allow_overwrite
	r.allow_draw = allow_draw
	r.custom_win_patterns = custom_win_patterns.duplicate(true)
	r.blocked_cells = blocked_cells.duplicate()
	r.special_cells = special_cells.duplicate(true)
	r.pieces_per_player = pieces_per_player.duplicate()
	r.flags = flags.duplicate(true)
	return r
