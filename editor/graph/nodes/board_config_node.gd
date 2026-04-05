extends "res://editor/graph/base_graph_node.gd"

## Board configuration node.
## Output: BoardConfig port (connects to MatchNode).
## Compact: mini grid + rules text.

const BoardConfigScript = preload("res://data/board_config.gd")

var board_config: Resource = null  # BoardConfig
var is_project_default: bool = false
var _info_label: Label = null
var _mini_board: Control = null


func _init() -> void:
	super._init()
	accent_color = GraphThemeC.COLOR_BOARD


func _ready() -> void:
	title = "TABLERO"
	custom_minimum_size.x = 140
	super._ready()

	if board_config == null:
		board_config = BoardConfigScript.create_default()

	# Row 0: mini board + output port
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	_mini_board = _MiniBoardPreview.new()
	_mini_board.custom_minimum_size = Vector2(48, 48)
	hbox.add_child(_mini_board)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	_info_label = _make_dim_label("")
	info.add_child(_info_label)
	hbox.add_child(info)

	add_child(hbox)
	add_board_config_output(0)

	_refresh_display()


func get_node_type() -> String:
	return "board_config"


func get_node_data() -> Dictionary:
	var data := {"is_project_default": is_project_default}
	if board_config:
		var rules = board_config.get_rules()
		data["board_size"] = rules.board_size
		data["win_length"] = rules.win_length
		data["max_pieces"] = rules.max_pieces_per_player
		data["overflow_mode"] = rules.overflow_mode
		data["allow_draw"] = rules.allow_draw
	return data


func set_node_data(data: Dictionary) -> void:
	is_project_default = data.get("is_project_default", false)
	if board_config == null:
		board_config = BoardConfigScript.create_default()
	var rules = board_config.get_rules()
	rules.board_size = data.get("board_size", 3)
	rules.win_length = data.get("win_length", 3)
	rules.max_pieces_per_player = data.get("max_pieces", -1)
	rules.overflow_mode = data.get("overflow_mode", "rotate")
	rules.allow_draw = data.get("allow_draw", true)
	_refresh_display()


func set_board_config(config: Resource) -> void:
	board_config = config
	if is_inside_tree():
		_refresh_display()


func _refresh_display() -> void:
	if board_config == null:
		return
	var rules = board_config.get_rules()

	if _info_label:
		var parts: PackedStringArray = []
		parts.append("%dx%d W=%d" % [rules.get_width(), rules.get_height(), rules.win_length])
		if rules.max_pieces_per_player > 0:
			parts.append("Max %d" % rules.max_pieces_per_player)
		if is_project_default:
			parts.append("DEFAULT")
		_info_label.text = "\n".join(parts)

	if _mini_board:
		_mini_board.board_config = board_config
		_mini_board.queue_redraw()


class _MiniBoardPreview extends Control:
	var board_config: Resource = null

	func _draw() -> void:
		if board_config == null:
			return
		var rules = board_config.get_rules()
		var w: int = rules.get_width()
		var h: int = rules.get_height()
		var cell_w: float = size.x / w
		var cell_h: float = size.y / h

		for row in range(h):
			for col in range(w):
				var rect := Rect2(col * cell_w, row * cell_h, cell_w - 1, cell_h - 1)
				var use_alt: bool = board_config.checkerboard_enabled and (row + col) % 2 == 1
				var color: Color = board_config.cell_color_alt if use_alt else board_config.cell_color_empty
				draw_rect(rect, color)

		for i in range(1, w):
			draw_line(Vector2(i * cell_w, 0), Vector2(i * cell_w, size.y), board_config.cell_line_color, 1.0)
		for i in range(1, h):
			draw_line(Vector2(0, i * cell_h), Vector2(size.x, i * cell_h), board_config.cell_line_color, 1.0)
