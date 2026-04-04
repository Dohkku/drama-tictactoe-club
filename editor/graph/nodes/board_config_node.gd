extends "res://editor/graph/base_graph_node.gd"

## Board configuration node.
## Output: BoardConfig port (connects to MatchNode.board_config).
## Shows mini board grid preview and rules summary.

const BoardConfigScript = preload("res://data/board_config.gd")

var board_config: Resource = null  # BoardConfig
var is_project_default: bool = false
var _rules_label: Label = null
var _default_label: Label = null
var _mini_board: Control = null


func _init() -> void:
	super._init()
	accent_color = GraphThemeC.COLOR_BOARD


func _ready() -> void:
	title = "TABLERO"
	custom_minimum_size.x = 180
	super._ready()

	if board_config == null:
		board_config = BoardConfigScript.create_default()

	# Row 0: mini board preview + output port
	_mini_board = _MiniBoardPreview.new()
	_mini_board.custom_minimum_size = Vector2(80, 80)
	add_child(_mini_board)
	add_board_config_output(0)

	# Row 1: rules summary
	_rules_label = _make_dim_label("")
	add_child(_rules_label)
	set_slot_enabled_left(1, false)
	set_slot_enabled_right(1, false)

	# Row 2: default indicator
	_default_label = _make_label("", GraphThemeC.FONT_SIZE_SMALL, GraphThemeC.COLOR_START)
	add_child(_default_label)
	set_slot_enabled_left(2, false)
	set_slot_enabled_right(2, false)

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

	if _rules_label:
		var size_str := "%dx%d" % [rules.get_width(), rules.get_height()]
		var win_str := "Win=%d" % rules.win_length
		var pieces_str := ""
		if rules.max_pieces_per_player > 0:
			pieces_str = ", Max=%d" % rules.max_pieces_per_player
		_rules_label.text = "%s, %s%s" % [size_str, win_str, pieces_str]

	if _default_label:
		_default_label.text = "DEFAULT" if is_project_default else ""

	if _mini_board:
		_mini_board.board_config = board_config
		_mini_board.queue_redraw()


# ── Mini board preview (custom draw) ──

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

		# Grid lines
		for i in range(1, w):
			draw_line(Vector2(i * cell_w, 0), Vector2(i * cell_w, size.y), board_config.cell_line_color, 1.0)
		for i in range(1, h):
			draw_line(Vector2(0, i * cell_h), Vector2(size.x, i * cell_h), board_config.cell_line_color, 1.0)
