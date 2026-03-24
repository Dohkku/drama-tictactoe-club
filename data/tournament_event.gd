class_name TournamentEvent
extends Resource

@export var event_type: String = "match"  # "match", "cutscene", "simultaneous"
@export var event_name: String = ""
@export var match_config: Resource = null  # MatchConfig for "match" type
@export var cutscene_script_path: String = ""  # For "cutscene" type
@export var simultaneous_configs: Array[Resource] = []  # Array of MatchConfig for "simultaneous"
@export var order_index: int = 0
