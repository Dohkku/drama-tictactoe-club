class_name BoardGameController
extends RefCounted

## Manages game flow: turns, move execution, AI turns, game-over handling.

const AI_THINK_DELAY := 0.4
const GAME_OVER_DELAY := 0.8

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

	# Input starts DISABLED — MatchManager/SceneRunner enables it
	# via EventBus.board_input_enabled when ready
	board.input_enabled = false
	board._animating = false
	update_input_state()
	board.abilities.update_ui_state()
	update_status("")
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
	update_input_state()

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

	# All pieces for effects (avoid array concat)
	var all_nodes: Array = []
	for p in pieces.player_pieces:
		if is_instance_valid(p):
			all_nodes.append(p)
	for p in pieces.opponent_pieces:
		if is_instance_valid(p):
			all_nodes.append(p)

	# Audio and effect hooks during animation
	var audio: Node = board.board_audio
	var sfx: Control = board.screen_effects
	var is_heavy: bool = style.impact_squash >= 0.3 if style.get("impact_squash") != null else false
	var eff: Resource = null
	if piece_node.get("effect_player") and piece_node.effect_player and piece_node.effect_player.get("effect"):
		eff = piece_node.effect_player.effect
	var pn: Control = piece_node
	var _on_phase := func(phase_name: String) -> void:
		if audio:
			match phase_name:
				"lift":
					audio.play_sfx("lift")
				"arc":
					audio.play_sfx("whoosh")
				"impact":
					if is_heavy:
						audio.play_sfx("impact_heavy")
					else:
						audio.play_sfx("impact_light")
		if phase_name == "impact" and eff and sfx:
			if eff.get("screen_flash_enabled") and eff.screen_flash_enabled:
				sfx.flash(eff.screen_flash_color, eff.screen_flash_duration)
			if eff.get("propagation_enabled") and eff.propagation_enabled and is_instance_valid(pn):
				var center: Vector2 = pn.global_position + pn.size / 2.0
				sfx.propagation_ring(center, eff.propagation_color, 200.0, eff.propagation_duration)

	piece_node.phase_started.connect(_on_phase)
	await piece_node.play_move_to(final_pos, piece_size, style, all_nodes)
	piece_node.phase_started.disconnect(_on_phase)

	board._animating = false
	pieces.position_hand_pieces()

	# Signals
	var piece_str = board.logic.piece_to_string(piece_type)
	EventBus.move_made.emit(index, piece_str)
	EventBus.board_state_changed.emit(board.logic.cells.duplicate())

	var patterns = board.logic.get_patterns_from_result(move_result)
	for pattern in patterns:
		EventBus.specific_pattern.emit(pattern)

	if board.logic.game_over:
		await handle_game_over()
	elif board._skip_turn_switch:
		board._skip_turn_switch = false
		board.input_enabled = true
		update_input_state()
		update_status("¡Turno extra!")
		board.abilities.update_ui_state()
	else:
		EventBus.turn_changed.emit(board.logic.piece_to_string(board.logic.current_turn))
		if not is_player and not board.external_input_control:
			board.input_enabled = true
			update_input_state()
			update_status("Tu turno — X")
		board.abilities.update_ui_state()


func do_ai_turn() -> void:
	update_status("Oponente pensando...")
	board.abilities.update_ui_state()
	if board.pre_move_hook_enabled:
		EventBus.before_ai_move.emit()
		await EventBus.pre_move_complete
	await board.get_tree().create_timer(AI_THINK_DELAY).timeout
	var move = board.ai.choose_move(board.logic)
	if move >= 0:
		await do_move(move, false)
	else:
		board.abilities.update_ui_state()


func trigger_ai_turn() -> void:
	if board.logic.game_over or board.logic.current_turn != board.ai_piece:
		return
	await do_ai_turn()


func handle_game_over() -> void:
	var result: String
	var audio: Node = board.board_audio
	var sfx: Control = board.screen_effects

	if board.logic.winner != 0:
		var winner_str: String = board.logic.piece_to_string(board.logic.winner)
		EventBus.game_won.emit(winner_str)
		if board.logic.winner == board.player_piece:
			update_status("¡Ganaste!")
			result = "win"
		else:
			update_status("Perdiste...")
			result = "lose"

		# Win line
		if sfx and not board.logic.winning_pattern.is_empty():
			var positions := PackedVector2Array()
			for idx in board.logic.winning_pattern:
				if idx >= 0 and idx < board.cells.size():
					positions.append(board.cells[idx].get_center_position())
			if positions.size() >= 2:
				var color: Color = board.player_color if board.logic.winner == board.player_piece else board.opponent_color
				board._win_line_node = sfx.play_win_line(positions, color)

		if audio:
			audio.play_sfx("win")
			audio.duck_bgm(0.5)
	else:
		update_status("¡Empate!")
		EventBus.game_draw.emit()
		result = "draw"

		# Draw effect
		if sfx and board.board_frame:
			var board_rect := Rect2(board.board_frame.global_position, board.board_frame.size)
			sfx.play_draw_effect(board_rect, 1.5)

		if audio:
			audio.play_sfx("draw")

	await board.get_tree().create_timer(GAME_OVER_DELAY).timeout

	# Clean up win line before layout transition
	if board._win_line_node and is_instance_valid(board._win_line_node):
		board._win_line_node.get_parent().remove_child(board._win_line_node)
		board._win_line_node.free()
		board._win_line_node = null

	EventBus.match_ended.emit(result)


func update_input_state() -> void:
	for cell in board.cells:
		cell.set_input_enabled(board.input_enabled)


func update_status(text: String) -> void:
	if board.status_label:
		board.status_label.text = text
