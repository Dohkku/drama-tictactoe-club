extends Control

## Interactive test scene for Board Logic system.
## Tests: N players, non-square boards, blocked/special cells, win conditions, MoveResult events.

const BoardLogicScript = preload("res://systems/board_logic/board_logic.gd")
const GameRulesScript = preload("res://systems/board_logic/game_rules.gd")
const AIPlayerScript = preload("res://systems/board_logic/ai_player.gd")
const MoveResultScript = preload("res://systems/board_logic/move_result.gd")

var board: RefCounted
var ai_players: Dictionary = {}
var rules: Resource
var cell_buttons: Array[Button] = []
var log_lines: Array[String] = []

# Edit mode for special cells: "" = play, "block" = toggle blocked, "special" = cycle special
var edit_mode: String = ""

# UI references
var grid: GridContainer
var log_label: RichTextLabel
var status_label: Label
var turn_label: Label
var num_players_spin: SpinBox
var board_width_spin: SpinBox
var board_height_spin: SpinBox
var win_length_spin: SpinBox
var max_pieces_spin: SpinBox
var overflow_option: OptionButton
var allow_draw_check: CheckBox
var win_condition_option: OptionButton
var player_config_container: VBoxContainer
var player_toggles: Dictionary = {}

const WIN_CONDITIONS := ["n_in_row", "control_corners", "most_pieces"]
const WIN_CONDITION_LABELS := ["N en raya", "Controlar esquinas", "Más fichas"]


func _ready() -> void:
	_build_ui()
	_rebuild_player_config()
	_new_game()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://systems/dev_menu.tscn")


func _new_game() -> void:
	rules = GameRulesScript.new()
	rules.num_players = int(num_players_spin.value)
	rules.board_width = int(board_width_spin.value)
	rules.board_height = int(board_height_spin.value)
	rules.win_length = int(win_length_spin.value)
	rules.max_pieces_per_player = int(max_pieces_spin.value)
	rules.overflow_mode = "rotate" if overflow_option.selected == 0 else "block"
	rules.allow_draw = allow_draw_check.button_pressed
	rules.win_condition = WIN_CONDITIONS[win_condition_option.selected]
	rules.pieces_per_player.resize(rules.num_players)
	for i in range(rules.num_players):
		rules.pieces_per_player[i] = -1

	var errors = rules.validate()
	for err in errors:
		_log("[color=red]%s[/color]" % err)

	board = BoardLogicScript.new(rules)

	ai_players.clear()
	for p in range(1, rules.num_players + 1):
		if player_toggles.has(p) and player_toggles[p].is_ai.button_pressed:
			var ai = AIPlayerScript.new()
			ai.difficulty = player_toggles[p].diff.value
			ai_players[p] = ai
		else:
			ai_players[p] = null

	_rebuild_grid()
	_update_display()
	var w = rules.get_width()
	var h = rules.get_height()
	_log("Nuevo: %dx%d, %dJ, ganar=%s, cond=%s" % [
		w, h, rules.num_players, str(rules.win_length), rules.win_condition
	])
	_try_ai_move()


func _rebuild_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	cell_buttons.clear()

	grid.columns = rules.get_width()
	var total = rules.get_total_cells()
	for i in range(total):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(48, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 20)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.13, 0.14, 0.19)
		style.set_corner_radius_all(4)
		style.set_border_width_all(2)
		style.border_color = Color(0.25, 0.25, 0.35)
		btn.add_theme_stylebox_override("normal", style)
		var style_h := style.duplicate()
		style_h.bg_color = Color(0.2, 0.22, 0.3)
		btn.add_theme_stylebox_override("hover", style_h)

		var idx := i
		btn.pressed.connect(func(): _on_cell_pressed(idx))
		grid.add_child(btn)
		cell_buttons.append(btn)


func _on_cell_pressed(index: int) -> void:
	if edit_mode == "block":
		_toggle_blocked(index)
		return
	if edit_mode == "special":
		_cycle_special(index)
		return

	if board.game_over:
		_log("Juego terminado. Pulsa Reset.")
		return
	if ai_players.get(board.current_turn) != null:
		_log("Turno de IA (J%d)." % board.current_turn)
		return
	_do_player_move(index)


func _toggle_blocked(index: int) -> void:
	if index in rules.blocked_cells:
		rules.blocked_cells.erase(index)
		_log("Celda %d: desbloqueada" % index)
	else:
		rules.blocked_cells.append(index)
		_log("Celda %d: bloqueada" % index)
	# Rebuild board with new blocked cells
	board = BoardLogicScript.new(rules)
	_update_display()


func _cycle_special(index: int) -> void:
	if index in rules.blocked_cells:
		_log("No se puede hacer especial una celda bloqueada")
		return
	var types := ["", "bonus", "trap", "wild"]
	var current_type: String = rules.special_cells.get(index, {}).get("type", "")
	var idx = types.find(current_type)
	var next_type: String = types[(idx + 1) % types.size()]
	if next_type == "":
		rules.special_cells.erase(index)
		_log("Celda %d: normal" % index)
	else:
		rules.special_cells[index] = {"type": next_type}
		_log("Celda %d: [color=yellow]%s[/color]" % [index, next_type])
	_update_display()


func _do_player_move(index: int) -> void:
	var player = board.current_turn
	var result = board.make_move(index)
	if not result.success:
		_log("Movimiento inválido en celda %d" % index)
		return

	_log_move_result(result)
	_update_display()

	if board.game_over:
		_show_game_result()
		return
	_try_ai_move()


func _log_move_result(result: RefCounted) -> void:
	var c = BoardLogicScript.piece_color(result.player).to_html(false)
	var label = board.piece_to_string(result.player)
	_log("[color=#%s]%s (J%d)[/color] -> celda %d" % [c, label, result.player, result.cell])

	for ev in result.events:
		match ev.type:
			MoveResultScript.PIECE_ROTATED:
				_log("  Rotación: celda %d eliminada" % ev.data.removed_cell)
			MoveResultScript.NEAR_WIN:
				var nc = BoardLogicScript.piece_color(ev.data.player).to_html(false)
				_log("  [color=#%s]J%d casi gana (falta celda %d)[/color]" % [nc, ev.data.player, ev.data.missing_cell])
			MoveResultScript.FORK:
				var fc = BoardLogicScript.piece_color(ev.data.player).to_html(false)
				_log("  [color=#%s]J%d FORK (%d amenazas)[/color]" % [fc, ev.data.player, ev.data.count])
			MoveResultScript.CENTER_TAKEN:
				_log("  Centro tomado")
			MoveResultScript.CORNER_TAKEN:
				_log("  Esquina tomada")
			MoveResultScript.SPECIAL_CELL:
				_log("  [color=yellow]Celda especial: %s -> %s[/color]" % [ev.data.type, ev.data.effect])
			MoveResultScript.WIN:
				_log("  [color=green]VICTORIA: celdas %s[/color]" % str(ev.data.pattern))
			MoveResultScript.DRAW:
				_log("  [color=yellow]EMPATE[/color]")


func _try_ai_move() -> void:
	if board.game_over:
		return
	var ai = ai_players.get(board.current_turn)
	if ai == null:
		return
	await get_tree().create_timer(0.15).timeout
	if board.game_over:
		return
	var move = ai.choose_move(board)
	if move < 0:
		_log("IA J%d: sin movimiento" % board.current_turn)
		return
	_do_player_move(move)


func _show_game_result() -> void:
	if board.winner != 0:
		var c = BoardLogicScript.piece_color(board.winner).to_html(false)
		_log("[color=#%s]VICTORIA J%d (%s)[/color]" % [c, board.winner, board.piece_to_string(board.winner)])
		if not board.winning_pattern.is_empty():
			_log("  Línea: %s" % str(board.winning_pattern))
	else:
		_log("[color=yellow]EMPATE[/color]")
	_log("  Total: %d movimientos" % board.global_history.size())


func _update_display() -> void:
	for i in range(cell_buttons.size()):
		var cell_val = board.cells[i]
		var btn: Button = cell_buttons[i]
		var style: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()

		if cell_val == BoardLogicScript.BLOCKED:
			btn.text = "■"
			btn.add_theme_color_override("font_color", Color(0.3, 0.15, 0.15))
			style.bg_color = Color(0.08, 0.06, 0.06)
			style.border_color = Color(0.3, 0.15, 0.15)
		elif cell_val == 0:
			# Show special cell indicator
			var special = rules.special_cells.get(i, {})
			var sp_type: String = special.get("type", "")
			match sp_type:
				"bonus": btn.text = "+"; btn.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3, 0.5))
				"trap": btn.text = "!"; btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 0.5))
				"wild": btn.text = "*"; btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3, 0.5))
				_: btn.text = ""; btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
			style.bg_color = Color(0.13, 0.14, 0.19)
			style.border_color = Color(0.25, 0.25, 0.35)
		else:
			btn.text = board.piece_to_string(cell_val)
			btn.add_theme_color_override("font_color", BoardLogicScript.piece_color(cell_val))
			style.bg_color = Color(0.13, 0.14, 0.19)
			style.border_color = Color(0.25, 0.25, 0.35)

		# Highlight winning pattern
		if board.game_over and i in board.winning_pattern:
			style.bg_color = BoardLogicScript.piece_color(board.winner).darkened(0.5)
			style.border_color = BoardLogicScript.piece_color(board.winner)
			style.set_border_width_all(3)
		# Highlight valid moves
		elif not board.game_over and i in board.get_valid_moves() and ai_players.get(board.current_turn) == null:
			style.border_color = BoardLogicScript.piece_color(board.current_turn).darkened(0.3)

		btn.add_theme_stylebox_override("normal", style)

	if not board.game_over:
		var p = board.current_turn
		var who = "IA" if ai_players.get(p) != null else "Humano"
		turn_label.text = "Turno: J%d %s (%s)" % [p, board.piece_to_string(p), who]
		turn_label.add_theme_color_override("font_color", BoardLogicScript.piece_color(p))
	else:
		turn_label.text = "Fin"
		turn_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	var w = rules.get_width()
	var h = rules.get_height()
	status_label.text = "Mov: %d | %dx%d | %dJ | %s" % [
		board.move_count, w, h, rules.num_players, rules.win_condition
	]


func _rebuild_player_config() -> void:
	for child in player_config_container.get_children():
		child.queue_free()
	player_toggles.clear()
	var np = int(num_players_spin.value)
	for p in range(1, np + 1):
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		player_config_container.add_child(hbox)
		var color = BoardLogicScript.piece_color(p)
		var lbl := Label.new()
		lbl.text = "J%d:" % p
		lbl.custom_minimum_size = Vector2(30, 0)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", color)
		hbox.add_child(lbl)
		var ai_check := CheckBox.new()
		ai_check.text = "IA"
		ai_check.button_pressed = (p >= 2)
		ai_check.add_theme_font_size_override("font_size", 11)
		hbox.add_child(ai_check)
		var diff := HSlider.new()
		diff.min_value = 0.0; diff.max_value = 1.0; diff.step = 0.05; diff.value = 0.5
		diff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		diff.custom_minimum_size = Vector2(50, 0)
		hbox.add_child(diff)
		player_toggles[p] = {"is_ai": ai_check, "diff": diff}


func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 100:
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
	left_scroll.size_flags_stretch_ratio = 0.28
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

	_lbl(left, "BOARD LOGIC", 16, Color(0.2, 0.8, 0.4))
	left.add_child(HSeparator.new())

	_lbl(left, "Tablero", 13, Color(0.6, 0.6, 0.75))
	board_width_spin = _spin(left, "Ancho", 3, 7, 3)
	board_height_spin = _spin(left, "Alto", 3, 7, 3)
	num_players_spin = _spin(left, "Jugadores", 2, 6, 2)
	num_players_spin.value_changed.connect(func(_v): _rebuild_player_config())
	win_length_spin = _spin(left, "Para ganar", 3, 7, 3)
	max_pieces_spin = _spin(left, "Máx fichas", -1, 20, -1)
	overflow_option = OptionButton.new()
	overflow_option.add_item("Rotar"); overflow_option.add_item("Bloquear")
	left.add_child(overflow_option)
	allow_draw_check = CheckBox.new()
	allow_draw_check.text = "Permitir empate"
	allow_draw_check.button_pressed = true
	allow_draw_check.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	left.add_child(allow_draw_check)

	_lbl(left, "Condición victoria", 13, Color(0.6, 0.6, 0.75))
	win_condition_option = OptionButton.new()
	for wl in WIN_CONDITION_LABELS:
		win_condition_option.add_item(wl)
	left.add_child(win_condition_option)

	left.add_child(HSeparator.new())
	_lbl(left, "Jugadores", 13, Color(0.6, 0.6, 0.75))
	player_config_container = VBoxContainer.new()
	player_config_container.add_theme_constant_override("separation", 3)
	left.add_child(player_config_container)

	left.add_child(HSeparator.new())
	_lbl(left, "Editar tablero", 13, Color(0.6, 0.6, 0.75))
	var edit_hbox := HBoxContainer.new()
	edit_hbox.add_theme_constant_override("separation", 4)
	left.add_child(edit_hbox)
	var block_btn := Button.new()
	block_btn.text = "Bloquear"
	block_btn.toggle_mode = true
	block_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block_btn.toggled.connect(func(on): edit_mode = "block" if on else "")
	edit_hbox.add_child(block_btn)
	var special_btn := Button.new()
	special_btn.text = "Especial"
	special_btn.toggle_mode = true
	special_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	special_btn.toggled.connect(func(on): edit_mode = "special" if on else "")
	edit_hbox.add_child(special_btn)

	left.add_child(HSeparator.new())
	var undo_hbox := HBoxContainer.new()
	undo_hbox.add_theme_constant_override("separation", 4)
	left.add_child(undo_hbox)
	var undo_btn := Button.new()
	undo_btn.text = "Undo"
	undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_btn.pressed.connect(func():
		if board.undo(): _log("[color=gray]Undo[/color]"); _update_display()
		else: _log("Nada que deshacer."))
	undo_hbox.add_child(undo_btn)
	var redo_btn := Button.new()
	redo_btn.text = "Redo"
	redo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	redo_btn.pressed.connect(func():
		if board.redo(): _log("[color=gray]Redo[/color]"); _update_display()
		else: _log("Nada que rehacer."))
	undo_hbox.add_child(redo_btn)

	var reset_btn := Button.new()
	reset_btn.text = "RESET"
	reset_btn.custom_minimum_size = Vector2(0, 36)
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.2, 0.5, 0.3); rs.set_corner_radius_all(4)
	reset_btn.add_theme_stylebox_override("normal", rs)
	reset_btn.add_theme_color_override("font_color", Color.WHITE)
	reset_btn.pressed.connect(func(): _new_game())
	left.add_child(reset_btn)

	left.add_child(HSeparator.new())
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	left.add_child(status_label)
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 14)
	left.add_child(turn_label)

	# ── CENTER: Grid ──
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 0.4
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(center)
	_lbl(center, "Tablero", 14, Color(0.7, 0.7, 0.8))
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	center.add_child(grid)
	_lbl(center, "Clic = mover | Bloquear/Especial = editar celdas", 10, Color(0.4, 0.4, 0.5))

	# ── RIGHT: Log ──
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.32
	root.add_child(right)
	_lbl(right, "Eventos", 14, Color(0.7, 0.7, 0.8))
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 11)
	log_label.add_theme_color_override("default_color", Color(0.65, 0.65, 0.7))
	right.add_child(log_label)


func _lbl(parent: Control, text: String, sz: int, col: Color) -> void:
	var l := Label.new()
	l.text = text; l.add_theme_font_size_override("font_size", sz); l.add_theme_color_override("font_color", col)
	parent.add_child(l)

func _spin(parent: Control, text: String, mn: int, mx: int, dv: int) -> SpinBox:
	var h := HBoxContainer.new(); parent.add_child(h)
	var l := Label.new(); l.text = text; l.custom_minimum_size = Vector2(80, 0)
	l.add_theme_font_size_override("font_size", 11); l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	h.add_child(l)
	var s := SpinBox.new(); s.min_value = mn; s.max_value = mx; s.value = dv
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(s)
	return s
