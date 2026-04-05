extends Node

var current_match_index: int = 0
var flags: Dictionary = {}
var match_history: Array = []
var character_affinity: Dictionary = {}

## Editor → main.tscn one-shot override: when set, main.gd uses it instead
## of loading user://current_project.tres. Consumed (nulled) after first read.
var preview_project_override: Resource = null

func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value

func get_flag(flag_name: String, default: bool = false) -> bool:
	return flags.get(flag_name, default)

func record_match(opponent_id: String, result: String) -> void:
	match_history.append({"opponent": opponent_id, "result": result})

func reset() -> void:
	current_match_index = 0
	flags.clear()
	match_history.clear()
	character_affinity.clear()
