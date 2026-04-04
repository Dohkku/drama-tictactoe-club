extends "res://editor/graph/base_graph_node.gd"

## Match event node.
## Inputs: Flow, Opponent (Character), BoardConfig, IntroScript, ReactionsScript
## Output: Flow
## Inline display: opponent name, AI difficulty bar, style icons.

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
	"intro_script": "",
	"reactions_script": "",
	"game_rules_preset": "standard",
	"custom_rules": false,
	"board_rules": {},
}

var _opponent_label: Label = null
var _difficulty_bar: ProgressBar = null
var _style_label: Label = null
var _connected_character: Resource = null  # CharacterData


func _init() -> void:
	super._init()
	accent_color = GraphThemeC.COLOR_MATCH


func _ready() -> void:
	title = "PARTIDA"
	custom_minimum_size.x = 220
	super._ready()

	# Slot 0: Flow in/out
	var flow_label := _make_label("Flujo", GraphThemeC.FONT_SIZE_SMALL, GraphThemeC.COLOR_TEXT_DIM)
	add_child(flow_label)
	add_flow_through(0)

	# Slot 1: Opponent (character input)
	_opponent_label = _make_label("vs ???", GraphThemeC.FONT_SIZE_NORMAL, GraphThemeC.COLOR_TEXT)
	add_child(_opponent_label)
	add_character_input(1)

	# Slot 2: Board config input
	var board_label := _make_dim_label("Tablero (opcional)")
	add_child(board_label)
	add_board_config_input(2)

	# Slot 3: Difficulty display
	var diff_hbox := HBoxContainer.new()
	diff_hbox.add_theme_constant_override("separation", 6)
	var diff_label := _make_dim_label("IA:")
	diff_hbox.add_child(diff_label)
	_difficulty_bar = ProgressBar.new()
	_difficulty_bar.min_value = 0.0
	_difficulty_bar.max_value = 1.0
	_difficulty_bar.value = match_data.get("ai_difficulty", 0.5)
	_difficulty_bar.custom_minimum_size = Vector2(80, 14)
	_difficulty_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_difficulty_bar.show_percentage = false
	diff_hbox.add_child(_difficulty_bar)
	add_child(diff_hbox)
	set_slot_enabled_left(3, false)
	set_slot_enabled_right(3, false)

	# Slot 4: Style summary
	_style_label = _make_dim_label("")
	add_child(_style_label)
	set_slot_enabled_left(4, false)
	set_slot_enabled_right(4, false)

	_refresh_display()


func get_node_type() -> String:
	return "match"


func get_node_data() -> Dictionary:
	return match_data.duplicate(true)


func set_node_data(data: Dictionary) -> void:
	for key in data:
		match_data[key] = data[key]
	_refresh_display()


func on_connection_changed(port: int, connected: bool, from_node: BaseGraphNode) -> void:
	if port == 1:  # Opponent character port
		if connected and from_node.has_method("set_character"):
			_connected_character = from_node.character_data
		elif connected and "character_data" in from_node:
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

	if _difficulty_bar:
		_difficulty_bar.value = match_data.get("ai_difficulty", 0.5)

	if _style_label:
		var ps: String = match_data.get("player_style", "slam")
		var os: String = match_data.get("opponent_style", "gentle")
		_style_label.text = "%s vs %s" % [ps, os]
