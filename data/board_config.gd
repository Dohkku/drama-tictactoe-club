class_name BoardConfig
extends Resource

## Complete board configuration: visual properties + game rules.
## Editable from the editor's "Tablero" tab.
## Each match can have its own BoardConfig, or inherit the project default.

const GameRulesScript = preload("res://board/game_rules.gd")

## --- Game rules (sub-resource) ---
## Defines board size, win conditions, rotation, etc.
@export var game_rules: Resource = null

## --- Board sizing ---
## Maximum board width/height in pixels (0 = no limit, fills panel).
@export var max_board_size: int = 420
## Horizontal margin around the board (px).
@export var margin_h: int = 24
## Vertical margin around the board (px).
@export var margin_v: int = 8

## --- Cell appearance ---
@export var cell_color_empty: Color = Color(0.92, 0.88, 0.82)
@export var cell_color_alt: Color = Color(0.25, 0.27, 0.32)  # Alternate color for checkerboard
@export var checkerboard_enabled: bool = false
@export var cell_color_hover: Color = Color(0.85, 0.80, 0.72)
@export var cell_line_color: Color = Color(0.6, 0.5, 0.4)
@export var cell_line_width: float = 2.0

## --- Board border/frame ---
@export var board_border_enabled: bool = false
@export var board_border_color: Color = Color(0.45, 0.35, 0.25)
@export var board_border_width: float = 12.0

## --- Hand areas ---
## Height of the piece hand areas (opponent on top, player on bottom).
@export var hand_area_height: int = 50

## --- Piece sizing ---
## Piece fills this fraction of the cell (0.0 - 1.0).
@export var piece_cell_ratio: float = 0.85

## --- Player/Opponent default colors (overridden by character data when available) ---
@export var default_player_color: Color = Color(0.2, 0.6, 1.0)
@export var default_opponent_color: Color = Color(1.0, 0.3, 0.3)

## --- Board background ---
@export var board_bg_color: Color = Color(0.96, 0.93, 0.88)


func get_rules() -> Resource:
	## Returns the GameRules sub-resource, creating a default if null.
	if game_rules == null:
		game_rules = GameRulesScript.new()
	return game_rules


func copy_config() -> Resource:
	## Deep-copy this BoardConfig including the game_rules sub-resource.
	var copy = load("res://data/board_config.gd").new()
	copy.max_board_size = max_board_size
	copy.margin_h = margin_h
	copy.margin_v = margin_v
	copy.cell_color_empty = cell_color_empty
	copy.cell_color_alt = cell_color_alt
	copy.checkerboard_enabled = checkerboard_enabled
	copy.cell_color_hover = cell_color_hover
	copy.cell_line_color = cell_line_color
	copy.cell_line_width = cell_line_width
	copy.board_border_enabled = board_border_enabled
	copy.board_border_color = board_border_color
	copy.board_border_width = board_border_width
	copy.hand_area_height = hand_area_height
	copy.piece_cell_ratio = piece_cell_ratio
	copy.default_player_color = default_player_color
	copy.default_opponent_color = default_opponent_color
	copy.board_bg_color = board_bg_color
	if game_rules != null:
		copy.game_rules = game_rules.duplicate_rules()
	return copy


static func create_default() -> Resource:
	## Returns a fully populated BoardConfig with standard GameRules.
	var cfg = load("res://data/board_config.gd").new()
	cfg.game_rules = GameRulesScript.new()
	return cfg
