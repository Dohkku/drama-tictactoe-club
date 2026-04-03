extends SceneTree

const BL = preload("res://systems/board_logic/board_logic.gd")
const GR = preload("res://systems/board_logic/game_rules.gd")
const AI = preload("res://systems/board_logic/ai_player.gd")

func _init():
	print("=== Testing BoardLogic ===")
	var board = BL.new()

	# Test 1: Basic moves
	print("\n--- Test 1: Basic moves ---")
	assert(board.make_move(4).success == true, "Center move should succeed")
	assert(board.cells[4] == 1, "Cell 4 should be player 1")
	assert(board.current_turn == 2, "Turn should switch to player 2")
	assert(board.make_move(4).success == false, "Duplicate move should fail")
	print("PASS: Basic moves work")

	# Test 2: Win detection
	print("\n--- Test 2: Win detection ---")
	board.reset()
	board.make_move(0)  # P1
	board.make_move(3)  # P2
	board.make_move(1)  # P1
	board.make_move(4)  # P2
	board.make_move(2)  # P1 - wins top row
	assert(board.game_over == true, "Game should be over")
	assert(board.winner == 1, "Player 1 should win")
	print("PASS: Win detection works")

	# Test 3: Draw detection
	print("\n--- Test 3: Draw detection ---")
	board.reset()
	board.make_move(0)  # P1
	board.make_move(1)  # P2
	board.make_move(2)  # P1
	board.make_move(5)  # P2
	board.make_move(3)  # P1
	board.make_move(6)  # P2
	board.make_move(4)  # P1
	board.make_move(8)  # P2
	board.make_move(7)  # P1
	assert(board.game_over == true, "Game should be over")
	assert(board.winner == BL.EMPTY, "Should be a draw")
	print("PASS: Draw detection works")

	# Test 4: Pattern detection via MoveResult
	print("\n--- Test 4: Pattern detection ---")
	board.reset()
	var result = board.make_move(4)  # P1 takes center
	var patterns = board.get_patterns_from_result(result)
	assert("center_taken_by_player" in patterns, "Should detect center taken")
	print("Patterns after center: ", patterns)
	print("PASS: Pattern detection works")

	# Test 5: Valid moves
	print("\n--- Test 5: Valid moves ---")
	board.reset()
	board.make_move(0)
	board.make_move(4)
	var valid = board.get_valid_moves()
	assert(valid.size() == 7, "Should have 7 valid moves")
	assert(0 not in valid, "Cell 0 should not be valid")
	assert(4 not in valid, "Cell 4 should not be valid")
	print("PASS: Valid moves work")

	# Test 6: Piece rotation (new feature)
	print("\n--- Test 6: Piece rotation ---")
	var rotating_rules = GR.new()
	rotating_rules.max_pieces_per_player = 3
	rotating_rules.overflow_mode = "rotate"
	var rot_board = BL.new(rotating_rules)

	rot_board.make_move(0) # P1-1
	rot_board.make_move(1) # P2-1
	rot_board.make_move(2) # P1-2
	rot_board.make_move(3) # P2-2
	rot_board.make_move(4) # P1-3
	rot_board.make_move(5) # P2-3

	# Current state: P1 at [0, 2, 4], P2 at [1, 3, 5]
	assert(rot_board.cells[0] == 1, "P1 still has first piece")

	# P1 places 4th piece, 1st (at 0) should disappear
	var move_result = rot_board.make_move(8) # P1-4
	assert(move_result.success == true, "4th move should succeed")
	assert(move_result.removed_cell == 0, "Cell 0 should have been removed")
	assert(rot_board.cells[0] == BL.EMPTY, "Cell 0 should be empty now")
	assert(rot_board.cells[8] == 1, "Cell 8 should be player 1")
	print("PASS: Piece rotation works")

	# Test 7: AI handles rotating rules via make_move simulation
	print("\n--- Test 7: AI with rotating rules ---")
	var ai = AI.new()
	ai.difficulty = 1.0
	ai.max_search_depth_override = 4
	var ai_move = ai.choose_move(rot_board)
	assert(ai_move >= 0, "AI should return a valid move on rotating board")
	assert(ai_move in rot_board.get_valid_moves(), "AI move must be valid under current rules")
	print("PASS: AI rotating-rule move selection works")

	print("\n=== All BoardLogic tests PASSED ===")
	quit()
