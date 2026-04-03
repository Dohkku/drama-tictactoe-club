extends Control

const BoardLogicScript = preload("res://board/board_logic.gd")
const GameRulesScript = preload("res://board/game_rules.gd")
const AIPlayerScript = preload("res://board/ai_player.gd")
const CellScript = preload("res://board/cell.gd")
const PieceScript = preload("res://board/piece.gd")
const PlacementStyleScript = preload("res://board/placement_style.gd")

var logic: RefCounted
var ai: RefCounted
var cells: Array[Control] = []
var player_piece: int = 1
var ai_piece: int = 2
var input_enabled: bool = true
var _animating: bool = false

var player_pieces: Array[Control] = []
var opponent_pieces: Array[Control] = []
var cell_to_piece: Dictionary = {}  # cell_index -> piece node
var _player_next: int = 0
var _opponent_next: int = 0
var _reflow_request_id: int = 0

var player_style: Resource = null
var opponent_style: Resource = null
var _next_move_style_override: Resource = null

var player_abilities: Array = []
var opponent_abilities: Array = []
var _skip_turn_switch: bool = false
var pre_move_hook_enabled: bool = false
var external_input_control: bool = false
var auto_ai_enabled: bool = true

var player_color: Color = Color(0.2, 0.6, 1.0)
var opponent_color: Color = Color(1.0, 0.3, 0.3)
var player_expressions: Dictionary = {}
var opponent_expressions: Dictionary = {}
var current_player_emotion: String = "neutral"
var current_opponent_emotion: String = "neutral"

var game_rules: Resource = null  # GameRules — set before _ready or call setup_rules()

@onready var grid: GridContainer = %GridContainer
@onready var status_label: Label = %StatusLabel
@onready var piece_layer: Control = %PieceLayer
@onready var opponent_hand_area: Control = $"VBoxContainer/OpponentHandArea"
@onready var player_hand_area: Control = $"VBoxContainer/PlayerHandArea"


func _ready() -> void:
	if game_rules == null:
		game_rules = GameRulesScript.new()
	logic = BoardLogicScript.new(game_rules)
	ai = AIPlayerScript.new()
	ai.difficulty = 0.3

	player_style = PlacementStyleScript.slam()
	opponent_style = PlacementStyleScript.gentle()

	_create_cells()
	_connect_signals()

	await get_tree().process_frame
	await get_tree().process_frame
	_start_game()

	get_tree().get_root().size_changed.connect(_on_resized)
	resized.connect(_on_resized)


func setup_rules(rules: Resource) -> void:
	game_rules = rules


func _create_cells() -> void:
	var total = game_rules.get_total_cells()
	grid.columns = game_rules.board_size
	for i in range(total):
		var cell = Control.new()
		cell.set_script(CellScript)
		cell.cell_index = i
		cell.custom_minimum_size = Vector2(10, 10)  # Tiny minimum; actual size from container
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.cell_clicked.connect(_on_cell_clicked)
		grid.add_child(cell)
		cells.append(cell)


func _connect_signals() -> void:
	EventBus.board_input_enabled.connect(_on_input_toggle)
	EventBus.layout_transition_finished.connect(_on_layout_transition_finished)


func _start_game() -> void:
	logic.reset()
	_skip_turn_switch = false
	_next_move_style_override = null
	_player_next = 0
	_opponent_next = 0
	cell_to_piece.clear()

	for p in player_pieces:
		if is_instance_valid(p):
			p.queue_free()
	for p in opponent_pieces:
		if is_instance_valid(p):
			p.queue_free()
	player_pieces.clear()
	opponent_pieces.clear()

	for c in cells:
		c.clear()

	for ab in player_abilities:
		ab.reset()
	for ab in opponent_abilities:
		ab.reset()

	_create_all_pieces()

	input_enabled = true
	_animating = false
	_update_input_state()
	_update_status("Tu turno — X")
	EventBus.game_started.emit()


func _create_all_pieces() -> void:
	var cell_size = _get_cell_size()
	var piece_size = cell_size * 0.85

	var player_count = game_rules.get_pieces_for(player_piece)
	for i in range(player_count):
		var p = _make_piece_node(player_piece, true, piece_size)
		piece_layer.add_child(p)
		player_pieces.append(p)

	var opponent_count = game_rules.get_pieces_for(ai_piece)
	for i in range(opponent_count):
		var p = _make_piece_node(ai_piece, false, piece_size)
		piece_layer.add_child(p)
		opponent_pieces.append(p)

	_position_hand_pieces(false)  # No animation on initial layout


func _make_piece_node(piece_type: int, is_player: bool, sz: Vector2) -> Control:
	var p = Control.new()
	p.set_script(PieceScript)
	p.size = sz
	p.pivot_offset = sz / 2.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color = player_color if is_player else opponent_color
	var expressions = player_expressions if is_player else opponent_expressions
	p.setup(piece_type, "player" if is_player else "opponent", color, expressions)
	p.set_emotion(current_player_emotion if is_player else current_opponent_emotion)
	return p


func _position_hand_pieces(animate: bool = true) -> void:
	var grid_rect = _get_grid_rect_in_layer()
	var player_hand_rect = _get_control_rect_in_layer(player_hand_area)
	var opponent_hand_rect = _get_control_rect_in_layer(opponent_hand_area)
	var hand_band_h: float = max(24.0, min(player_hand_rect.size.y, opponent_hand_rect.size.y) - 4.0)
	if hand_band_h <= 24.0:
		hand_band_h = 50.0
	var cell_size = _get_cell_size()
	var hand_h: float = clamp(min(cell_size.y * 0.42, hand_band_h), 24.0, 96.0)
	var piece_size = Vector2(hand_h, hand_h)
	var gap = 4.0

	# Player hand: centered in PlayerHandArea below the grid
	var player_y = player_hand_rect.position.y + (player_hand_rect.size.y - hand_h) / 2.0
	var max_y = size.y - piece_size.y - 2.0
	player_y = min(player_y, max_y)
	var player_available: Array[Control] = []
	for p in player_pieces:
		if is_instance_valid(p) and p not in cell_to_piece.values():
			player_available.append(p)
	var player_start_x = grid_rect.position.x + (grid_rect.size.x - player_available.size() * (piece_size.x + gap)) / 2.0
	for i in range(player_available.size()):
		var p = player_available[i]
		var target_pos = Vector2(player_start_x + i * (piece_size.x + gap), player_y)
		_move_piece_to_hand(p, target_pos, piece_size, animate)

	# Opponent hand: centered in OpponentHandArea above the grid
	var opponent_y = opponent_hand_rect.position.y + (opponent_hand_rect.size.y - hand_h) / 2.0
	opponent_y = max(opponent_y, 2.0)
	var opponent_available: Array[Control] = []
	for p in opponent_pieces:
		if is_instance_valid(p) and p not in cell_to_piece.values():
			opponent_available.append(p)
	var opponent_start_x = grid_rect.position.x + (grid_rect.size.x - opponent_available.size() * (piece_size.x + gap)) / 2.0
	for i in range(opponent_available.size()):
		var p = opponent_available[i]
		var target_pos = Vector2(opponent_start_x + i * (piece_size.x + gap), opponent_y)
		_move_piece_to_hand(p, target_pos, piece_size, animate)


func _move_piece_to_hand(p: Control, target_pos: Vector2, piece_size: Vector2, animate: bool) -> void:
	p.size = piece_size
	p.pivot_offset = piece_size / 2.0
	if not animate or p.position.is_zero_approx():
		p.position = target_pos
		return
	var tw = p.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(p, "position", target_pos, 0.35)


func _on_cell_clicked(index: int) -> void:
	if not input_enabled or _animating or logic.game_over:
		return
	if logic.current_turn != player_piece:
		return

	await _do_move(index, true)

	if auto_ai_enabled and not logic.game_over and logic.current_turn == ai_piece:
		await _do_ai_turn()


func _do_move(index: int, is_player: bool) -> void:
	var piece_type = logic.current_turn
	var move_result = logic.make_move(index)
	if not move_result.success:
		return

	_animating = true
	input_enabled = false
	_update_input_state()

	# Handle rotation: remove old piece visually
	if move_result.removed_cell >= 0:
		var removed_idx = move_result.removed_cell
		cells[removed_idx].set_occupied(false)
		if cell_to_piece.has(removed_idx):
			var old_piece = cell_to_piece[removed_idx]
			cell_to_piece.erase(removed_idx)
			# Fade out and return to hand
			var fade = old_piece.create_tween()
			fade.tween_property(old_piece, "modulate:a", 0.3, 0.2)
			await fade.finished
			# Move back to hand area (will be repositioned by _position_hand_pieces)
			old_piece.modulate.a = 1.0
			# Decrement the "next" counter so this piece can be reused
			if is_player:
				_player_next = max(0, _player_next - 1)
			else:
				_opponent_next = max(0, _opponent_next - 1)

	cells[index].set_occupied(true)

	# Pick the next available piece from hand
	var piece_node: Control
	if is_player:
		piece_node = player_pieces[_player_next]
		_player_next += 1
	else:
		piece_node = opponent_pieces[_opponent_next]
		_opponent_next += 1

	cell_to_piece[index] = piece_node

	# Target position
	var target_pos = _get_cell_pos_in_layer(index)
	var cell_size = _get_cell_size()
	var piece_size = cell_size * 0.85
	var offset = (cell_size - piece_size) / 2.0
	var final_pos = target_pos + offset

	# Style
	var style = _next_move_style_override if _next_move_style_override else (player_style if is_player else opponent_style)
	_next_move_style_override = null

	# All pieces for effects
	var all_nodes: Array = []
	for p in player_pieces + opponent_pieces:
		if is_instance_valid(p):
			all_nodes.append(p)

	# Animate movement
	await piece_node.play_move_to(final_pos, piece_size, style, all_nodes)

	_animating = false
	_position_hand_pieces()

	# Signals
	var piece_str = logic.piece_to_string(piece_type)
	EventBus.move_made.emit(index, piece_str)
	EventBus.board_state_changed.emit(logic.cells.duplicate())

	var patterns = logic.detect_patterns(index, piece_type)
	for pattern in patterns:
		EventBus.specific_pattern.emit(pattern)

	if logic.game_over:
		await _handle_game_over()
	elif _skip_turn_switch:
		_skip_turn_switch = false
		input_enabled = true
		_update_input_state()
		_update_status("¡Turno extra!")
	else:
		EventBus.turn_changed.emit(logic.piece_to_string(logic.current_turn))
		if not is_player and not external_input_control:
			input_enabled = true
			_update_input_state()
			_update_status("Tu turno — X")


func _handle_game_over() -> void:
	var result: String
	if logic.winner != 0:
		var winner_str = logic.piece_to_string(logic.winner)
		EventBus.game_won.emit(winner_str)
		if logic.winner == player_piece:
			_update_status("¡Ganaste!")
			result = "win"
		else:
			_update_status("Perdiste...")
			result = "lose"
	else:
		_update_status("¡Empate!")
		EventBus.game_draw.emit()
		result = "draw"

	# Wait for last piece animation to fully settle before signaling match end
	await get_tree().create_timer(0.8).timeout
	EventBus.match_ended.emit(result)


func trigger_ai_turn() -> void:
	## Public method for external controllers (e.g., simultaneous match manager)
	if logic.game_over or logic.current_turn != ai_piece:
		return
	await _do_ai_turn()


func _do_ai_turn() -> void:
	_update_status("Oponente pensando...")
	if pre_move_hook_enabled:
		EventBus.before_ai_move.emit()
		await EventBus.pre_move_complete
	await get_tree().create_timer(0.4).timeout
	var move = ai.choose_move(logic)
	if move >= 0:
		await _do_move(move, false)


# --- Coordinates ---

func _get_grid_rect_in_layer() -> Rect2:
	var gp = grid.global_position - piece_layer.global_position
	return Rect2(gp, grid.size)

func _get_control_rect_in_layer(control: Control) -> Rect2:
	var gp = control.global_position - piece_layer.global_position
	return Rect2(gp, control.size)

func _get_cell_pos_in_layer(index: int) -> Vector2:
	return cells[index].global_position - piece_layer.global_position

func _get_cell_size() -> Vector2:
	if cells.is_empty() or cells[0].size == Vector2.ZERO:
		return Vector2(80, 80)
	return cells[0].size

func _on_resized() -> void:
	_schedule_piece_reflow()

func _on_layout_transition_finished() -> void:
	_schedule_piece_reflow()

func _schedule_piece_reflow() -> void:
	if not is_inside_tree():
		return
	if size.x < 10 or size.y < 10:
		return  # Board collapsed (fullscreen cinematic)
	_reflow_request_id += 1
	var request_id := _reflow_request_id
	_run_piece_reflow(request_id)

func _run_piece_reflow(request_id: int) -> void:
	if size.x < 10 or size.y < 10:
		return  # Board collapsed (fullscreen cinematic)
	await get_tree().process_frame
	if request_id != _reflow_request_id:
		return
	_apply_piece_layout_snap()
	await get_tree().process_frame
	if request_id != _reflow_request_id:
		return
	_apply_piece_layout_snap()

func _apply_piece_layout_snap() -> void:
	_position_hand_pieces(false)  # Snap on resize/layout changes, don't animate
	for cell_idx in cell_to_piece:
		var p = cell_to_piece[cell_idx]
		if is_instance_valid(p):
			var target = _get_cell_pos_in_layer(cell_idx)
			var cell_size = _get_cell_size()
			var ps = cell_size * 0.85
			p.position = target + (cell_size - ps) / 2.0
			p.size = ps
			p.pivot_offset = ps / 2.0
			p.queue_redraw()


# --- Public API ---

func full_reset(new_rules: Resource = null) -> void:
	## Tear down and rebuild the board with (optionally) new rules.
	## Used by MatchManager when switching between matches.
	if new_rules:
		game_rules = new_rules

	# Clear existing cells
	for c in cells:
		if is_instance_valid(c):
			c.queue_free()
	cells.clear()

	# Clear existing pieces
	for p in player_pieces:
		if is_instance_valid(p):
			p.queue_free()
	for p in opponent_pieces:
		if is_instance_valid(p):
			p.queue_free()
	player_pieces.clear()
	opponent_pieces.clear()
	cell_to_piece.clear()
	_player_next = 0
	_opponent_next = 0

	# Rebuild
	logic = BoardLogicScript.new(game_rules)
	_create_cells()

	await get_tree().process_frame
	await get_tree().process_frame

	_start_game()


func set_player_style(s: Resource) -> void:
	player_style = s

func set_opponent_style(s: Resource) -> void:
	opponent_style = s

func override_next_style(s: Resource) -> void:
	_next_move_style_override = s

func set_piece_emotion(is_player: bool, emotion: String) -> void:
	if is_player:
		current_player_emotion = emotion
	else:
		current_opponent_emotion = emotion
	var arr = player_pieces if is_player else opponent_pieces
	for p in arr:
		if is_instance_valid(p):
			p.set_emotion(emotion)

func apply_ability(ability: Resource, is_player: bool) -> Dictionary:
	var board_state = {
		"move_count": logic.move_count,
		"current_turn": logic.current_turn,
		"cells": logic.cells.duplicate(),
	}
	if not ability.can_use(logic, board_state):
		return {}
	var result = ability.apply(logic, board_state)
	if result.get("skip_turn_switch", false):
		_skip_turn_switch = true
	return result

func _update_input_state() -> void:
	for cell in cells:
		cell.set_input_enabled(input_enabled)

func _update_status(text: String) -> void:
	if status_label:
		status_label.text = text

func save_board_state() -> Dictionary:
	var placed = {}
	for cell_idx in cell_to_piece:
		var p = cell_to_piece[cell_idx]
		placed[cell_idx] = {"type": p.piece_type, "is_player": p.character_id == "player"}
	return {
		"logic": logic.get_state(),
		"placed_pieces": placed,
		"player_next": _player_next,
		"opponent_next": _opponent_next,
	}


func load_board_state(state: Dictionary) -> void:
	# Clear visual pieces
	for p in player_pieces:
		if is_instance_valid(p): p.queue_free()
	for p in opponent_pieces:
		if is_instance_valid(p): p.queue_free()
	player_pieces.clear()
	opponent_pieces.clear()
	cell_to_piece.clear()

	# Clear all cell visual states
	for c in cells:
		c.clear()

	# Restore logic state
	logic.load_state(state.logic)
	_player_next = state.player_next
	_opponent_next = state.opponent_next

	# Recreate piece nodes
	_create_all_pieces()
	await get_tree().process_frame

	# Place pieces on cells without animation
	for cell_idx in state.placed_pieces:
		var info = state.placed_pieces[cell_idx]
		var piece_node: Control = null
		var arr = player_pieces if info.is_player else opponent_pieces
		for p in arr:
			if p not in cell_to_piece.values():
				piece_node = p
				break
		if piece_node:
			cell_to_piece[cell_idx] = piece_node
			cells[cell_idx].set_occupied(true)
			var target = _get_cell_pos_in_layer(cell_idx)
			var cs = _get_cell_size()
			var ps = cs * 0.85
			piece_node.position = target + (cs - ps) / 2.0
			piece_node.size = ps
			piece_node.pivot_offset = ps / 2.0

	_position_hand_pieces(false)
	_animating = false
	input_enabled = false
	_update_input_state()
	_update_status("Tu turno — X" if logic.current_turn == player_piece else "Oponente pensando...")


func _on_input_toggle(enabled: bool) -> void:
	input_enabled = enabled
	_update_input_state()
