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
const PieceDesignScript = preload("res://systems/board_visuals/piece_design.gd")
const PieceEffectScript = preload("res://systems/board_visuals/piece_effect.gd")
const PieceEffectPlayerScript = preload("res://systems/board_visuals/piece_effect_player.gd")
const ScreenEffectsScript = preload("res://systems/board_visuals/screen_effects.gd")
const BoardAudioScript = preload("res://systems/board_visuals/board_audio.gd")

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
var screen_fx: Control = null
var board_audio: Node = null
var _win_line_node: Control = null
var win_line_color_picker: ColorPickerButton
var win_line_width_spin: SpinBox
var win_line_auto_color_check: CheckBox
var placement_offset_max: float = 0.0  # Max random offset as fraction of cell size (0 = perfect center)
var log_lines: Array[String] = []

# Piece selection (dormant — infrastructure for future ability-based pieces)
# Flow: click piece in hand → selected_piece = piece → click cell → place selected_piece
# Activate by calling piece.set_selectable(true) on hand pieces
var selected_piece: Control = null

# UI references
var grid: GridContainer
var piece_layer: Control
var player_hand: Control
var opponent_hand: Control
var board_frame: PanelContainer
var board_aspect: AspectRatioContainer
var hand_align: int = 1  # 0=left, 1=center, 2=right
var hand_compact: bool = true  # true=shift pieces, false=keep fixed positions
var log_label: RichTextLabel
var status_label: Label
var style_option: OptionButton
var player_design_option: OptionButton
var opponent_design_option: OptionButton
var checkerboard_check: CheckBox
var border_check: CheckBox
var board_size_spin: SpinBox
var max_pieces_spin: SpinBox
var ai_check: CheckBox
var cell_empty_picker: ColorPickerButton
var cell_alt_picker: ColorPickerButton
var line_color_picker: ColorPickerButton
var border_color_picker: ColorPickerButton
var board_bg_picker: ColorPickerButton
var cell_hover_picker: ColorPickerButton
var player_body_shape_option: OptionButton
var opponent_body_shape_option: OptionButton
var player_body_color_picker: ColorPickerButton
var opponent_body_color_picker: ColorPickerButton
var player_symbol_color_picker: ColorPickerButton
var opponent_symbol_color_picker: ColorPickerButton
var player_effect_option: OptionButton
var opponent_effect_option: OptionButton

var _all_designs: Array = []
var _all_effects: Array = []
var player_design: Resource = null
var opponent_design: Resource = null
var player_effect: Resource = null
var opponent_effect: Resource = null

const STYLES := ["gentle", "slam", "spinning", "dramatic", "nervous"]
const PLAYER_COLOR := Color(0.3, 0.6, 1.0)
const OPPONENT_COLOR := Color(1.0, 0.3, 0.3)


func _ready() -> void:
	_all_designs = PieceDesignScript.all_designs()
	_all_effects = PieceEffectScript.all_effects()
	player_design = _all_designs[0]  # X
	opponent_design = _all_designs[1]  # O
	player_effect = _all_effects[0]  # none
	opponent_effect = _all_effects[0]  # none
	board_audio = Node.new()
	board_audio.set_script(BoardAudioScript)
	add_child(board_audio)
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
	if _win_line_node and is_instance_valid(_win_line_node):
		_win_line_node.queue_free()
		_win_line_node = null
	for c in cells:
		if is_instance_valid(c):
			c.queue_free()
	cells.clear()
	# Clean effect players
	for p in player_pieces + opponent_pieces:
		if is_instance_valid(p) and p.effect_player and is_instance_valid(p.effect_player):
			p.effect_player.queue_free()
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
		cell.color_empty = cell_empty_picker.color if cell_empty_picker else Color(0.92, 0.88, 0.82)
		cell.color_alt = cell_alt_picker.color if cell_alt_picker else Color(0.25, 0.27, 0.32)
		cell.color_hover = cell_hover_picker.color if cell_hover_picker else Color(0.85, 0.80, 0.72)
		cell.color_line = line_color_picker.color if line_color_picker else Color(0.6, 0.5, 0.4)
		cell.line_width = 2.0
		cell.cell_clicked.connect(_on_cell_clicked)
		grid.add_child(cell)
		cells.append(cell)


func _create_pieces() -> void:
	var count: int = rules.get_pieces_for(1)
	for i in range(count):
		var p := Control.new()
		p.set_script(PieceScript)
		p.setup(player_design, "player", PLAYER_COLOR)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece_layer.add_child(p)
		_attach_effect(p, player_effect)
		player_pieces.append(p)

	count = rules.get_pieces_for(2)
	for i in range(count):
		var p := Control.new()
		p.set_script(PieceScript)
		p.setup(opponent_design, "opponent", OPPONENT_COLOR)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece_layer.add_child(p)
		_attach_effect(p, opponent_effect)
		opponent_pieces.append(p)

	await get_tree().process_frame
	_position_hand_pieces()


func _attach_effect(piece: Control, eff: Resource) -> void:
	var ep := Node2D.new()
	ep.set_script(PieceEffectPlayerScript)
	ep.setup(eff)
	piece_layer.add_child(ep)
	piece.effect_player = ep


func _position_hand_pieces() -> void:
	if cells.is_empty():
		return
	var cell_size = _get_cell_size()
	var piece_h: float = cell_size.y * 0.85  # Same scale as board pieces

	# Player hand (below board)
	_layout_hand(player_pieces, player_next, player_hand, piece_h)
	# Opponent hand (above board)
	_layout_hand(opponent_pieces, opponent_next, opponent_hand, piece_h)


func _layout_hand(pieces: Array[Control], next_idx: int, hand: Control, piece_sz: float) -> void:
	var hand_rect: Rect2 = hand.get_global_rect()
	var hand_local_x: float = hand_rect.position.x - piece_layer.global_position.x
	var hand_width: float = hand_rect.size.x
	var y: float = hand_rect.position.y - piece_layer.global_position.y + (hand_rect.size.y - piece_sz) / 2.0
	var spacing: float = piece_sz + 4.0
	var total_count: int = pieces.size()

	# Determine which slots to show and how many visible pieces
	var visible_count: int = 0
	if hand_compact:
		visible_count = total_count - next_idx
	else:
		visible_count = total_count

	# Calculate start X based on alignment
	var row_width: float = visible_count * spacing - 4.0 if visible_count > 0 else 0.0
	var start_x: float = hand_local_x
	match hand_align:
		0:  # Left
			start_x = hand_local_x + 8.0
		1:  # Center
			start_x = hand_local_x + (hand_width - row_width) / 2.0
		2:  # Right
			start_x = hand_local_x + hand_width - row_width - 8.0

	for i in range(total_count):
		var p: Control = pieces[i]
		if not is_instance_valid(p):
			continue
		if not hand.visible or i < next_idx:
			if i < next_idx and cell_to_piece.values().has(p):
				continue  # Already placed on board
			if not hand.visible:
				if not cell_to_piece.values().has(p):
					p.visible = false
			continue

		p.visible = true
		p.size = Vector2(piece_sz, piece_sz)
		var slot: int
		if hand_compact:
			slot = i - next_idx
		else:
			slot = i
		p.position = Vector2(start_x + slot * spacing, y)
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
	# Random visual offset (imprecision)
	if placement_offset_max > 0.0:
		var max_px: float = cell_size.x * placement_offset_max
		var rand_offset := Vector2(
			randf_range(-max_px, max_px),
			randf_range(-max_px, max_px)
		)
		final_pos += rand_offset

	# Animate with phase hooks for screen effects
	var style = current_style
	var all_nodes: Array = []
	for p in player_pieces + opponent_pieces:
		if is_instance_valid(p):
			all_nodes.append(p)

	var eff: Resource = null
	if piece_node.effect_player and piece_node.effect_player.effect:
		eff = piece_node.effect_player.effect
	var pn: Control = piece_node
	var cur_style_name: String = STYLES[style_option.selected]
	var _on_phase := func(phase_name: String) -> void:
		# Audio hooks
		if board_audio:
			match phase_name:
				"lift":
					board_audio.play_sfx("lift")
				"arc":
					board_audio.play_sfx("whoosh")
				"impact":
					if cur_style_name == "slam" or cur_style_name == "dramatic":
						board_audio.play_sfx("impact_heavy")
					else:
						board_audio.play_sfx("impact_light")
		# Visual effect hooks (impact only)
		if phase_name != "impact" or eff == null:
			return
		if eff.board_shake_intensity > 0.0:
			_shake_board(eff.board_shake_intensity, eff.board_shake_duration)
		if eff.screen_flash_enabled and screen_fx:
			screen_fx.flash(eff.screen_flash_color, eff.screen_flash_duration)
		if eff.propagation_enabled and screen_fx and is_instance_valid(pn):
			var impact_center: Vector2 = pn.global_position + pn.size / 2.0
			screen_fx.propagation_ring(impact_center, eff.propagation_color, 200.0, eff.propagation_duration)

	piece_node.phase_started.connect(_on_phase)
	await piece_node.play_move_to(final_pos, piece_size, style, all_nodes)
	piece_node.phase_started.disconnect(_on_phase)

	_animating = false
	_position_hand_pieces()
	_update_ghost_state()

	var label = "J1" if is_player else "J2 (IA)"
	_log("%s → celda %d" % [label, index])

	if result.is_win:
		# Win line
		var win_positions := PackedVector2Array()
		for idx in result.winning_pattern:
			win_positions.append(cells[idx].get_center_position())
		var win_color: Color
		if win_line_auto_color_check.button_pressed:
			win_color = PLAYER_COLOR if logic.winner == 1 else OPPONENT_COLOR
		else:
			win_color = win_line_color_picker.color
		var win_width: float = float(win_line_width_spin.value)
		_win_line_node = screen_fx.play_win_line(win_positions, win_color, win_width)
		# Audio
		if board_audio:
			board_audio.play_sfx("win")
			board_audio.duck_bgm(0.5)
		_log("[color=green]VICTORIA: %s[/color]" % ("J1" if logic.winner == 1 else "J2"))
	elif result.is_draw:
		if board_audio:
			board_audio.play_sfx("draw")
		# Visual: board cracks + gray wash
		if screen_fx and board_frame:
			var board_global_rect := Rect2(board_frame.global_position, board_frame.size)
			screen_fx.play_draw_effect(board_global_rect, 1.5)
		_log("[color=yellow]EMPATE[/color]")

	_update_status()


var _ghost_enabled: bool = true

func _update_ghost_state(enabled: bool = _ghost_enabled) -> void:
	_ghost_enabled = enabled
	var show: bool = _ghost_enabled and not _animating and not logic.game_over and logic.current_turn == 1
	var ratio: float = 0.85
	for cell in cells:
		cell.set_ghost(player_design, PLAYER_COLOR, show)
		cell.ghost_piece_ratio = ratio


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

	var scale_h := HBoxContainer.new()
	left.add_child(scale_h)
	var scale_lbl := Label.new()
	scale_lbl.text = "Escala"
	scale_lbl.custom_minimum_size = Vector2(80, 0)
	scale_lbl.add_theme_font_size_override("font_size", 11)
	scale_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	scale_h.add_child(scale_lbl)
	var scale_slider := HSlider.new()
	scale_slider.min_value = 150.0
	scale_slider.max_value = 600.0
	scale_slider.step = 10.0
	scale_slider.value = 300.0
	scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_slider.value_changed.connect(func(v: float): _on_board_scale_changed(v))
	scale_h.add_child(scale_slider)

	_lbl(left, "Fichas en espera", 11, Color(0.55, 0.55, 0.65))
	var hand_vis_option := OptionButton.new()
	hand_vis_option.add_item("Ambas (arriba/abajo)")
	hand_vis_option.add_item("Solo J1 (abajo)")
	hand_vis_option.add_item("Solo J2 (arriba)")
	hand_vis_option.add_item("Ninguna")
	hand_vis_option.select(0)
	hand_vis_option.item_selected.connect(func(idx: int): _on_hand_visibility_changed(idx))
	left.add_child(hand_vis_option)

	var hand_align_option := OptionButton.new()
	hand_align_option.add_item("Izquierda")
	hand_align_option.add_item("Centro")
	hand_align_option.add_item("Derecha")
	hand_align_option.select(1)
	hand_align_option.item_selected.connect(func(idx: int): hand_align = idx; _position_hand_pieces())
	left.add_child(hand_align_option)

	var compact_check := CheckBox.new()
	compact_check.text = "Compactar al usar"
	compact_check.button_pressed = true
	compact_check.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	compact_check.toggled.connect(func(on: bool): hand_compact = on; _position_hand_pieces())
	left.add_child(compact_check)

	ai_check = CheckBox.new()
	ai_check.text = "IA oponente"
	ai_check.button_pressed = true
	ai_check.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	left.add_child(ai_check)

	var ghost_check := CheckBox.new()
	ghost_check.text = "Ghost piece (hover)"
	ghost_check.button_pressed = true
	ghost_check.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	ghost_check.toggled.connect(func(on: bool): _update_ghost_state(on))
	left.add_child(ghost_check)
	# Enable ghost by default
	call_deferred("_update_ghost_state", true)

	left.add_child(HSeparator.new())
	_lbl(left, "Estilo de colocación", 13, Color(0.6, 0.6, 0.75))
	style_option = OptionButton.new()
	for s in STYLES:
		style_option.add_item(s)
	style_option.select(1)  # slam
	style_option.item_selected.connect(func(_i): current_style = _get_style())
	left.add_child(style_option)

	_lbl(left, "Diseño J1", 13, Color(0.6, 0.6, 0.75))
	player_design_option = OptionButton.new()
	for d in _all_designs:
		player_design_option.add_item(d.design_name)
	player_design_option.select(0)
	player_design_option.item_selected.connect(func(idx: int): _on_design_changed(true, idx))
	left.add_child(player_design_option)

	_lbl(left, "Diseño J2", 13, Color(0.6, 0.6, 0.75))
	opponent_design_option = OptionButton.new()
	for d in _all_designs:
		opponent_design_option.add_item(d.design_name)
	opponent_design_option.select(1)
	opponent_design_option.item_selected.connect(func(idx: int): _on_design_changed(false, idx))
	left.add_child(opponent_design_option)

	left.add_child(HSeparator.new())
	_lbl(left, "Cuerpo ficha", 13, Color(0.6, 0.6, 0.75))
	var body_labels: PackedStringArray = PieceDesignScript.body_shape_labels()

	_lbl(left, "Forma J1", 11, Color(0.55, 0.55, 0.65))
	player_body_shape_option = OptionButton.new()
	for bl in body_labels:
		player_body_shape_option.add_item(bl)
	player_body_shape_option.select(0)
	player_body_shape_option.item_selected.connect(func(idx: int): _on_body_shape_changed(true, idx))
	left.add_child(player_body_shape_option)
	player_body_color_picker = _piece_color_picker(left, "Cuerpo J1", PLAYER_COLOR.darkened(0.3), true, "body")
	player_symbol_color_picker = _piece_color_picker(left, "Símbolo J1", PLAYER_COLOR, true, "symbol")

	_lbl(left, "Forma J2", 11, Color(0.55, 0.55, 0.65))
	opponent_body_shape_option = OptionButton.new()
	for bl in body_labels:
		opponent_body_shape_option.add_item(bl)
	opponent_body_shape_option.select(0)
	opponent_body_shape_option.item_selected.connect(func(idx: int): _on_body_shape_changed(false, idx))
	left.add_child(opponent_body_shape_option)
	opponent_body_color_picker = _piece_color_picker(left, "Cuerpo J2", OPPONENT_COLOR.darkened(0.3), false, "body")
	opponent_symbol_color_picker = _piece_color_picker(left, "Símbolo J2", OPPONENT_COLOR, false, "symbol")

	left.add_child(HSeparator.new())
	_lbl(left, "Efectos J1", 13, Color(0.6, 0.6, 0.75))
	player_effect_option = OptionButton.new()
	var effect_names: PackedStringArray = PieceEffectScript.effect_names()
	for n in effect_names:
		player_effect_option.add_item(n)
	player_effect_option.select(0)
	player_effect_option.item_selected.connect(func(idx: int): _on_effect_changed(true, idx))
	left.add_child(player_effect_option)

	_lbl(left, "Efectos J2", 13, Color(0.6, 0.6, 0.75))
	opponent_effect_option = OptionButton.new()
	for n in effect_names:
		opponent_effect_option.add_item(n)
	opponent_effect_option.select(0)
	opponent_effect_option.item_selected.connect(func(idx: int): _on_effect_changed(false, idx))
	left.add_child(opponent_effect_option)

	left.add_child(HSeparator.new())
	_lbl(left, "Audio", 13, Color(0.6, 0.6, 0.75))

	var bgm_check := CheckBox.new()
	bgm_check.text = "Música de fondo"
	bgm_check.button_pressed = false
	bgm_check.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	bgm_check.toggled.connect(func(on: bool):
		if on: board_audio.play_bgm()
		else: board_audio.stop_bgm()
	)
	left.add_child(bgm_check)

	var sfx_h := HBoxContainer.new()
	left.add_child(sfx_h)
	var sfx_lbl := Label.new()
	sfx_lbl.text = "Vol. SFX"
	sfx_lbl.custom_minimum_size = Vector2(80, 0)
	sfx_lbl.add_theme_font_size_override("font_size", 11)
	sfx_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	sfx_h.add_child(sfx_lbl)
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = 0.7
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.value_changed.connect(func(v: float): board_audio.set_sfx_volume(v))
	sfx_h.add_child(sfx_slider)

	var sound_theme := OptionButton.new()
	sound_theme.add_item("Clásico")
	sound_theme.add_item("Retro")
	sound_theme.add_item("Suave")
	sound_theme.select(0)
	sound_theme.item_selected.connect(func(idx: int): board_audio.apply_theme(idx))
	left.add_child(sound_theme)

	left.add_child(HSeparator.new())
	_lbl(left, "Línea victoria", 13, Color(0.6, 0.6, 0.75))
	win_line_auto_color_check = CheckBox.new()
	win_line_auto_color_check.text = "Color automático"
	win_line_auto_color_check.button_pressed = true
	win_line_auto_color_check.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	left.add_child(win_line_auto_color_check)
	win_line_color_picker = _color_picker(left, "Color línea", Color(1.0, 0.9, 0.2))
	win_line_width_spin = _spin(left, "Grosor", 2, 16, 6)

	var offset_h := HBoxContainer.new()
	left.add_child(offset_h)
	var offset_lbl := Label.new()
	offset_lbl.text = "Imprecisión"
	offset_lbl.custom_minimum_size = Vector2(80, 0)
	offset_lbl.add_theme_font_size_override("font_size", 11)
	offset_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	offset_h.add_child(offset_lbl)
	var offset_slider := HSlider.new()
	offset_slider.min_value = 0.0
	offset_slider.max_value = 0.3
	offset_slider.step = 0.01
	offset_slider.value = 0.0
	offset_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offset_slider.value_changed.connect(func(v: float): placement_offset_max = v)
	offset_h.add_child(offset_slider)

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

	cell_empty_picker = _color_picker(left, "Casilla", Color(0.92, 0.88, 0.82))
	cell_alt_picker = _color_picker(left, "Casilla alt", Color(0.25, 0.27, 0.32))
	line_color_picker = _color_picker(left, "Líneas", Color(0.6, 0.5, 0.4))
	border_color_picker = _color_picker(left, "Borde", Color(0.45, 0.35, 0.25))
	board_bg_picker = _color_picker(left, "Fondo", Color(0.3, 0.28, 0.24))
	cell_hover_picker = _color_picker(left, "Hover", Color(0.85, 0.80, 0.72))

	left.add_child(HSeparator.new())
	_lbl(left, "Temas", 13, Color(0.6, 0.6, 0.75))
	var themes_flow := HFlowContainer.new()
	themes_flow.add_theme_constant_override("h_separation", 4)
	themes_flow.add_theme_constant_override("v_separation", 4)
	left.add_child(themes_flow)
	for theme_name in ["Clásico", "Oscuro", "Neón", "Pastel"]:
		var tb := Button.new()
		tb.text = theme_name
		tb.add_theme_font_size_override("font_size", 11)
		var tn: String = theme_name
		tb.pressed.connect(func(): _apply_theme(tn))
		themes_flow.add_child(tb)

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
	opponent_hand.custom_minimum_size = Vector2(0, 90)
	center.add_child(opponent_hand)

	var board_center := CenterContainer.new()
	board_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(board_center)

	board_aspect = AspectRatioContainer.new()
	board_aspect.custom_minimum_size = Vector2(300, 300)
	board_center.add_child(board_aspect)

	board_frame = PanelContainer.new()
	board_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_aspect.add_child(board_frame)
	_apply_border()

	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	board_frame.add_child(grid)

	player_hand = Control.new()
	player_hand.custom_minimum_size = Vector2(0, 90)
	center.add_child(player_hand)

	# Piece layer overlays the entire center area
	piece_layer = Control.new()
	piece_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	piece_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(piece_layer)

	screen_fx = Control.new()
	screen_fx.set_script(ScreenEffectsScript)
	center.add_child(screen_fx)

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


func _on_board_scale_changed(val: float) -> void:
	if board_aspect:
		board_aspect.custom_minimum_size = Vector2(val, val)
	await get_tree().process_frame
	_reflow_all_pieces()


func _reflow_all_pieces() -> void:
	var cell_size: Vector2 = _get_cell_size()
	var piece_size: Vector2 = cell_size * 0.85
	for cell_idx in cell_to_piece:
		var p: Control = cell_to_piece[cell_idx]
		if not is_instance_valid(p):
			continue
		var target_pos: Vector2 = _get_cell_pos_in_layer(cell_idx)
		var offset: Vector2 = (cell_size - piece_size) / 2.0
		p.size = piece_size
		p.position = target_pos + offset
		p.pivot_offset = piece_size / 2.0
		p.queue_redraw()
	_position_hand_pieces()


func _on_hand_visibility_changed(idx: int) -> void:
	match idx:
		0:  # Ambas
			player_hand.visible = true
			opponent_hand.visible = true
		1:  # Solo J1 abajo
			player_hand.visible = true
			opponent_hand.visible = false
		2:  # Solo J2 arriba
			player_hand.visible = false
			opponent_hand.visible = true
		3:  # Ninguna
			player_hand.visible = false
			opponent_hand.visible = false
	await get_tree().process_frame
	_position_hand_pieces()


func _on_body_shape_changed(is_player: bool, idx: int) -> void:
	var shape_names: PackedStringArray = PieceDesignScript.body_shape_names()
	var d: Resource = player_design if is_player else opponent_design
	d.body_shape = shape_names[idx]
	var pieces: Array[Control] = player_pieces if is_player else opponent_pieces
	for p in pieces:
		if is_instance_valid(p):
			p.queue_redraw()
	_log("Forma %s: %s" % ["J1" if is_player else "J2", PieceDesignScript.body_shape_labels()[idx]])


func _on_piece_color_changed(is_player: bool, which: String, color: Color) -> void:
	var d: Resource = player_design if is_player else opponent_design
	if which == "body":
		d.body_color = color
	else:
		d.symbol_color = color
	var pieces: Array[Control] = player_pieces if is_player else opponent_pieces
	for p in pieces:
		if is_instance_valid(p):
			p.queue_redraw()


func _on_effect_changed(is_player: bool, idx: int) -> void:
	var new_effect: Resource = _all_effects[idx]
	var pieces: Array[Control] = player_pieces if is_player else opponent_pieces
	if is_player:
		player_effect = new_effect
	else:
		opponent_effect = new_effect
	for p in pieces:
		if is_instance_valid(p) and p.effect_player and is_instance_valid(p.effect_player):
			p.effect_player.setup(new_effect)
	var label: String = "J1" if is_player else "J2"
	_log("Efecto %s: %s" % [label, PieceEffectScript.effect_names()[idx]])


func _on_design_changed(is_player: bool, idx: int) -> void:
	var new_design: Resource = _all_designs[idx]
	if is_player:
		player_design = new_design
		for p in player_pieces:
			if is_instance_valid(p):
				p.set_design(new_design)
		_log("Diseño J1: %s" % new_design.design_name)
	else:
		opponent_design = new_design
		for p in opponent_pieces:
			if is_instance_valid(p):
				p.set_design(new_design)
		_log("Diseño J2: %s" % new_design.design_name)


func _shake_board(intensity: float, duration: float) -> void:
	if not board_frame:
		return
	# Shake both board_frame and piece_layer together so pieces stay aligned
	var orig_board: Vector2 = board_frame.position
	var orig_pieces: Vector2 = piece_layer.position
	var steps: int = maxi(3, int(duration / 0.03))
	var step_dur: float = duration / float(steps)

	var tween := create_tween()
	for i in steps:
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_callback(func():
			board_frame.position = orig_board + offset
			piece_layer.position = orig_pieces + offset
		)
		tween.tween_interval(step_dur)
	tween.tween_callback(func():
		board_frame.position = orig_board
		piece_layer.position = orig_pieces
	)


func _apply_colors() -> void:
	for c in cells:
		if is_instance_valid(c):
			c.color_empty = cell_empty_picker.color
			c.color_alt = cell_alt_picker.color
			c.color_hover = cell_hover_picker.color
			c.color_line = line_color_picker.color
			c.queue_redraw()
	_apply_border()


func _apply_theme(theme_name: String) -> void:
	match theme_name:
		"Clásico":
			cell_empty_picker.color = Color(0.92, 0.88, 0.82)
			cell_alt_picker.color = Color(0.25, 0.27, 0.32)
			line_color_picker.color = Color(0.6, 0.5, 0.4)
			border_color_picker.color = Color(0.45, 0.35, 0.25)
			board_bg_picker.color = Color(0.3, 0.28, 0.24)
			cell_hover_picker.color = Color(0.85, 0.80, 0.72)
		"Oscuro":
			cell_empty_picker.color = Color(0.18, 0.18, 0.22)
			cell_alt_picker.color = Color(0.12, 0.12, 0.16)
			line_color_picker.color = Color(0.3, 0.3, 0.35)
			border_color_picker.color = Color(0.25, 0.25, 0.3)
			board_bg_picker.color = Color(0.08, 0.08, 0.12)
			cell_hover_picker.color = Color(0.22, 0.22, 0.28)
		"Neón":
			cell_empty_picker.color = Color(0.05, 0.05, 0.08)
			cell_alt_picker.color = Color(0.08, 0.08, 0.12)
			line_color_picker.color = Color(0.0, 0.9, 0.9)
			border_color_picker.color = Color(0.9, 0.0, 0.9)
			board_bg_picker.color = Color(0.02, 0.02, 0.05)
			cell_hover_picker.color = Color(0.08, 0.08, 0.14)
		"Pastel":
			cell_empty_picker.color = Color(0.95, 0.88, 0.9)
			cell_alt_picker.color = Color(0.85, 0.9, 0.88)
			line_color_picker.color = Color(0.75, 0.7, 0.8)
			border_color_picker.color = Color(0.8, 0.75, 0.85)
			board_bg_picker.color = Color(0.9, 0.85, 0.92)
			cell_hover_picker.color = Color(0.90, 0.82, 0.85)
	_apply_colors()
	_log("Tema: %s" % theme_name)


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
		style.bg_color = board_bg_picker.color if board_bg_picker else Color(0.3, 0.28, 0.24)
		style.border_color = border_color_picker.color if border_color_picker else Color(0.45, 0.35, 0.25)
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


func _piece_color_picker(parent: Control, text: String, default_color: Color, is_player: bool, which: String) -> ColorPickerButton:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(80, 0)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	h.add_child(l)
	var cp := ColorPickerButton.new()
	cp.color = default_color
	cp.custom_minimum_size = Vector2(40, 24)
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p: bool = is_player
	var w: String = which
	cp.color_changed.connect(func(c: Color): _on_piece_color_changed(p, w, c))
	h.add_child(cp)
	return cp


func _color_picker(parent: Control, text: String, default_color: Color) -> ColorPickerButton:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(80, 0)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	h.add_child(l)
	var cp := ColorPickerButton.new()
	cp.color = default_color
	cp.custom_minimum_size = Vector2(40, 24)
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cp.color_changed.connect(func(_c: Color): _apply_colors())
	h.add_child(cp)
	return cp


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
