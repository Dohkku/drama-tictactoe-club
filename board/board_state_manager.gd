class_name BoardStateManager
extends RefCounted

## Handles saving and loading board state for simultaneous matches.

var board: Control  # Reference to the Board node


func _init(board_ref: Control) -> void:
	board = board_ref


func save() -> Dictionary:
	var pieces = board.pieces
	var placed = {}
	for cell_idx in pieces.cell_to_piece:
		var p = pieces.cell_to_piece[cell_idx]
		placed[cell_idx] = {"is_player": p.character_id == "player"}
	return {
		"logic": board.logic.get_state(),
		"placed_pieces": placed,
		"player_next": pieces.player_next,
		"opponent_next": pieces.opponent_next,
	}


func load_state(state: Dictionary) -> void:
	var pieces = board.pieces

	# Clear visual pieces
	pieces.clear_all_pieces()

	# Clear all cell visual states
	for c in board.cells:
		c.clear()

	# Restore logic state
	board.logic.load_state(state.logic)

	# Recreate piece nodes
	pieces.create_all_pieces()
	await board.get_tree().process_frame

	# Place pieces on cells without animation
	for cell_idx in state.placed_pieces:
		var info = state.placed_pieces[cell_idx]
		var piece_node: Control = null
		var arr = pieces.player_pieces if info.is_player else pieces.opponent_pieces
		for p in arr:
			if p not in pieces.cell_to_piece.values():
				piece_node = p
				break
		if piece_node:
			pieces.cell_to_piece[cell_idx] = piece_node
			board.cells[cell_idx].set_occupied(true)
			var target = pieces.get_cell_pos_in_layer(cell_idx)
			var cs = pieces.get_cell_size()
			var ps = cs * board.pieces.get_piece_ratio()
			piece_node.position = target + (cs - ps) / 2.0
			piece_node.size = ps
			piece_node.pivot_offset = ps / 2.0

	# Compute indices from actual placed pieces
	var placed_player := 0
	var placed_opponent := 0
	for info in state.placed_pieces.values():
		if info.is_player:
			placed_player += 1
		else:
			placed_opponent += 1
	pieces.player_next = mini(placed_player, pieces.player_pieces.size())
	pieces.opponent_next = mini(placed_opponent, pieces.opponent_pieces.size())

	pieces.position_hand_pieces(false)
	board._animating = false
	board.input_enabled = false
	board.game_controller.update_input_state()
	board.abilities.update_ui_state()
	board.game_controller.update_status(
		"Tu turno — X" if board.logic.current_turn == board.player_piece else "Oponente pensando..."
	)
