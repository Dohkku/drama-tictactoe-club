extends SceneTree

## Integration test: simulates full tournament flow with player input.
## Run: godot --headless --script board/test_game_flow.gd

const BoardLogicScript = preload("res://systems/board_logic/board_logic.gd")
const GameRulesScript = preload("res://systems/board_logic/game_rules.gd")
const AIPlayerScript = preload("res://systems/board_logic/ai_player.gd")
const SceneParserScript = preload("res://scene_scripts/parser/scene_parser.gd")
const PlacementStyleScript = preload("res://systems/board_visuals/placement_style.gd")

var _pass_count := 0
var _fail_count := 0


func _init():
	print("=== Integration Test: Game Flow ===\n")

	test_board_logic_full_game()
	test_ai_responds_to_all_moves()
	test_scene_parser_all_scripts()
	test_placement_styles()
	test_board_logic_rotating_rules()
	test_title_card_parsing()

	print("\n=== Results: %d PASSED, %d FAILED ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		print("!!! SOME TESTS FAILED !!!")
	quit()


func _assert(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % msg)
	else:
		_fail_count += 1
		print("  FAIL: %s" % msg)


func test_board_logic_full_game() -> void:
	print("\n--- Test: Full game simulation (player vs AI) ---")
	var rules = GameRulesScript.new()
	var board = BoardLogicScript.new(rules)
	var ai = AIPlayerScript.new()
	ai.difficulty = 0.5

	var moves_made := 0
	var max_moves := rules.get_total_cells()

	while not board.game_over and moves_made < max_moves:
		var valid = board.get_valid_moves()
		_assert(valid.size() > 0, "Move %d: valid moves available (%d)" % [moves_made, valid.size()])

		if board.current_turn == 1:  # Player
			var move = valid[0]  # Simple strategy: take first available
			var result = board.make_move(move)
			_assert(result.success, "Player move %d at cell %d succeeded" % [moves_made, move])
		else:  # AI
			var ai_move = ai.choose_move(board)
			_assert(ai_move >= 0, "AI chose valid move at cell %d" % ai_move)
			var result = board.make_move(ai_move)
			_assert(result.success, "AI move at cell %d succeeded" % ai_move)

		moves_made += 1

	_assert(board.game_over, "Game ended after %d moves" % moves_made)
	if board.winner == 1:
		print("  INFO: Player 1 won")
	elif board.winner == 2:
		print("  INFO: Player 2 (AI) won")
	else:
		print("  INFO: Draw")


func test_ai_responds_to_all_moves() -> void:
	print("\n--- Test: AI responds correctly at every board state ---")
	var rules = GameRulesScript.new()
	var ai = AIPlayerScript.new()
	ai.difficulty = 1.0

	# Test AI on empty board
	var board = BoardLogicScript.new(rules)
	board.make_move(4)  # Player takes center
	board.current_turn = 2  # Force AI turn
	var move = ai.choose_move(board)
	_assert(move >= 0 and move != 4, "AI picks valid cell (not center) after player takes center")

	# Test AI blocks a win
	board = BoardLogicScript.new(rules)
	board.make_move(0)  # P1
	board.make_move(3)  # P2
	board.make_move(1)  # P1 - two in a row at top
	# AI should block at cell 2
	var block_move = ai.choose_move(board)
	_assert(block_move == 2, "AI blocks player win at cell 2 (got %d)" % block_move)


func test_scene_parser_all_scripts() -> void:
	print("\n--- Test: Parse all .dscn script files ---")
	var dir = DirAccess.open("res://scene_scripts/scripts/")
	if not dir:
		_assert(false, "Could not open scripts directory")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var count := 0

	while file_name != "":
		if file_name.ends_with(".dscn"):
			var path = "res://scene_scripts/scripts/%s" % file_name
			var data = SceneParserScript.parse_file(path)
			var has_content = data.commands.size() > 0 or data.reactions.size() > 0
			_assert(has_content, "Parsed %s: %d commands, %d reaction events" % [
				file_name,
				data.commands.size(),
				data.reactions.size()
			])
			count += 1
		file_name = dir.get_next()

	dir.list_dir_end()
	_assert(count > 0, "Found %d .dscn files total" % count)


func test_placement_styles() -> void:
	print("\n--- Test: Placement styles have valid durations ---")
	var styles = {
		"gentle": PlacementStyleScript.gentle(),
		"slam": PlacementStyleScript.slam(),
		"spinning": PlacementStyleScript.spinning(),
		"dramatic": PlacementStyleScript.dramatic(),
		"nervous": PlacementStyleScript.nervous(),
	}
	for name in styles:
		var s = styles[name]
		_assert(s.arc_duration > 0.3, "%s: arc_duration %.2f > 0.3 (slow enough)" % [name, s.arc_duration])
		_assert(s.settle_duration > 0.1, "%s: settle_duration %.2f > 0.1" % [name, s.settle_duration])
		_assert(s.lift_height > 0, "%s: lift_height %.1f > 0" % [name, s.lift_height])


func test_board_logic_rotating_rules() -> void:
	print("\n--- Test: Rotating rules game simulation ---")
	var rules = GameRulesScript.rotating_3()
	var board = BoardLogicScript.new(rules)
	var ai = AIPlayerScript.new()
	ai.difficulty = 0.8

	var moves_made := 0
	while not board.game_over and moves_made < 20:
		var valid = board.get_valid_moves()
		if valid.is_empty():
			break

		if board.current_turn == 1:
			var result = board.make_move(valid[randi() % valid.size()])
			_assert(result.success, "Rotating: player move %d succeeded" % moves_made)
		else:
			var ai_move = ai.choose_move(board)
			if ai_move >= 0:
				board.make_move(ai_move)
		moves_made += 1

	# Count pieces per player - should never exceed max_pieces_per_player
	var p1_count := 0
	var p2_count := 0
	for cell in board.cells:
		if cell == 1: p1_count += 1
		elif cell == 2: p2_count += 1
	_assert(p1_count <= 3, "Rotating: P1 has %d pieces (<= 3 max)" % p1_count)
	_assert(p2_count <= 3, "Rotating: P2 has %d pieces (<= 3 max)" % p2_count)
	print("  INFO: Game ended after %d moves (winner: %d)" % [moves_made, board.winner])


func test_title_card_parsing() -> void:
	print("\n--- Test: Title card DSL command parsing ---")
	var text := """
@scene test

[title_card Capítulo 1 | La Invitación]
[title_card Solo Título]
[wait 1.0]

@end
"""
	var data = SceneParserScript.parse(text)
	_assert(data.commands.size() == 3, "Parsed 3 commands (got %d)" % data.commands.size())

	if data.commands.size() >= 2:
		var tc1 = data.commands[0]
		_assert(tc1.type == "title_card", "First command is title_card")
		_assert(tc1.title == "Capítulo 1", "Title is 'Capítulo 1' (got '%s')" % tc1.get("title", ""))
		_assert(tc1.subtitle == "La Invitación", "Subtitle is 'La Invitación' (got '%s')" % tc1.get("subtitle", ""))

		var tc2 = data.commands[1]
		_assert(tc2.type == "title_card", "Second command is title_card")
		_assert(tc2.title == "Solo Título", "Title only (got '%s')" % tc2.get("title", ""))
		_assert(tc2.subtitle == "", "No subtitle (got '%s')" % tc2.get("subtitle", ""))
