class_name BoardPieces
extends RefCounted

## Manages piece creation, hand layout, cell-piece mapping, and resize reflow.

const PieceScript = preload("res://systems/board_visuals/piece.gd")

var board: Control  # Reference to the Board node

# Piece state
var player_pieces: Array[Control] = []
var opponent_pieces: Array[Control] = []
var cell_to_piece: Dictionary = {}  # cell_index -> piece node
var player_next: int = 0
var opponent_next: int = 0
var _reflow_request_id: int = 0


func _init(board_ref: Control) -> void:
	board = board_ref


func get_piece_ratio() -> float:
	if board._board_config:
		return board._board_config.piece_cell_ratio
	return 0.85


func create_all_pieces() -> void:
	var cell_size = get_cell_size()
	var piece_size = cell_size * get_piece_ratio()
	var player_piece = board.player_piece
	var ai_piece = board.ai_piece

	var player_count = board.game_rules.get_pieces_for(player_piece)
	for i in range(player_count):
		var p = make_piece_node(player_piece, true, piece_size)
		board.piece_layer.add_child(p)
		player_pieces.append(p)

	var opponent_count = board.game_rules.get_pieces_for(ai_piece)
	for i in range(opponent_count):
		var p = make_piece_node(ai_piece, false, piece_size)
		board.piece_layer.add_child(p)
		opponent_pieces.append(p)

	position_hand_pieces(false)


func make_piece_node(piece_type: int, is_player: bool, sz: Vector2) -> Control:
	var p = Control.new()
	p.set_script(PieceScript)
	p.size = sz
	p.pivot_offset = sz / 2.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color = board.player_color if is_player else board.opponent_color
	var design = board.player_design if is_player else board.opponent_design
	p.setup(design, "player" if is_player else "opponent", color)
	return p


func clear_all_pieces() -> void:
	for p in player_pieces:
		if is_instance_valid(p):
			if p.get("effect_player") and is_instance_valid(p.effect_player):
				p.effect_player.get_parent().remove_child(p.effect_player)
				p.effect_player.free()
			p.get_parent().remove_child(p)
			p.free()
	for p in opponent_pieces:
		if is_instance_valid(p):
			if p.get("effect_player") and is_instance_valid(p.effect_player):
				p.effect_player.get_parent().remove_child(p.effect_player)
				p.effect_player.free()
			p.get_parent().remove_child(p)
			p.free()
	player_pieces.clear()
	opponent_pieces.clear()
	cell_to_piece.clear()
	player_next = 0
	opponent_next = 0


func position_hand_pieces(animate: bool = true) -> void:
	var grid_rect = _get_grid_rect_in_layer()
	var player_hand_rect = _get_control_rect_in_layer(board.player_hand_area)
	var opponent_hand_rect = _get_control_rect_in_layer(board.opponent_hand_area)
	var hand_band_h: float = max(24.0, min(player_hand_rect.size.y, opponent_hand_rect.size.y) - 4.0)
	if hand_band_h <= 24.0:
		hand_band_h = 50.0
	var cell_size = get_cell_size()
	var hand_h: float = clamp(cell_size.y * get_piece_ratio(), 24.0, hand_band_h)
	var piece_size = Vector2(hand_h, hand_h)
	var gap = 4.0

	# Pre-compute occupied pieces to avoid O(n²) lookup
	var occupied := {}
	for piece in cell_to_piece.values():
		occupied[piece] = true

	# Player hand: centered in PlayerHandArea below the grid
	var player_y = player_hand_rect.position.y + (player_hand_rect.size.y - hand_h) / 2.0
	var max_y = board.size.y - piece_size.y - 2.0
	player_y = min(player_y, max_y)
	var player_available: Array[Control] = []
	for p in player_pieces:
		if is_instance_valid(p) and not occupied.has(p):
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
		if is_instance_valid(p) and not occupied.has(p):
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


func snap_layout() -> void:
	## Snap all pieces to their correct positions without animation.
	position_hand_pieces(false)
	for cell_idx in cell_to_piece:
		var p = cell_to_piece[cell_idx]
		if is_instance_valid(p):
			var target = get_cell_pos_in_layer(cell_idx)
			var cell_size = get_cell_size()
			var ps = cell_size * get_piece_ratio()
			var base_pos = target + (cell_size - ps) / 2.0
			var offset = p.placement_offset if p.get("placement_offset") else Vector2.ZERO
			p.position = base_pos + offset
			p.size = ps
			p.pivot_offset = ps / 2.0
			p.queue_redraw()


func schedule_reflow() -> void:
	if not board.is_inside_tree():
		return
	if board.size.x < 50 or board.size.y < 50:
		return  # Board collapsed during layout transition
	if board.logic.game_over or board._animating:
		return
	_reflow_request_id += 1
	var request_id := _reflow_request_id
	_run_piece_reflow(request_id)


func _run_piece_reflow(request_id: int) -> void:
	if board.size.x < 50 or board.size.y < 50:
		return
	await board.get_tree().process_frame
	if request_id != _reflow_request_id:
		return
	snap_layout()
	await board.get_tree().process_frame
	if request_id != _reflow_request_id:
		return
	snap_layout()


# --- Coordinate helpers ---

func get_cell_size() -> Vector2:
	if board.cells.is_empty() or board.cells[0].size == Vector2.ZERO:
		return Vector2(80, 80)
	return board.cells[0].size


func get_cell_pos_in_layer(index: int) -> Vector2:
	return board.cells[index].global_position - board.piece_layer.global_position


func _get_grid_rect_in_layer() -> Rect2:
	var gp = board.grid.global_position - board.piece_layer.global_position
	return Rect2(gp, board.grid.size)


func _get_control_rect_in_layer(control: Control) -> Rect2:
	var gp = control.global_position - board.piece_layer.global_position
	return Rect2(gp, control.size)
