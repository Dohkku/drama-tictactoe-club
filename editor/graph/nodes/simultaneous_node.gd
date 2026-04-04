extends "res://editor/graph/base_graph_node.gd"

## Simultaneous match event node.
## Inputs: Flow, Opponent1..N (Character), BoardConfig (optional)
## Output: Flow
## Per-opponent match configs are stored internally and edited in the detail panel.

var opponent_configs: Array[Dictionary] = []  # Per-opponent match settings
var _opponent_labels: Array[Label] = []
var _connected_characters: Array[Resource] = []  # CharacterData refs
var _next_opponent_slot: int = 3  # First dynamic opponent slot


func _init() -> void:
	super._init()
	accent_color = GraphThemeC.COLOR_SIMULTANEOUS


func _ready() -> void:
	title = "SIMULTANEA"
	custom_minimum_size.x = 200
	super._ready()

	# Slot 0: Flow through
	var flow_label := _make_label("Flujo", GraphThemeC.FONT_SIZE_SMALL, GraphThemeC.COLOR_TEXT_DIM)
	add_child(flow_label)
	add_flow_through(0)

	# Slot 1: Board config input (shared)
	var board_label := _make_dim_label("Tablero (compartido)")
	add_child(board_label)
	add_board_config_input(1)

	# Slot 2: Info label
	var info_label := _make_dim_label("Oponentes:")
	add_child(info_label)
	set_slot_enabled_left(2, false)
	set_slot_enabled_right(2, false)

	# Add initial empty opponent slot
	_add_opponent_slot()


func get_node_type() -> String:
	return "simultaneous"


func get_node_data() -> Dictionary:
	return {
		"opponent_configs": opponent_configs.duplicate(true),
	}


func set_node_data(data: Dictionary) -> void:
	opponent_configs = data.get("opponent_configs", [])
	# Ensure we have enough slots
	while _opponent_labels.size() < opponent_configs.size():
		_add_opponent_slot()
	_refresh_display()


func on_connection_changed(port: int, connected: bool, from_node: BaseGraphNode) -> void:
	var opp_idx := port - _next_opponent_slot + _opponent_labels.size()
	if port >= 3 and opp_idx >= 0 and opp_idx < _opponent_labels.size():
		if connected and "character_data" in from_node:
			# Ensure opponent_configs array is big enough
			while opponent_configs.size() <= opp_idx:
				opponent_configs.append({"ai_difficulty": 0.5, "player_style": "slam", "opponent_style": "gentle"})
			_update_opponent_label(opp_idx, from_node.character_data)
		else:
			_update_opponent_label(opp_idx, null)

		# Add new empty slot if the last slot just got connected
		if connected and opp_idx == _opponent_labels.size() - 1:
			_add_opponent_slot()


func _add_opponent_slot() -> void:
	var idx := _opponent_labels.size()
	var slot_idx := 3 + idx

	var label := _make_label("(vacio)", GraphThemeC.FONT_SIZE_NORMAL, GraphThemeC.COLOR_TEXT_DIM)
	add_child(label)
	_opponent_labels.append(label)

	add_character_input(slot_idx)


func _update_opponent_label(idx: int, char_data: Resource) -> void:
	if idx < 0 or idx >= _opponent_labels.size():
		return
	if char_data:
		var name_str: String = char_data.display_name if char_data.display_name != "" else char_data.character_id
		_opponent_labels[idx].text = name_str
		_opponent_labels[idx].add_theme_color_override("font_color", char_data.color if char_data.color != Color.BLACK else GraphThemeC.COLOR_TEXT)
	else:
		_opponent_labels[idx].text = "(vacio)"
		_opponent_labels[idx].add_theme_color_override("font_color", GraphThemeC.COLOR_TEXT_DIM)


func _refresh_display() -> void:
	for i in range(_opponent_labels.size()):
		if i < _connected_characters.size() and _connected_characters[i]:
			_update_opponent_label(i, _connected_characters[i])
		else:
			_update_opponent_label(i, null)
