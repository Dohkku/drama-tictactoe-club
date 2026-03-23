extends SceneTree

const BL = preload("res://board/board_logic.gd")

func _init():
	print("=== Testing BoardLogic ===")
	var board = BL.new()

	# Test 1: Basic moves
	print("\n--- Test 1: Basic moves ---")
	assert(board.make_move(4) == true, "Center move should succeed")
	assert(board.cells[4] == BL.Piece.X, "Cell 4 should be X")
	assert(board.current_turn == BL.Piece.O, "Turn should switch to O")
	assert(board.make_move(4) == false, "Duplicate move should fail")
	print("PASS: Basic moves work")

	# Test 2: Win detection
	print("\n--- Test 2: Win detection ---")
	board.reset()
	board.make_move(0)  # X
	board.make_move(3)  # O
	board.make_move(1)  # X
	board.make_move(4)  # O
	board.make_move(2)  # X - wins top row
	assert(board.game_over == true, "Game should be over")
	assert(board.winner == BL.Piece.X, "X should win")
	print("PASS: Win detection works")

	# Test 3: Draw detection
	print("\n--- Test 3: Draw detection ---")
	board.reset()
	board.make_move(0)  # X
	board.make_move(1)  # O
	board.make_move(2)  # X
	board.make_move(5)  # O
	board.make_move(3)  # X
	board.make_move(6)  # O
	board.make_move(4)  # X
	board.make_move(8)  # O
	board.make_move(7)  # X
	assert(board.game_over == true, "Game should be over")
	assert(board.winner == BL.Piece.EMPTY, "Should be a draw")
	print("PASS: Draw detection works")

	# Test 4: Pattern detection
	print("\n--- Test 4: Pattern detection ---")
	board.reset()
	board.make_move(4)  # X takes center
	var patterns = board.detect_patterns(4, BL.Piece.X)
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

	print("\n=== All BoardLogic tests PASSED ===")
	quit()
