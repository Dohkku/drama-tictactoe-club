class_name BoardAbilityController
extends RefCounted

## Manages special abilities: setup, UI, execution, and visual effects.

const StealAbilityScript = preload("res://systems/board_logic/abilities/steal_ability.gd")
const DoublePlayAbilityScript = preload("res://systems/board_logic/abilities/double_play_ability.gd")

var board: Control  # Reference to the Board node
var player_abilities: Array = []
var opponent_abilities: Array = []


func _init(board_ref: Control) -> void:
	board = board_ref


func setup_defaults() -> void:
	if player_abilities.is_empty():
		player_abilities = [
			DoublePlayAbilityScript.new(),
			StealAbilityScript.new(),
		]


func connect_ui() -> void:
	pass


func reset_all() -> void:
	for ab in player_abilities:
		ab.reset()
	for ab in opponent_abilities:
		ab.reset()


func update_ui_state() -> void:
	if board.ability_bar:
		board.ability_bar.visible = not board.logic.game_over
	var can_try = _can_use_player_abilities()

	var _state := _get_board_state()


func apply_ability(ability: Resource, _is_player: bool) -> Dictionary:
	var state := _get_board_state()
	if not ability.can_use(board.logic, state):
		return {}
	var result: Dictionary = ability.apply(board.logic, state)
	if result.get("skip_turn_switch", false):
		board._skip_turn_switch = true
	return result


func _on_double_play_pressed() -> void:
	if not _can_use_player_abilities():
		return
	var ability = _find_ability_by_type(player_abilities, DoublePlayAbilityScript)
	if ability == null:
		return
	var result = apply_ability(ability, true)
	if result.is_empty():
		update_ui_state()
		return
	board.status_label.text = result.get("description", "¡Habilidad activada!")
	update_ui_state()


func _on_steal_pressed() -> void:
	if not _can_use_player_abilities():
		return
	var ability = _find_ability_by_type(player_abilities, StealAbilityScript)
	if ability == null:
		return
	var result = apply_ability(ability, true)
	if result.is_empty():
		update_ui_state()
		return
	_apply_steal_visual(result)
	board.status_label.text = result.get("description", "¡Habilidad activada!")
	EventBus.board_state_changed.emit(board.logic.cells.duplicate())
	_recompute_game_state_after_ability()
	if board.logic.game_over:
		await board.game_controller.handle_game_over()
		return
	update_ui_state()


func _can_use_player_abilities() -> bool:
	if board.logic.game_over or board._animating:
		return false
	if not board.input_enabled:
		return false
	if board.logic.current_turn != board.player_piece:
		return false
	return true


func _find_ability_by_type(list: Array, ability_script: Script) -> Resource:
	for ab in list:
		if ab != null and ab.get_script() == ability_script:
			return ab
	return null


func _apply_steal_visual(result: Dictionary) -> void:
	var affected: Array = result.get("cells_affected", [])
	if affected.is_empty():
		return

	var cell_idx = int(affected[0])
	if cell_idx < 0 or cell_idx >= board.cells.size():
		return
	var pieces = board.pieces
	if not pieces.cell_to_piece.has(cell_idx):
		return

	var piece_node: Control = pieces.cell_to_piece[cell_idx]
	var from_piece = int(result.get("from_piece", board.ai_piece))
	var to_piece = int(result.get("to_piece", board.player_piece))

	if from_piece == board.ai_piece and to_piece == board.player_piece:
		var opp_idx = pieces.opponent_pieces.find(piece_node)
		if opp_idx >= 0:
			pieces.opponent_pieces.remove_at(opp_idx)
		if pieces.player_pieces.find(piece_node) < 0:
			pieces.player_pieces.append(piece_node)
		pieces.opponent_next = max(0, pieces.opponent_next - 1)
	elif from_piece == board.player_piece and to_piece == board.ai_piece:
		var player_idx = pieces.player_pieces.find(piece_node)
		if player_idx >= 0:
			pieces.player_pieces.remove_at(player_idx)
		if pieces.opponent_pieces.find(piece_node) < 0:
			pieces.opponent_pieces.append(piece_node)
		pieces.player_next = max(0, pieces.player_next - 1)

	_update_piece_node_identity(piece_node, to_piece)
	board.cells[cell_idx].set_occupied(true)
	pieces.position_hand_pieces(false)


func _update_piece_node_identity(piece_node: Control, piece_value: int) -> void:
	if not is_instance_valid(piece_node):
		return
	if piece_value == board.player_piece:
		piece_node.setup(board.player_design, "player", board.player_color)
	elif piece_value == board.ai_piece:
		piece_node.setup(board.opponent_design, "opponent", board.opponent_color)


func _get_board_state() -> Dictionary:
	return {
		"move_count": board.logic.move_count,
		"current_turn": board.logic.current_turn,
	}


func _recompute_game_state_after_ability() -> void:
	board.logic.recompute_game_state()
