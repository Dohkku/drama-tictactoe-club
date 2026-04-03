extends HSplitContainer

## Board configuration editor with live playable test board.
## Exposes both visual properties and game rules for full board customization.

const BoardConfigScript = preload("res://data/board_config.gd")
const GameRulesScript = preload("res://systems/board_logic/game_rules.gd")
const BoardScene = preload("res://board/board.tscn")

signal config_changed

var _config: Resource = null
var _suppress_sync: bool = false
var _test_board: Control = null

# --- Game Rules controls ---
var _preset_option: OptionButton
var _board_size_spin: SpinBox
var _win_length_spin: SpinBox
var _max_pieces_spin: SpinBox
var _overflow_option: OptionButton
var _allow_draw_check: CheckBox

# --- Visual controls ---
var _max_size_slider: HSlider
var _hand_height_slider: HSlider
var _piece_ratio_slider: HSlider
var _cell_line_width_slider: HSlider

var _cell_empty_picker: ColorPickerButton
var _cell_alt_picker: ColorPickerButton
var _checkerboard_check: CheckBox
var _cell_hover_picker: ColorPickerButton
var _cell_line_picker: ColorPickerButton
var _player_color_picker: ColorPickerButton
var _opponent_color_picker: ColorPickerButton
var _board_bg_picker: ColorPickerButton
var _border_enabled_check: CheckBox
var _border_color_picker: ColorPickerButton
var _border_width_slider: HSlider


func _ready() -> void:
	_config = BoardConfigScript.create_default()
	_suppress_sync = true
	_build_ui()
	_apply_config_to_ui()
	_suppress_sync = false

	# Apply config to test board now that it's in the tree
	if _test_board:
		_test_board.apply_board_config(_config)

	EventBus.match_ended.connect(_on_test_match_ended)


func get_config() -> Resource:
	return _config


func set_config(cfg: Resource) -> void:
	if cfg == null or not (cfg is BoardConfigScript):
		_config = BoardConfigScript.create_default()
	else:
		_config = cfg
		# Ensure game_rules is populated
		_config.get_rules()
	_suppress_sync = true
	_apply_config_to_ui()
	_suppress_sync = false
	_rebuild_test_board()


func _build_ui() -> void:
	# --- Left panel ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(360, 0)
	add_child(scroll)

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 6)
	scroll.add_child(form)

	var header := Label.new()
	header.text = "Configuración del Tablero"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	form.add_child(header)
	form.add_child(HSeparator.new())

	# ── Game Rules Section ──
	_add_section_label(form, "Reglas de juego")

	# Presets
	_preset_option = _add_option_button(form, "Preset", ["Estándar", "Rotación (3 fichas)", "Tablero grande (5x5)"])
	_preset_option.item_selected.connect(_on_preset_selected)

	_board_size_spin = _add_spin_box(form, "Tamaño tablero", 3, 7, 1, 3)
	_board_size_spin.value_changed.connect(func(_v): _on_rules_changed())

	_win_length_spin = _add_spin_box(form, "Fichas para ganar", 3, 7, 1, 3)
	_win_length_spin.value_changed.connect(func(_v): _on_rules_changed())

	_max_pieces_spin = _add_spin_box(form, "Máx fichas por jugador", -1, 20, 1, -1)
	_max_pieces_spin.tooltip_text = "-1 = ilimitado"
	_max_pieces_spin.value_changed.connect(func(_v): _on_rules_changed())

	_overflow_option = _add_option_button(form, "Al exceder máximo", ["Rotar (quitar más vieja)", "Bloquear"])
	_overflow_option.item_selected.connect(func(_i): _on_rules_changed())

	_allow_draw_check = _add_check_box(form, "Permitir empate", true)
	_allow_draw_check.toggled.connect(func(_v): _on_rules_changed())

	form.add_child(HSeparator.new())

	# ── Visual Section ──
	_add_section_label(form, "Tamaño")
	_max_size_slider = _add_slider(form, "Tamaño máx. tablero (px)", 150, 800, 10)
	_hand_height_slider = _add_slider(form, "Altura área fichas (px)", 20, 100, 5)
	_piece_ratio_slider = _add_slider(form, "Ratio ficha/casilla", 0.5, 1.0, 0.05)

	form.add_child(HSeparator.new())
	_add_section_label(form, "Casillas")
	_cell_empty_picker = _add_color_picker(form, "Color casilla")
	_checkerboard_check = _add_check_box(form, "Patrón ajedrez", false)
	_checkerboard_check.toggled.connect(func(_v): _on_visual_changed())
	_cell_alt_picker = _add_color_picker(form, "Color casilla alterno")
	_cell_hover_picker = _add_color_picker(form, "Color hover")
	_cell_line_picker = _add_color_picker(form, "Líneas de casilla")
	_cell_line_width_slider = _add_slider(form, "Grosor líneas (px)", 1.0, 5.0, 0.5)

	form.add_child(HSeparator.new())
	_add_section_label(form, "Borde / Marco")
	_border_enabled_check = _add_check_box(form, "Borde del tablero", false)
	_border_enabled_check.toggled.connect(func(_v): _on_visual_changed())
	_border_color_picker = _add_color_picker(form, "Color del borde")
	_border_width_slider = _add_slider(form, "Grosor del borde (px)", 2.0, 30.0, 1.0)
	_board_bg_picker = _add_color_picker(form, "Fondo tablero")

	form.add_child(HSeparator.new())
	_add_section_label(form, "Colores de jugadores")
	_player_color_picker = _add_color_picker(form, "Color jugador (defecto)")
	_opponent_color_picker = _add_color_picker(form, "Color oponente (defecto)")

	# --- Right panel: live test board ---
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(right)

	var lbl := Label.new()
	lbl.text = "Tablero de prueba"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.85))
	right.add_child(lbl)

	_test_board = BoardScene.instantiate()
	_test_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_test_board)


func _on_test_match_ended(_result: String) -> void:
	if not _test_board or not is_instance_valid(_test_board):
		return
	await get_tree().create_timer(1.0).timeout
	if _test_board and is_instance_valid(_test_board):
		_test_board._start_game()


# ── Change handlers ──

func _on_preset_selected(idx: int) -> void:
	if _suppress_sync:
		return
	var rules: Resource
	match idx:
		1:  # Rotating 3
			rules = GameRulesScript.rotating_3()
		2:  # Big board
			rules = GameRulesScript.big_board()
		_:  # Standard
			rules = GameRulesScript.new()
	_config.game_rules = rules
	_suppress_sync = true
	_apply_rules_to_ui()
	_suppress_sync = false
	_rebuild_test_board()
	config_changed.emit()


func _on_rules_changed() -> void:
	## Called when any game rule control changes. Requires board rebuild.
	if _suppress_sync:
		return
	_sync_rules_from_ui()
	# Clamp win_length to board_size
	var rules = _config.get_rules()
	_win_length_spin.max_value = rules.board_size
	if rules.win_length > rules.board_size:
		rules.win_length = rules.board_size
		_suppress_sync = true
		_win_length_spin.value = rules.win_length
		_suppress_sync = false
	_rebuild_test_board()
	config_changed.emit()


func _on_visual_changed(_value = null) -> void:
	## Called when any visual-only control changes. No board rebuild needed.
	if _suppress_sync:
		return
	_sync_visuals_from_ui()
	_apply_config_to_test_board()
	config_changed.emit()


# ── Sync methods ──

func _apply_config_to_ui() -> void:
	_apply_rules_to_ui()
	_apply_visuals_to_ui()


func _apply_rules_to_ui() -> void:
	var rules = _config.get_rules()
	_board_size_spin.value = rules.board_size
	_win_length_spin.max_value = rules.board_size
	_win_length_spin.value = rules.win_length
	_max_pieces_spin.value = rules.max_pieces_per_player
	_overflow_option.select(0 if rules.overflow_mode == "rotate" else 1)
	_allow_draw_check.button_pressed = rules.allow_draw
	# Update preset dropdown to match (best effort)
	_preset_option.select(_detect_preset(rules))


func _apply_visuals_to_ui() -> void:
	_max_size_slider.value = _config.max_board_size
	_hand_height_slider.value = _config.hand_area_height
	_piece_ratio_slider.value = _config.piece_cell_ratio
	_cell_line_width_slider.value = _config.cell_line_width

	_cell_empty_picker.color = _config.cell_color_empty
	_cell_alt_picker.color = _config.cell_color_alt
	_checkerboard_check.button_pressed = _config.checkerboard_enabled
	_cell_hover_picker.color = _config.cell_color_hover
	_cell_line_picker.color = _config.cell_line_color
	_board_bg_picker.color = _config.board_bg_color
	_border_enabled_check.button_pressed = _config.board_border_enabled
	_border_color_picker.color = _config.board_border_color
	_border_width_slider.value = _config.board_border_width
	_player_color_picker.color = _config.default_player_color
	_opponent_color_picker.color = _config.default_opponent_color


func _sync_rules_from_ui() -> void:
	var rules = _config.get_rules()
	rules.board_size = int(_board_size_spin.value)
	rules.win_length = int(_win_length_spin.value)
	rules.max_pieces_per_player = int(_max_pieces_spin.value)
	rules.overflow_mode = "rotate" if _overflow_option.selected == 0 else "block"
	rules.allow_draw = _allow_draw_check.button_pressed


func _sync_visuals_from_ui() -> void:
	_config.max_board_size = int(_max_size_slider.value)
	_config.hand_area_height = int(_hand_height_slider.value)
	_config.piece_cell_ratio = _piece_ratio_slider.value
	_config.cell_line_width = _cell_line_width_slider.value

	_config.cell_color_empty = _cell_empty_picker.color
	_config.cell_color_alt = _cell_alt_picker.color
	_config.checkerboard_enabled = _checkerboard_check.button_pressed
	_config.cell_color_hover = _cell_hover_picker.color
	_config.cell_line_color = _cell_line_picker.color
	_config.board_bg_color = _board_bg_picker.color
	_config.board_border_enabled = _border_enabled_check.button_pressed
	_config.board_border_color = _border_color_picker.color
	_config.board_border_width = _border_width_slider.value
	_config.default_player_color = _player_color_picker.color
	_config.default_opponent_color = _opponent_color_picker.color


# ── Test board management ──

func _apply_config_to_test_board() -> void:
	if not _test_board or not is_instance_valid(_test_board):
		return
	_test_board.apply_board_config(_config)


func _rebuild_test_board() -> void:
	## Rebuild the test board with current game rules + apply visual config.
	if not _test_board or not is_instance_valid(_test_board):
		return
	_test_board.full_reset(_config.get_rules())
	_test_board.apply_board_config(_config)


func _detect_preset(rules: Resource) -> int:
	## Returns preset index that matches current rules, or 0 (standard) as fallback.
	if rules.board_size == 3 and rules.win_length == 3 and rules.max_pieces_per_player == 3 \
			and rules.overflow_mode == "rotate" and not rules.allow_draw:
		return 1  # Rotating 3
	if rules.board_size == 5 and rules.win_length == 4 and rules.max_pieces_per_player == -1:
		return 2  # Big board
	if rules.board_size == 3 and rules.win_length == 3 and rules.max_pieces_per_player == -1 \
			and rules.allow_draw:
		return 0  # Standard
	return 0  # Fallback


# --- UI Helpers ---

func _add_section_label(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.7, 0.9))
	parent.add_child(lbl)


func _add_slider(parent: Control, label_text: String, min_val: float, max_val: float, step: float) -> HSlider:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9))
	hbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(slider)

	var val_label := Label.new()
	val_label.custom_minimum_size = Vector2(50, 0)
	val_label.add_theme_font_size_override("font_size", 13)
	val_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	hbox.add_child(val_label)

	slider.value_changed.connect(func(v):
		val_label.text = str(snapped(v, step)) if step >= 1.0 else "%.2f" % v
		_on_visual_changed()
	)
	val_label.text = str(snapped(min_val, step)) if step >= 1.0 else "%.2f" % min_val

	return slider


func _add_color_picker(parent: Control, label_text: String) -> ColorPickerButton:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9))
	hbox.add_child(lbl)

	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(60, 28)
	picker.edit_alpha = false
	hbox.add_child(picker)

	picker.color_changed.connect(func(_c): _on_visual_changed())

	return picker


func _add_spin_box(parent: Control, label_text: String, min_val: int, max_val: int, step: int, default_val: int) -> SpinBox:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9))
	hbox.add_child(lbl)

	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value = default_val
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(spin)

	return spin


func _add_option_button(parent: Control, label_text: String, options: Array) -> OptionButton:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9))
	hbox.add_child(lbl)

	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option_text in options:
		opt.add_item(option_text)
	hbox.add_child(opt)

	return opt


func _add_check_box(parent: Control, label_text: String, default_val: bool) -> CheckBox:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9))
	hbox.add_child(lbl)

	var check := CheckBox.new()
	check.button_pressed = default_val
	hbox.add_child(check)

	return check
