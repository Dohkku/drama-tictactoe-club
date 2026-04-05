class_name MatchConfig
extends Resource

## Configuration for a single match in the tournament.

@export var match_id: String = ""
@export var opponent_id: String = ""
@export var ai_difficulty: float = 0.5
@export var game_rules_preset: String = "standard"
@export var intro_script: String = ""
@export var reactions_script: String = ""
@export var player_style: String = "slam"
@export var opponent_style: String = "gentle"
@export var turns_per_visit: int = 1

## Visual effects: none, fire, sparkle, smoke, shockwave
@export var player_effect_name: String = "none"
@export var opponent_effect_name: String = "auto"  # auto = derive from style

## Piece placement imprecision (0.0 = perfect center, 0.3 = max offset)
@export var placement_offset: float = 0.0

## Piece designs: x, o, triangle, square, star, diamond
@export var player_piece_design: String = "x"
@export var opponent_piece_design: String = "o"

## Who plays first: "player", "opponent", "random"
@export var starting_player: String = "player"

## Per-match board configuration (null = use project default).
@export var board_config: Resource = null
