extends Control

## Interactive test scene for the Board Logic system.
## Test game rules, moves, AI, abilities, patterns - all without visuals.

const BoardLogicScript = preload("res://systems/board_logic/board_logic.gd")
const GameRulesScript = preload("res://systems/board_logic/game_rules.gd")
const AIPlayerScript = preload("res://systems/board_logic/ai_player.gd")

var board: RefCounted
var ai: RefCounted
var rules: Resource
var cell_labels: Array[Button] = []
var log_lines: Array[String] = []

# UI references
var grid: GridContainer
var log_label: RichTextLabel
var status_label: Label
var turn_label: Label
var ai_diff_slider: HSlider
var board_size_spin: SpinBox
var win_length_spin: SpinBox
var max_pieces_spin: SpinBox
var overflow_option: OptionButton
var allow_draw_check: CheckBox


func _ready() -> void:
	_build_ui()
	_new_game()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://systems/dev_menu.tscn")


func _new_game() -> void:
	rules = GameRulesScript.new()
	rules.board_size = int(board_size_spin.value)
	rules.win_length = int(win_length_spin.value)
	rules.max_pieces_per_player = int(max_pieces_spin.value)
	rules.overflow_mode = "rotate" if overflow_option.selected == 0 else "block"
	rules.allow_draw = allow_draw_check.button_pressed

	board = BoardLogicScript.new(rules)
	ai = AIPlayerScript.new()
	ai.difficulty = ai_diff_slider.value

	_rebuild_grid()
	_update_display()
	_log("Nuevo juego: %dx%d, ganar con %d, max fichas: %d" % [
		rules.board_size, rules.win_length, rules.win_length,
		rules.max_pieces_per_player
	])


func _rebuild_grid() -> void:
	# Clear old cells
	for child in grid.get_children():
		child.queue_free()
	cell_labels.clear()

	grid.columns = rules.board_size
	var total = rules.get_total_cells()
	for i in range(total):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(60, 60)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 24)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.17, 0.22)
		style.set_corner_radius_all(4)
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = Color(0.3, 0.3, 0.4)
		btn.add_theme_stylebox_override("normal", style)

		var style_h := style.duplicate()
		style_h.bg_color = Color(0.2, 0.25, 0.35)
		btn.add_theme_stylebox_override("hover", style_h)

		var idx := i
		btn.pressed.connect(func(): _on_cell_pressed(idx))
		grid.add_child(btn)
		cell_labels.append(btn)


func _on_cell_pressed(index: int) -> void:
	if board.game_over:
		_log("Juego terminado. Pulsa Reset.")
		return
	if board.current_turn != 1:
		_log("No es tu turno.")
		return

	var result = board.make_move(index)
	if not result.success:
		_log("Movimiento inválido en celda %d" % index)
		return

	_log("Jugador -> celda %d" % index)
	if result.removed_cell >= 0:
		_log("  Rotación: celda %d eliminada" % result.removed_cell)

	# Detect patterns
	var patterns = board.detect_patterns(index, 1)
	if not patterns.is_empty():
		_log("  Patrones: %s" % ", ".join(patterns))

	_update_display()

	if board.game_over:
		_show_game_result()
		return

	# Auto AI turn
	_do_ai_turn()


func _do_ai_turn() -> void:
	if board.game_over or board.current_turn != 2:
		return

	var move = ai.choose_move(board)
	if move < 0:
		_log("IA: no encuentra movimiento")
		return

	var result = board.make_move(move)
	if result.success:
		_log("IA (dif %.2f) -> celda %d" % [ai.difficulty, move])
		if result.removed_cell >= 0:
			_log("  Rotación: celda %d eliminada" % result.removed_cell)
		var patterns = board.detect_patterns(move, 2)
		if not patterns.is_empty():
			_log("  Patrones: %s" % ", ".join(patterns))

	_update_display()

	if board.game_over:
		_show_game_result()


func _show_game_result() -> void:
	if board.winner == 1:
		_log("[color=green]VICTORIA del jugador (X)[/color]")
	elif board.winner == 2:
		_log("[color=red]VICTORIA de la IA (O)[/color]")
	else:
		_log("[color=yellow]EMPATE[/color]")


func _update_display() -> void:
	for i in range(cell_labels.size()):
		var cell_val = board.cells[i]
		var btn: Button = cell_labels[i]
		match cell_val:
			0:
				btn.text = "-"
				btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
			1:
				btn.text = "X"
				btn.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
			2:
				btn.text = "O"
				btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	var turn_text = "X (Jugador)" if board.current_turn == 1 else "O (IA)"
	turn_label.text = "Turno: %s" % turn_text
	status_label.text = "Movimientos: %d | Game Over: %s" % [board.move_count, "Sí" if board.game_over else "No"]


func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 50:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
	# Scroll to bottom
	await get_tree().process_frame
	log_label.scroll_to_line(log_label.get_line_count() - 1)


func _on_ai_move_pressed() -> void:
	if board.game_over:
		_log("Juego terminado.")
		return
	if board.current_turn == 2:
		_do_ai_turn()
	else:
		_log("Es turno del jugador, no de la IA.")


func _on_reset_pressed() -> void:
	_new_game()


# ── UI Construction ──

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_hbox := HBoxContainer.new()
	root_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_hbox.add_theme_constant_override("separation", 12)
	add_child(root_hbox)

	# Left panel: controls
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.35
	left.add_theme_constant_override("separation", 8)
	root_hbox.add_child(left)

	var back_btn := Button.new()
	back_btn.text = "< Dev Menu (Esc)"
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://systems/dev_menu.tscn"))
	left.add_child(back_btn)

	var header := Label.new()
	header.text = "BOARD LOGIC SYSTEM"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4))
	left.add_child(header)

	left.add_child(HSeparator.new())
	_add_label(left, "Reglas", 14, Color(0.7, 0.7, 0.8))

	board_size_spin = _add_spin(left, "Tamaño tablero", 3, 7, 3)
	win_length_spin = _add_spin(left, "Para ganar", 3, 7, 3)
	max_pieces_spin = _add_spin(left, "Máx fichas/jugador", -1, 20, -1)

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
	_add_label(left, "IA", 14, Color(0.7, 0.7, 0.8))

	var diff_hbox := HBoxContainer.new()
	left.add_child(diff_hbox)
	var diff_lbl := Label.new()
	diff_lbl.text = "Dificultad: "
	diff_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	diff_hbox.add_child(diff_lbl)
	ai_diff_slider = HSlider.new()
	ai_diff_slider.min_value = 0.0
	ai_diff_slider.max_value = 1.0
	ai_diff_slider.step = 0.05
	ai_diff_slider.value = 0.5
	ai_diff_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_hbox.add_child(ai_diff_slider)
	var diff_val := Label.new()
	diff_val.text = "0.50"
	diff_val.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	diff_hbox.add_child(diff_val)
	ai_diff_slider.value_changed.connect(func(v): diff_val.text = "%.2f" % v)

	left.add_child(HSeparator.new())

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	left.add_child(btn_hbox)

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.custom_minimum_size = Vector2(80, 36)
	reset_btn.pressed.connect(_on_reset_pressed)
	btn_hbox.add_child(reset_btn)

	var ai_btn := Button.new()
	ai_btn.text = "IA Mueve"
	ai_btn.custom_minimum_size = Vector2(80, 36)
	ai_btn.pressed.connect(_on_ai_move_pressed)
	btn_hbox.add_child(ai_btn)

	left.add_child(HSeparator.new())
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	left.add_child(status_label)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 14)
	turn_label.add_theme_color_override("font_color", Color.WHITE)
	left.add_child(turn_label)

	# Center: board grid
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 0.35
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	root_hbox.add_child(center)

	_add_label(center, "Tablero", 16, Color(0.8, 0.8, 0.9))

	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	center.add_child(grid)

	_add_label(center, "Haz clic en una celda para mover", 11, Color(0.5, 0.5, 0.6))

	# Right: log
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.3
	root_hbox.add_child(right)

	_add_label(right, "Log", 14, Color(0.7, 0.7, 0.8))

	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 12)
	log_label.add_theme_color_override("default_color", Color(0.75, 0.75, 0.8))
	right.add_child(log_label)


func _add_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl


func _add_spin(parent: Control, text: String, min_v: int, max_v: int, default_v: int) -> SpinBox:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hbox.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.value = default_v
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spin)
	return spin
