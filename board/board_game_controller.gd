class_name BoardGameController
extends RefCounted

## Manages game flow: turns, move execution, AI turns, game-over handling.

var board: Control  # Reference to the Board node


func _init(board_ref: Control) -> void:
	board = board_ref


func start_game() -> void:
	board.logic.reset()
	board._skip_turn_switch = false
	board._next_move_style_override = null
	board.pieces.player_next = 0
	board.pieces.opponent_next = 0
	board.pieces.cell_to_piece.clear()

	board.pieces.clear_all_pieces()

	for c in board.cells:
		c.clear()

	for ab in board.abilities.player_abilities:
		ab.reset()
	for ab in board.abilities.opponent_abilities:
		ab.reset()

	board.pieces.create_all_pieces()

	board.input_enabled = true
	board._animating = false
	_update_input_state()
	board.abilities.update_ui_state()
	_update_status("Tu turno — X")
	EventBus.game_started.emit()


func handle_cell_click(index: int) -> void:
	if not board.input_enabled or board._animating or board.logic.game_over:
		return
	if board.logic.current_turn != board.player_piece:
		return

	await do_move(index, true)

	if board.auto_ai_enabled and not board.logic.game_over and board.logic.current_turn == board.ai_piece:
		await do_ai_turn()
	else:
		board.abilities.update_ui_state()


func do_move(index: int, is_player: bool) -> void:
	var piece_type = board.logic.current_turn
	var move_result = board.logic.make_move(index)
	if not move_result.success:
		return

	board._animating = true
	board.input_enabled = false
	_update_input_state()

	var pieces = board.pieces

	# Handle rotation: remove old piece visually
	if move_result.removed_cell >= 0:
		var removed_idx = move_result.removed_cell
		board.cells[removed_idx].set_occupied(false)
		if pieces.cell_to_piece.has(removed_idx):
			var old_piece = pieces.cell_to_piece[removed_idx]
			pieces.cell_to_piece.erase(removed_idx)
			var fade = old_piece.create_tween()
			fade.tween_property(old_piece, "modulate:a", 0.3, 0.2)
			await fade.finished
			old_piece.modulate.a = 1.0
			if is_player:
				pieces.player_next = max(0, pieces.player_next - 1)
			else:
				pieces.opponent_next = max(0, pieces.opponent_next - 1)

	board.cells[index].set_occupied(true)

	# Pick the next available piece from hand
	var piece_node: Control
	if is_player:
		if pieces.player_next >= pieces.player_pieces.size():
			push_error("Board: player_next (%d) out of bounds (size %d)" % [pieces.player_next, pieces.player_pieces.size()])
			board._animating = false
			return
		piece_node = pieces.player_pieces[pieces.player_next]
		pieces.player_next += 1
	else:
		if pieces.opponent_next >= pieces.opponent_pieces.size():
			push_error("Board: opponent_next (%d) out of bounds (size %d)" % [pieces.opponent_next, pieces.opponent_pieces.size()])
			board._animating = false
			return
		piece_node = pieces.opponent_pieces[pieces.opponent_next]
		pieces.opponent_next += 1

	pieces.cell_to_piece[index] = piece_node

	# Target position
	var target_pos = pieces.get_cell_pos_in_layer(index)
	var cell_size = pieces.get_cell_size()
	var piece_size = cell_size * board.pieces.get_piece_ratio()
	var offset = (cell_size - piece_size) / 2.0
	var final_pos = target_pos + offset

	# Style
	var style = board._next_move_style_override if board._next_move_style_override else (board.player_style if is_player else board.opponent_style)
	board._next_move_style_override = null

	# All pieces for effects
	var all_nodes: Array = []
	for p in pieces.player_pieces + pieces.opponent_pieces:
		if is_instance_valid(p):
			all_nodes.append(p)

	# Animate movement
	await piece_node.play_move_to(final_pos, piece_size, style, all_nodes)

	board._animating = false
	pieces.position_hand_pieces()

	# Signals
	var piece_str = board.logic.piece_to_string(piece_type)
	EventBus.move_made.emit(index, piece_str)
	EventBus.board_state_changed.emit(board.logic.cells.duplicate())

	var patterns = board.logic.detect_patterns(index, piece_type)
	for pattern in patterns:
		EventBus.specific_pattern.emit(pattern)

	if board.logic.game_over:
		await _handle_game_over()
	elif board._skip_turn_switch:
		board._skip_turn_switch = false
		board.input_enabled = true
		_update_input_state()
		_update_status("¡Turno extra!")
		board.abilities.update_ui_state()
	else:
		EventBus.turn_changed.emit(board.logic.piece_to_string(board.logic.current_turn))
		if not is_player and not board.external_input_control:
			board.input_enabled = true
			_update_input_state()
			_update_status("Tu turno — X")
		board.abilities.update_ui_state()


func do_ai_turn() -> void:
	_update_status("Oponente pensando...")
	board.abilities.update_ui_state()
	if board.pre_move_hook_enabled:
		EventBus.before_ai_move.emit()
		await EventBus.pre_move_complete
	await board.get_tree().create_timer(0.4).timeout
	var move = board.ai.choose_move(board.logic)
	if move >= 0:
		await do_move(move, false)
	else:
		board.abilities.update_ui_state()


func trigger_ai_turn() -> void:
	if board.logic.game_over or board.logic.current_turn != board.ai_piece:
		return
	await do_ai_turn()


func _handle_game_over() -> void:
	var result: String
	if board.logic.winner != 0:
		var winner_str = board.logic.piece_to_string(board.logic.winner)
		EventBus.game_won.emit(winner_str)
		if board.logic.winner == board.player_piece:
			_update_status("¡Ganaste!")
			result = "win"
		else:
			_update_status("Perdiste...")
			result = "lose"
	else:
		_update_status("¡Empate!")
		EventBus.game_draw.emit()
		result = "draw"

	await board.get_tree().create_timer(0.8).timeout
	EventBus.match_ended.emit(result)


func _update_input_state() -> void:
	for cell in board.cells:
		cell.set_input_enabled(board.input_enabled)


func _update_status(text: String) -> void:
	if board.status_label:
		board.status_label.text = text
