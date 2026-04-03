extends Control

## Interactive test scene for N-player Board Logic system.

const BoardLogicScript = preload("res://systems/board_logic/board_logic.gd")
const GameRulesScript = preload("res://systems/board_logic/game_rules.gd")
const AIPlayerScript = preload("res://systems/board_logic/ai_player.gd")

var board: RefCounted
var ai_players: Dictionary = {}  # {player_id: AIPlayer or null (human)}
var rules: Resource
var cell_buttons: Array[Button] = []
var log_lines: Array[String] = []

# UI references
var grid: GridContainer
var log_label: RichTextLabel
var status_label: Label
var turn_label: Label
var num_players_spin: SpinBox
var board_size_spin: SpinBox
var win_length_spin: SpinBox
var max_pieces_spin: SpinBox
var overflow_option: OptionButton
var allow_draw_check: CheckBox
var player_config_container: VBoxContainer
var player_toggles: Dictionary = {}  # {player_id: {"is_ai": CheckBox, "diff": HSlider}}


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
	rules.board_size = int(board_size_spin.value)
	rules.win_length = int(win_length_spin.value)
	rules.max_pieces_per_player = int(max_pieces_spin.value)
	rules.overflow_mode = "rotate" if overflow_option.selected == 0 else "block"
	rules.allow_draw = allow_draw_check.button_pressed
	# Resize pieces_per_player to match num_players
	rules.pieces_per_player.resize(rules.num_players)
	for i in range(rules.num_players):
		rules.pieces_per_player[i] = -1

	# Validate rules
	var errors = rules.validate()
	for err in errors:
		_log("[color=red]Error: %s[/color]" % err)
	if not errors.is_empty():
		_log("[color=red]Corrige las reglas y pulsa Reset.[/color]")

	board = BoardLogicScript.new(rules)

	# Setup AI players from config
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
	_log("Nuevo juego: %dx%d, %d jugadores, ganar con %d" % [
		rules.board_size, rules.board_size, rules.num_players, rules.win_length
	])

	# If first player is AI, trigger their move
	_try_ai_move()


func _rebuild_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	cell_buttons.clear()

	grid.columns = rules.board_size
	var total = rules.get_total_cells()
	for i in range(total):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(56, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 22)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.13, 0.14, 0.19)
		style.set_corner_radius_all(4)
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
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
	if board.game_over:
		_log("Juego terminado. Pulsa Reset.")
		return

	# Check if current player is human
	if ai_players.get(board.current_turn) != null:
		_log("Es turno de la IA (Jugador %d)." % board.current_turn)
		return

	_do_player_move(index)


func _do_player_move(index: int) -> void:
	var player = board.current_turn
	var result = board.make_move(index)
	if not result.success:
		_log("Movimiento inválido en celda %d" % index)
		return

	var label = board.piece_to_string(player)
	_log("[color=#%s]%s (J%d)[/color] -> celda %d" % [
		BoardLogicScript.piece_color(player).to_html(false), label, player, index
	])
	if result.removed_cell >= 0:
		_log("  Rotación: celda %d eliminada" % result.removed_cell)

	var patterns = board.detect_patterns(index, player)
	for p in patterns:
		if not p.begins_with("move_count_"):
			_log("  Patrón: %s" % p)

	# Show near-win details
	for p_id in board.get_all_players():
		var near = board.get_near_wins(p_id)
		for nw in near:
			var c = BoardLogicScript.piece_color(p_id).to_html(false)
			_log("  [color=#%s]J%d casi gana: falta celda %d[/color]" % [c, p_id, nw.missing_cell])

	_update_display()

	if board.game_over:
		_show_game_result()
		return

	# Trigger next AI move if applicable
	_try_ai_move()


func _try_ai_move() -> void:
	if board.game_over:
		return
	var current = board.current_turn
	var ai = ai_players.get(current)
	if ai == null:
		return  # Human's turn

	# Small delay so it feels natural
	await get_tree().create_timer(0.2).timeout
	if board.game_over:
		return

	var move = ai.choose_move(board)
	if move < 0:
		_log("IA J%d: no encuentra movimiento" % current)
		return

	_do_player_move(move)


func _show_game_result() -> void:
	if board.winner != 0:
		var color_hex = BoardLogicScript.piece_color(board.winner).to_html(false)
		_log("[color=#%s]VICTORIA de J%d (%s)[/color]" % [
			color_hex, board.winner, board.piece_to_string(board.winner)
		])
		if not board.winning_pattern.is_empty():
			_log("  Línea ganadora: celdas %s" % str(board.winning_pattern))
	else:
		_log("[color=yellow]EMPATE[/color]")
	# Show global history summary
	_log("  Historial: %d movimientos totales" % board.global_history.size())


func _update_display() -> void:
	for i in range(cell_buttons.size()):
		var cell_val = board.cells[i]
		var btn: Button = cell_buttons[i]
		if cell_val == 0:
			btn.text = ""
			btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
		else:
			btn.text = board.piece_to_string(cell_val)
			btn.add_theme_color_override("font_color", BoardLogicScript.piece_color(cell_val))

	# Highlight cells: winning pattern or valid moves
	var valid = board.get_valid_moves()
	for i in range(cell_buttons.size()):
		var btn: Button = cell_buttons[i]
		var style: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
		if board.game_over and i in board.winning_pattern:
			# Winning cells glow with winner's color
			style.bg_color = BoardLogicScript.piece_color(board.winner).darkened(0.5)
			style.border_color = BoardLogicScript.piece_color(board.winner)
			style.border_width_bottom = 3
			style.border_width_top = 3
			style.border_width_left = 3
			style.border_width_right = 3
		elif not board.game_over and i in valid and ai_players.get(board.current_turn) == null:
			style.border_color = BoardLogicScript.piece_color(board.current_turn).darkened(0.3)
		else:
			style.border_color = Color(0.25, 0.25, 0.35)
		btn.add_theme_stylebox_override("normal", style)

	var p = board.current_turn
	var color_hex = BoardLogicScript.piece_color(p).to_html(false)
	var who = "IA" if ai_players.get(p) != null else "Humano"
	turn_label.text = "Turno: J%d %s (%s) [%s]" % [p, board.piece_to_string(p), who, color_hex]
	turn_label.add_theme_color_override("font_color", BoardLogicScript.piece_color(p))
	status_label.text = "Movimientos: %d | Jugadores: %d | Game Over: %s" % [
		board.move_count, rules.num_players, "Sí" if board.game_over else "No"
	]


func _rebuild_player_config() -> void:
	for child in player_config_container.get_children():
		child.queue_free()
	player_toggles.clear()

	var np = int(num_players_spin.value)
	for p in range(1, np + 1):
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		player_config_container.add_child(hbox)

		var color = BoardLogicScript.piece_color(p)
		var lbl := Label.new()
		lbl.text = "J%d %s:" % [p, BoardLogicScript.PIECE_LABELS[p] if p < BoardLogicScript.PIECE_LABELS.size() else "P%d" % p]
		lbl.custom_minimum_size = Vector2(50, 0)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", color)
		hbox.add_child(lbl)

		var ai_check := CheckBox.new()
		ai_check.text = "IA"
		ai_check.button_pressed = (p >= 2)  # Default: player 1 human, rest AI
		ai_check.add_theme_font_size_override("font_size", 12)
		ai_check.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		hbox.add_child(ai_check)

		var diff := HSlider.new()
		diff.min_value = 0.0
		diff.max_value = 1.0
		diff.step = 0.05
		diff.value = 0.5
		diff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		diff.custom_minimum_size = Vector2(60, 0)
		hbox.add_child(diff)

		var val_lbl := Label.new()
		val_lbl.text = "0.50"
		val_lbl.custom_minimum_size = Vector2(35, 0)
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		hbox.add_child(val_lbl)
		diff.value_changed.connect(func(v): val_lbl.text = "%.2f" % v)

		player_toggles[p] = {"is_ai": ai_check, "diff": diff}


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
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var root_hbox := HBoxContainer.new()
	root_hbox.add_theme_constant_override("separation", 16)
	margin.add_child(root_hbox)

	# ── Left panel: controls ──
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 0.3
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_hbox.add_child(left_scroll)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left)

	var back_btn := Button.new()
	back_btn.text = "< Dev Menu (Esc)"
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://systems/dev_menu.tscn"))
	left.add_child(back_btn)

	_section(left, "BOARD LOGIC", 18, Color(0.2, 0.8, 0.4))
	left.add_child(HSeparator.new())

	_section(left, "Reglas", 14, Color(0.7, 0.7, 0.85))
	num_players_spin = _spin(left, "Jugadores", 2, 6, 2)
	num_players_spin.value_changed.connect(func(_v): _rebuild_player_config())
	board_size_spin = _spin(left, "Tamaño tablero", 3, 7, 3)
	win_length_spin = _spin(left, "Para ganar", 3, 7, 3)
	max_pieces_spin = _spin(left, "Máx fichas/jugador", -1, 20, -1)

	overflow_option = OptionButton.new()
	overflow_option.add_item("Rotar")
	overflow_option.add_item("Bloquear")
	left.add_child(overflow_option)

	allow_draw_check = CheckBox.new()
	allow_draw_check.text = "Permitir empate"
	allow_draw_check.button_pressed = true
	allow_draw_check.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	left.add_child(allow_draw_check)

	left.add_child(HSeparator.new())
	_section(left, "Jugadores", 14, Color(0.7, 0.7, 0.85))

	player_config_container = VBoxContainer.new()
	player_config_container.add_theme_constant_override("separation", 4)
	left.add_child(player_config_container)

	left.add_child(HSeparator.new())

	var undo_redo_hbox := HBoxContainer.new()
	undo_redo_hbox.add_theme_constant_override("separation", 6)
	left.add_child(undo_redo_hbox)

	var undo_btn := Button.new()
	undo_btn.text = "Undo"
	undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_btn.custom_minimum_size = Vector2(0, 34)
	undo_btn.pressed.connect(func():
		if board.undo():
			_log("[color=gray]Undo[/color]")
			_update_display()
		else:
			_log("Nada que deshacer."))
	undo_redo_hbox.add_child(undo_btn)

	var redo_btn := Button.new()
	redo_btn.text = "Redo"
	redo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	redo_btn.custom_minimum_size = Vector2(0, 34)
	redo_btn.pressed.connect(func():
		if board.redo():
			_log("[color=gray]Redo[/color]")
			_update_display()
		else:
			_log("Nada que rehacer."))
	undo_redo_hbox.add_child(redo_btn)

	var reset_btn := Button.new()
	reset_btn.text = "RESET / NUEVA PARTIDA"
	reset_btn.custom_minimum_size = Vector2(0, 40)
	var reset_style := StyleBoxFlat.new()
	reset_style.bg_color = Color(0.2, 0.5, 0.3)
	reset_style.set_corner_radius_all(4)
	reset_btn.add_theme_stylebox_override("normal", reset_style)
	reset_btn.add_theme_color_override("font_color", Color.WHITE)
	reset_btn.pressed.connect(func(): _new_game())
	left.add_child(reset_btn)

	left.add_child(HSeparator.new())
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	left.add_child(status_label)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 15)
	left.add_child(turn_label)

	# ── Center: board grid ──
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 0.4
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	root_hbox.add_child(center)

	_section(center, "Tablero", 15, Color(0.8, 0.8, 0.9))

	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	center.add_child(grid)

	var hint := Label.new()
	hint.text = "Clic en celda = mover (si eres humano)"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(hint)

	# ── Right: log ──
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.3
	root_hbox.add_child(right)

	_section(right, "Log", 14, Color(0.7, 0.7, 0.8))

	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 12)
	log_label.add_theme_color_override("default_color", Color(0.7, 0.7, 0.75))
	right.add_child(log_label)


func _section(parent: Control, text: String, font_size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)


func _spin(parent: Control, text: String, min_v: int, max_v: int, default_v: int) -> SpinBox:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hbox.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.value = default_v
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spin)
	return spin
