extends Node

# === Board events ===
signal move_made(cell_index: int, piece: String)
signal board_state_changed(board: Array)
signal game_won(winner: String)
signal game_draw()
signal game_started()
signal turn_changed(whose_turn: String)
signal specific_pattern(pattern_name: String)

# === Cinematic events ===
signal dialogue_started(speaker: String, text: String)
signal dialogue_finished()
signal character_entered(character_id: String)
signal character_exited(character_id: String)
signal scene_script_finished(script_id: String)

# === Match management ===
signal match_started(match_config: Resource)
signal match_ended(result: String)
signal tournament_progressed(match_index: int)

# === UI / Layout ===
signal transition_requested(transition_type: String)
signal board_input_enabled(enabled: bool)
signal layout_transition_requested(mode: String)  # "fullscreen", "split", "board_only"
signal layout_transition_finished()

# === Debug ===
signal effect_triggered(effect_name: String, intensity: float)
