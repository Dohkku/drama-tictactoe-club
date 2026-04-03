class_name MatchConfig
extends Resource

## Configuration for a single match in the tournament.

@export var match_id: String = ""
@export var opponent_id: String = ""          # character_id registered in CinematicStage
@export var ai_difficulty: float = 0.5
## DEPRECATED: Use board_config.game_rules instead. Kept for backward compatibility.
@export var game_rules_preset: String = "standard"  # "standard", "rotating_3", "big_board"
@export var intro_script: String = ""         # path to .dscn cutscene
@export var reactions_script: String = ""     # path to .dscn reactions
@export var player_style: String = "slam"
@export var opponent_style: String = "gentle"
@export var turns_per_visit: int = 1  # For simultaneous: how many player turns per visit
## Per-match board configuration (null = use project default).
@export var board_config: Resource = null  # BoardConfig
