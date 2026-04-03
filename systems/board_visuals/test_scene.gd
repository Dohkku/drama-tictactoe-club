extends Control

## Interactive test scene for Board Visuals system.
## Tests: cell rendering, piece animation, hand areas, placement styles,
## checkerboard, emotions, rotation removal — all without EventBus.

const BoardLogicScript = preload("res://systems/board_logic/board_logic.gd")
const GameRulesScript = preload("res://systems/board_logic/game_rules.gd")
const AIPlayerScript = preload("res://systems/board_logic/ai_player.gd")
const CellScript = preload("res://systems/board_visuals/cell.gd")
const PieceScript = preload("res://systems/board_visuals/piece.gd")
const PlacementStyleScript = preload("res://systems/board_visuals/placement_style.gd")

var logic: RefCounted
var ai: RefCounted
var rules: Resource
var cells: Array[Control] = []
var player_pieces: Array[Control] = []
var opponent_pieces: Array[Control] = []
var cell_to_piece: Dictionary = {}
var player_next: int = 0
var opponent_next: int = 0
var _animating: bool = false

var current_style: Resource
var log_lines: Array[String] = []

# UI references
var grid: GridContainer
var piece_layer: Control
var player_hand: Control
var opponent_hand: Control
var board_frame: PanelContainer
var log_label: RichTextLabel
var status_label: Label
var style_option: OptionButton
var emotion_option: OptionButton
var checkerboard_check: CheckBox
var border_check: CheckBox
var board_size_spin: SpinBox
var max_pieces_spin: SpinBox
var ai_check: CheckBox

const STYLES := ["gentle", "slam", "spinning", "dramatic", "nervous"]
const EMOTIONS := ["neutral", "happy", "angry", "sad", "focused"]
const PLAYER_COLOR := Color(0.3, 0.6, 1.0)
const OPPONENT_COLOR := Color(1.0, 0.3, 0.3)
const EXPRESSION_COLORS := {
	"happy": Color(0.3, 0.9, 0.4),
	"angry": Color(1.0, 0.2, 0.1),
	"sad": Color(0.4, 0.4, 0.7),
	"focused": Color(0.9, 0.7, 0.2),
}


func _ready() -> void:
	_build_ui()
	_new_game()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://systems/dev_menu.tscn")


func _new_game() -> void:
	rules = GameRulesScript.new()
	rules.board_size = int(board_size_spin.value)
	rules.max_pieces_per_player = int(max_pieces_spin.value)
	if rules.max_pieces_per_player > 0:
		rules.overflow_mode = "rotate"
		rules.allow_draw = false

	logic = BoardLogicScript.new(rules)
	ai = AIPlayerScript.new()
	ai.difficulty = 0.6
	current_style = _get_style()

	_clear_board()
	_create_cells()
	_create_pieces()
	_update_status()
	_log("Nuevo juego %dx%d" % [rules.board_size, rules.board_size])


func _clear_board() -> void:
	for c in cells:
		if is_instance_valid(c):
			c.queue_free()
	cells.clear()
	for p in player_pieces + opponent_pieces:
		if is_instance_valid(p):
			p.queue_free()
	player_pieces.clear()
	opponent_pieces.clear()
	cell_to_piece.clear()
	player_next = 0
	opponent_next = 0
	_animating = false


func _create_cells() -> void:
	grid.columns = rules.board_size
	var total = rules.get_total_cells()
	var use_checker = checkerboard_check.button_pressed
	for i in range(total):
		var cell := Control.new()
		cell.set_script(CellScript)
		cell.cell_index = i
		cell.custom_minimum_size = Vector2(10, 10)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var row = i / rules.board_size
		var col = i % rules.board_size
		cell.is_dark_cell = ((row + col) % 2 == 1)
		cell.checkerboard = use_checker
		cell.color_empty = Color(0.92, 0.88, 0.82)
		cell.color_alt = Color(0.25, 0.27, 0.32)
		cell.color_hover = Color(0.85, 0.80, 0.72)
		cell.color_line = Color(0.6, 0.5, 0.4)
		cell.line_width = 2.0
		cell.cell_clicked.connect(_on_cell_clicked)
		grid.add_child(cell)
		cells.append(cell)


func _create_pieces() -> void:
	var count = rules.get_pieces_for(1)
	for i in range(count):
		var p := Control.new()
		p.set_script(PieceScript)
		p.setup(1, "player", PLAYER_COLOR, EXPRESSION_COLORS)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece_layer.add_child(p)
		player_pieces.append(p)

	count = rules.get_pieces_for(2)
	for i in range(count):
		var p := Control.new()
		p.set_script(PieceScript)
		p.setup(2, "opponent", OPPONENT_COLOR, EXPRESSION_COLORS)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece_layer.add_child(p)
		opponent_pieces.append(p)

	await get_tree().process_frame
	_position_hand_pieces()


func _position_hand_pieces() -> void:
	if cells.is_empty():
		return
	var cell_size = _get_cell_size()
	var piece_h = max(24.0, min(cell_size.y * 0.42, 40.0))

	# Player hand (below board)
	var hand_rect = player_hand.get_global_rect()
	var start_x = hand_rect.position.x - piece_layer.global_position.x + 8.0
	var y = hand_rect.position.y - piece_layer.global_position.y + 4.0
	for i in range(player_next, player_pieces.size()):
		var p = player_pieces[i]
		if not is_instance_valid(p):
			continue
		p.size = Vector2(piece_h, piece_h)
		p.position = Vector2(start_x + (i - player_next) * (piece_h + 4.0), y)
		p.pivot_offset = p.size / 2.0

	# Opponent hand (above board)
	hand_rect = opponent_hand.get_global_rect()
	start_x = hand_rect.position.x - piece_layer.global_position.x + 8.0
	y = hand_rect.position.y - piece_layer.global_position.y + 4.0
	for i in range(opponent_next, opponent_pieces.size()):
		var p = opponent_pieces[i]
		if not is_instance_valid(p):
			continue
		p.size = Vector2(piece_h, piece_h)
		p.position = Vector2(start_x + (i - opponent_next) * (piece_h + 4.0), y)
		p.pivot_offset = p.size / 2.0


func _on_cell_clicked(index: int) -> void:
	if _animating or logic.game_over:
		return
	if logic.current_turn != 1:
		return
	await _do_move(index, true)
	if ai_check.button_pressed and not logic.game_over and logic.current_turn == 2:
		await get_tree().create_timer(0.3).timeout
		var move = ai.choose_move(logic)
		if move >= 0:
			await _do_move(move, false)


func _do_move(index: int, is_player: bool) -> void:
	var result = logic.make_move(index)
	if not result.success:
		_log("Movimiento inválido: %s" % result.fail_reason)
		return

	_animating = true
	var pieces_arr = player_pieces if is_player else opponent_pieces
	var next_ref = player_next if is_player else opponent_next

	# Handle rotation removal
	if result.removed_cell >= 0:
		var removed_idx = result.removed_cell
		cells[removed_idx].set_occupied(false)
		if cell_to_piece.has(removed_idx):
			var old_piece = cell_to_piece[removed_idx]
			cell_to_piece.erase(removed_idx)
			var fade = old_piece.create_tween()
			fade.tween_property(old_piece, "modulate:a", 0.3, 0.2)
			await fade.finished
			old_piece.modulate.a = 1.0
			if is_player:
				player_next = max(0, player_next - 1)
			else:
				opponent_next = max(0, opponent_next - 1)
		_log("  Rotación: celda %d eliminada" % result.removed_cell)

	cells[index].set_occupied(true)

	# Pick piece from hand
	next_ref = player_next if is_player else opponent_next
	if next_ref >= pieces_arr.size():
		_animating = false
		return
	var piece_node = pieces_arr[next_ref]
	if is_player:
		player_next += 1
	else:
		opponent_next += 1
	cell_to_piece[index] = piece_node

	# Target position
	var target_pos = _get_cell_pos_in_layer(index)
	var cell_size = _get_cell_size()
	var piece_size = cell_size * 0.85
	var offset = (cell_size - piece_size) / 2.0
	var final_pos = target_pos + offset

	# Animate
	var style = current_style
	var all_nodes: Array = []
	for p in player_pieces + opponent_pieces:
		if is_instance_valid(p):
			all_nodes.append(p)
	await piece_node.play_move_to(final_pos, piece_size, style, all_nodes)

	_animating = false
	_position_hand_pieces()

	var label = "J1" if is_player else "J2 (IA)"
	_log("%s → celda %d" % [label, index])

	if result.is_win:
		_log("[color=green]VICTORIA: %s[/color]" % ("J1" if logic.winner == 1 else "J2"))
	elif result.is_draw:
		_log("[color=yellow]EMPATE[/color]")

	_update_status()


func _get_cell_size() -> Vector2:
	if cells.is_empty():
		return Vector2(50, 50)
	return cells[0].size


func _get_cell_pos_in_layer(index: int) -> Vector2:
	if index < 0 or index >= cells.size():
		return Vector2.ZERO
	var cell = cells[index]
	return cell.global_position - piece_layer.global_position


func _get_style() -> Resource:
	if style_option == null:
		return PlacementStyleScript.slam()
	match style_option.selected:
		0: return PlacementStyleScript.gentle()
		1: return PlacementStyleScript.slam()
		2: return PlacementStyleScript.spinning()
		3: return PlacementStyleScript.dramatic()
		4: return PlacementStyleScript.nervous()
	return PlacementStyleScript.slam()


func _update_status() -> void:
	if logic.game_over:
		if logic.winner > 0:
			status_label.text = "Victoria J%d" % logic.winner
		else:
			status_label.text = "Empate"
	else:
		status_label.text = "Turno: J%d | Mov: %d" % [logic.current_turn, logic.move_count]


func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 80:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
	await get_tree().process_frame
	log_label.scroll_to_line(log_label.get_line_count() - 1)


# ── UI Construction ──

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# ── LEFT: Controls ──
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 0.25
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 5)
	left_scroll.add_child(left)

	var back := Button.new()
	back.text = "< Dev Menu (Esc)"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://systems/dev_menu.tscn"))
	left.add_child(back)

	_lbl(left, "BOARD VISUALS", 16, Color(0.4, 0.7, 1.0))
	left.add_child(HSeparator.new())

	_lbl(left, "Tablero", 13, Color(0.6, 0.6, 0.75))
	board_size_spin = _spin(left, "Tamaño", 3, 7, 3)
	max_pieces_spin = _spin(left, "Máx fichas", -1, 10, -1)

	ai_check = CheckBox.new()
	ai_check.text = "IA oponente"
	ai_check.button_pressed = true
	ai_check.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	left.add_child(ai_check)

	left.add_child(HSeparator.new())
	_lbl(left, "Estilo de colocación", 13, Color(0.6, 0.6, 0.75))
	style_option = OptionButton.new()
	for s in STYLES:
		style_option.add_item(s)
	style_option.select(1)  # slam
	style_option.item_selected.connect(func(_i): current_style = _get_style())
	left.add_child(style_option)

	_lbl(left, "Emoción piezas", 13, Color(0.6, 0.6, 0.75))
	emotion_option = OptionButton.new()
	for e in EMOTIONS:
		emotion_option.add_item(e)
	emotion_option.item_selected.connect(func(_i): _apply_emotion())
	left.add_child(emotion_option)

	left.add_child(HSeparator.new())
	_lbl(left, "Config visual", 13, Color(0.6, 0.6, 0.75))
	checkerboard_check = CheckBox.new()
	checkerboard_check.text = "Ajedrez"
	checkerboard_check.button_pressed = true
	checkerboard_check.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	checkerboard_check.toggled.connect(func(_v): _apply_checkerboard())
	left.add_child(checkerboard_check)

	border_check = CheckBox.new()
	border_check.text = "Borde tablero"
	border_check.button_pressed = true
	border_check.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	border_check.toggled.connect(func(_v): _apply_border())
	left.add_child(border_check)

	left.add_child(HSeparator.new())
	var reset_btn := Button.new()
	reset_btn.text = "RESET"
	reset_btn.custom_minimum_size = Vector2(0, 36)
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.2, 0.5, 0.3)
	rs.set_corner_radius_all(4)
	reset_btn.add_theme_stylebox_override("normal", rs)
	reset_btn.add_theme_color_override("font_color", Color.WHITE)
	reset_btn.pressed.connect(func(): _new_game())
	left.add_child(reset_btn)

	left.add_child(HSeparator.new())
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	left.add_child(status_label)

	# ── CENTER: Board ──
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 0.5
	root.add_child(center)

	_lbl(center, "Tablero", 14, Color(0.7, 0.7, 0.8))

	opponent_hand = Control.new()
	opponent_hand.custom_minimum_size = Vector2(0, 50)
	center.add_child(opponent_hand)

	var board_center := CenterContainer.new()
	board_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(board_center)

	var aspect := AspectRatioContainer.new()
	aspect.custom_minimum_size = Vector2(300, 300)
	board_center.add_child(aspect)

	board_frame = PanelContainer.new()
	board_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	aspect.add_child(board_frame)
	_apply_border()

	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	board_frame.add_child(grid)

	player_hand = Control.new()
	player_hand.custom_minimum_size = Vector2(0, 50)
	center.add_child(player_hand)

	# Piece layer overlays the entire center area
	piece_layer = Control.new()
	piece_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	piece_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(piece_layer)

	# ── RIGHT: Log ──
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.25
	root.add_child(right_col)
	_lbl(right_col, "Eventos", 14, Color(0.7, 0.7, 0.8))
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 11)
	log_label.add_theme_color_override("default_color", Color(0.65, 0.65, 0.7))
	right_col.add_child(log_label)


func _apply_emotion() -> void:
	var emo = EMOTIONS[emotion_option.selected]
	for p in player_pieces + opponent_pieces:
		if is_instance_valid(p):
			p.set_emotion(emo)
	_log("Emoción: %s" % emo)


func _apply_checkerboard() -> void:
	var on = checkerboard_check.button_pressed
	for c in cells:
		if is_instance_valid(c):
			c.checkerboard = on
			c.queue_redraw()


func _apply_border() -> void:
	if not board_frame:
		return
	if border_check and border_check.button_pressed:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.28, 0.24)
		style.border_color = Color(0.45, 0.35, 0.25)
		style.set_border_width_all(10)
		style.set_corner_radius_all(3)
		style.set_content_margin_all(10)
		board_frame.add_theme_stylebox_override("panel", style)
	else:
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color.TRANSPARENT
		board_frame.add_theme_stylebox_override("panel", empty)


func _lbl(parent: Control, text: String, sz: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)


func _spin(parent: Control, text: String, mn: int, mx: int, dv: int) -> SpinBox:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(80, 0)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	h.add_child(l)
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.value = dv
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(s)
	return s
