extends "res://editor/graph/base_graph_node.gd"

## Match event node.
## Inputs: Flow, Opponent (Character), BoardConfig
## Output: Flow
## Compact inline display with key info.

const MatchConfigScript = preload("res://match_system/match_config.gd")

var match_data: Dictionary = {
	"ai_difficulty": 0.5,
	"player_style": "slam",
	"opponent_style": "gentle",
	"player_effect_name": "none",
	"opponent_effect_name": "auto",
	"placement_offset": 0.0,
	"player_piece_design": "x",
	"opponent_piece_design": "o",
	"turns_per_visit": 1,
	"starting_player": "player",
	"intro_script": "",
	"reactions_script": "",
	"game_rules_preset": "standard",
	"custom_rules": false,
	"board_rules": {},
}

var _opponent_label: Label = null
var _info_label: Label = null
var _connected_character: Resource = null  # CharacterData


func _init() -> void:
	super._init()
	accent_color = GraphThemeC.COLOR_MATCH


func _ready() -> void:
	title = "PARTIDA"
	custom_minimum_size.x = 180
	super._ready()

	# Slot 0: Flow in/out
	_opponent_label = _make_label("vs ???", GraphThemeC.FONT_SIZE_NORMAL, GraphThemeC.COLOR_TEXT)
	add_child(_opponent_label)
	add_flow_through(0)

	# Slot 1: Opponent (character input)
	var opp_hint := _make_dim_label("Oponente")
	add_child(opp_hint)
	add_character_input(1)

	# Slot 2: Board config input
	var board_hint := _make_dim_label("Tablero")
	add_child(board_hint)
	add_board_config_input(2)

	# Slot 3: Info summary (no ports)
	_info_label = _make_dim_label("")
	add_child(_info_label)
	set_slot_enabled_left(3, false)
	set_slot_enabled_right(3, false)

	_refresh_display()


func get_node_type() -> String:
	return "match"


func get_node_data() -> Dictionary:
	return match_data.duplicate(true)


func set_node_data(data: Dictionary) -> void:
	for key in data:
		match_data[key] = data[key]
	_refresh_display()


func validate() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var ge := get_parent() as GraphEdit
	if ge:
		if not _has_flow_input_connection(ge, 0) and not _has_flow_output_connection(ge, 0):
			errors.append("Flujo no conectado")
		elif not _has_flow_input_connection(ge, 0):
			errors.append("Entrada de flujo no conectada")
		elif not _has_flow_output_connection(ge, 0):
			errors.append("Salida de flujo no conectada")
		if _connected_character == null:
			warnings.append("Sin oponente conectado")
	return {"valid": errors.is_empty(), "warnings": warnings, "errors": errors}


func on_connection_changed(port: int, connected: bool, from_node: BaseGraphNode) -> void:
	if port == 1:  # Opponent character port
		if connected and from_node != null and "character_data" in from_node:
			_connected_character = from_node.character_data
		else:
			_connected_character = null
		_refresh_display()


func set_connected_character(char_data: Resource) -> void:
	_connected_character = char_data
	_refresh_display()


func _refresh_display() -> void:
	if _opponent_label:
		if _connected_character:
			var name_str: String = _connected_character.display_name if _connected_character.display_name != "" else _connected_character.character_id
			_opponent_label.text = "vs %s" % name_str
			_opponent_label.add_theme_color_override("font_color", _connected_character.color if _connected_character.color != Color.BLACK else GraphThemeC.COLOR_TEXT)
		else:
			_opponent_label.text = "vs ???"
			_opponent_label.add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT)

	if _info_label:
		var diff: float = match_data.get("ai_difficulty", 0.5)
		var diff_pct: int = int(diff * 100)
		var ps: String = match_data.get("player_style", "slam")
		var os: String = match_data.get("opponent_style", "gentle")
		_info_label.text = "IA:%d%%  %s/%s" % [diff_pct, ps.left(3), os.left(3)]

	_notify_validation_needed()
