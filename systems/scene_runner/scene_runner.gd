
extends RefCounted

## Executes scene commands produced by SceneParser.
## Needs references to the stage, board, and dialogue box nodes.

const PlacementStyleScript = preload("res://systems/board_visuals/placement_style.gd")
const CinematicCameraScript = preload("res://systems/cinematic/cinematic_camera.gd")

var _stage: Control       # CinematicStage
var _board: Control       # Board (can be null for pure cutscenes)
var _dialogue_box: Control  # DialogueBox
var _reactions: Dictionary = {}  # event_name -> Array[Dictionary]
var _running: bool = false
signal execution_finished
signal resumed
signal command_executed(label: String)
var _music_player: AudioStreamPlayer = null
var _sfx_player: AudioStreamPlayer = null
var auto_advance_dialogue: bool = false
var auto_advance_dialogue_delay: float = 1.0
var auto_choose_first: bool = false
var time_scale: float = 1.0
var paused: bool = false  # Editor preview cooperative pause
var current_context: String = ""  # Label for snapshots: "intro"/"reaction:name"
var _dialogue_auto_token: int = 0
var _last_music: String = ""


func setup(stage: Control, board: Control, dialogue_box: Control) -> void:
	_stage = stage
	_board = board
	_dialogue_box = dialogue_box
	_setup_audio_players()
	EventBus.dialogue_trigger.connect(_handle_dialogue_trigger)


func load_reactions(reactions_dict: Dictionary) -> void:
	for key in reactions_dict:
		_reactions[key] = reactions_dict[key]


func clear_reactions() -> void:
	_reactions.clear()


func has_reaction(event_name: String) -> bool:
	return _reactions.has(event_name)


func pause() -> void:
	paused = true


func resume() -> void:
	if paused:
		paused = false
		resumed.emit()


func get_reactions() -> Dictionary:
	return _reactions


func save_runner_state() -> Dictionary:
	return {
		"context": current_context,
		"music": _last_music,
	}


func load_runner_state(state: Dictionary) -> void:
	current_context = state.get("context", "")
	var track: String = state.get("music", "")
	if track != "" and track != _last_music:
		_cmd_music({"track": track})
	elif track == "" and _last_music != "":
		_cmd_stop_music()


func execute(data: Dictionary) -> void:
	if data.get("background") != "" and data.get("background") != null:
		_stage.set_background(data.background)
	var prev_ctx: String = current_context
	if current_context == "":
		current_context = "intro"
	await _run(data.commands)
	current_context = prev_ctx


func trigger_reaction(event_name: String) -> void:
	if not _reactions.has(event_name):
		return
	if _running:
		return  # Don't stack reactions
	var prev_ctx: String = current_context
	current_context = "reaction:%s" % event_name
	await _run(_reactions[event_name])
	current_context = prev_ctx


# ---- Execution engine ----

func _run(commands: Array) -> void:
	_running = true
	var skip_depth := 0  # > 0 = inside a false if-branch
	var cmd_index := 0

	for cmd in commands:
		# Cooperative pause for editor preview toolbar.
		if paused:
			await resumed

		# Conditional flow control while skipping
		if skip_depth > 0:
			match cmd.type:
				"if_flag":
					skip_depth += 1
				"else":
					if skip_depth == 1:
						skip_depth = 0
				"end_if":
					skip_depth -= 1
			cmd_index += 1
			continue

		match cmd.type:
			"dialogue":
				await _cmd_dialogue(cmd)
			"choose":
				await _cmd_choose(cmd)
			"enter":
				await _stage.enter_character(cmd.character, cmd.get("position", "center"), cmd.get("enter_from", ""))
			"exit":
				await _stage.exit_character(cmd.character, cmd.get("direction", ""))
			"move":
				await _stage.move_character(cmd.character, cmd.position)
			"shake":
				_stage.camera_effects.shake(cmd.intensity, cmd.get("duration", 0.3))
			"flash":
				_stage.camera_effects.flash(_resolve_color(cmd.get("color", "white")), cmd.get("duration", 0.3))
			"wait":
				await _wait_seconds(cmd.duration)
			"if_flag":
				if not GameState.get_flag(cmd.flag):
					skip_depth = 1
			"else":
				skip_depth = 1  # Was in true branch, now skip else
			"end_if":
				pass
			"set_flag":
				GameState.set_flag(cmd.flag, true)
			"clear_flag":
				GameState.set_flag(cmd.flag, false)
			"board_enable":
				EventBus.board_input_enabled.emit(true)
			"board_disable":
				EventBus.board_input_enabled.emit(false)
			"set_style":
				_cmd_set_style(cmd)
			"set_emotion":
				_cmd_set_emotion(cmd)
			"override_next_style":
				var style = _resolve_style(cmd.style)
				if style and _board:
					_board.override_next_style(style)
			"set_difficulty":
				if _board and _board.ai:
					_board.ai.difficulty = clampf(cmd.value, 0.0, 1.0)
			"expression":
				_stage.set_character_expression(cmd.character, cmd.expression)
			# --- Rich cinematic commands ---
			"look_at":
				_stage.set_look_at(cmd.character, cmd.target)
			"pose":
				_stage.set_body_state(cmd.character, cmd.state)
			"focus":
				if cmd.character != "":
					_stage.set_focus(cmd.character)
				else:
					_stage.clear_focus()
			"clear_focus":
				_stage.clear_focus()
			# --- Layout / Camera ---
			"layout":
				if _board != null:
					EventBus.layout_transition_requested.emit(cmd.mode)
					await EventBus.layout_transition_finished
				else:
					await _wait_seconds(0.01)
			"depth":
				var depth_dur = cmd.get("duration", 0.4)
				_stage.set_character_depth(cmd.character, cmd.get("depth", 1.0), depth_dur)
				await _wait_seconds(depth_dur)
			"close_up":
				_stage.camera_close_up(cmd.character, cmd.get("zoom", 1.4), cmd.get("duration", 0.5))
				var close_cam = _stage.get_camera()
				var close_dur = CinematicCameraScript.SNAPPY_DURATION if close_cam and close_cam.get_mode() == CinematicCameraScript.Mode.SNAPPY else CinematicCameraScript.SMOOTH_DURATION
				await _wait_seconds(close_dur)
			"pull_back":
				_stage.camera_pull_back(cmd.character, cmd.get("zoom", 0.8), cmd.get("duration", 0.5))
				var pull_cam = _stage.get_camera()
				var pull_dur = CinematicCameraScript.SNAPPY_DURATION if pull_cam and pull_cam.get_mode() == CinematicCameraScript.Mode.SNAPPY else CinematicCameraScript.SMOOTH_DURATION
				await _wait_seconds(pull_dur)
			"camera_reset":
				_stage.camera_reset(cmd.get("duration", 0.4))
				var reset_cam = _stage.get_camera()
				var reset_dur = CinematicCameraScript.SNAPPY_DURATION if reset_cam and reset_cam.get_mode() == CinematicCameraScript.Mode.SNAPPY else CinematicCameraScript.SMOOTH_DURATION
				await _wait_seconds(reset_dur)
			"camera_mode":
				_stage.set_camera_mode(cmd.mode)
			"camera_snap":
				_stage.camera_snap_to(cmd.character, cmd.get("zoom", 1.4))
				await _wait_seconds(CinematicCameraScript.SNAPPY_DURATION)
			"background":
				_stage.set_background(cmd.source)
			"music":
				_cmd_music(cmd)
			"sfx":
				_cmd_sfx(cmd)
			"stop_music":
				_cmd_stop_music()
			"title_card":
				await _stage.show_title_card(cmd.get("title", ""), cmd.get("subtitle", ""))
			"transition":
				await _cmd_transition(cmd)
			"clear_stage":
				_stage.clear_stage()
			"speed_lines":
				_stage.camera_effects.speed_lines(cmd.get("direction", "right"), cmd.get("duration", 0.3))
				await _wait_seconds(cmd.get("duration", 0.3))
			"wipe":
				_stage.camera_effects.wipe(cmd.get("direction", "right"), cmd.get("duration", 0.4))
				await _wait_seconds(cmd.get("duration", 0.4))
			"wipe_out":
				_stage.camera_effects.wipe_out(cmd.get("direction", "right"), cmd.get("duration", 0.4))
				await _wait_seconds(cmd.get("duration", 0.4))
			"layout_instant":
				if _board:
					var layout_mgr = _board.get_parent().get_parent()
					if layout_mgr and layout_mgr.has_method("set_instant"):
						layout_mgr.set_instant(cmd.get("mode", "fullscreen"))
			"board_cheat":
				if _board:
					await _cmd_board_cheat(cmd)

		# After-command hook for editor snapshot system.
		cmd_index += 1
		var label: String = "%s:%d %s" % [current_context if current_context != "" else "cmd", cmd_index, cmd.get("type", "")]
		command_executed.emit(label)

	_running = false
	execution_finished.emit()


# ---- Command implementations ----

func _cmd_dialogue(cmd: Dictionary) -> void:
	var char_id: String = cmd.character
	var expression: String = cmd.expression
	var text: String = cmd.text
	var target: String = cmd.get("target", "")
	var is_player := (char_id == "player")

	# Set talk target if directed dialogue
	if target != "" and not is_player:
		_stage.set_talk_target(char_id, target)

	# Expression + speaking state
	if expression != "" and not is_player:
		_stage.set_character_expression(char_id, expression)
		if _board:
			_board.set_piece_emotion(false, expression)
	if expression != "" and is_player and _board:
		_board.set_piece_emotion(true, expression)
	if not is_player:
		_stage.set_character_speaking(char_id, true)

	# Show dialogue
	var color = _stage.get_character_color(char_id)
	var display_name = _get_display_name(char_id)
	var char_data = _stage.get_character_data(char_id)

	# Add target indicator to dialogue if directed
	if target != "":
		var target_name = _get_display_name(target)
		_dialogue_box.show_dialogue("%s a %s" % [display_name, target_name], text, color, char_data)
	else:
		_dialogue_box.show_dialogue(display_name, text, color, char_data)

	if auto_advance_dialogue:
		_dialogue_auto_token += 1
		var my_token: int = _dialogue_auto_token
		var raw_delay := auto_advance_dialogue_delay
		var dynamic_delay := 0.45 + float(text.length()) * 0.02
		var delay := maxf(raw_delay, dynamic_delay)
		var tree = _stage.get_tree()
		var timer = tree.create_timer(_scaled_duration(delay))
		timer.timeout.connect(func():
			if my_token != _dialogue_auto_token:
				return
			if _dialogue_box and is_instance_valid(_dialogue_box) and _dialogue_box.is_active:
				_dialogue_box.hide_dialogue()
				EventBus.dialogue_finished.emit())

	await EventBus.dialogue_finished

	if not is_player:
		_stage.set_character_speaking(char_id, false)
		if target != "":
			_stage.set_talk_target(char_id, "")


func _cmd_choose(cmd: Dictionary) -> void:
	var color = _stage.get_character_color("player")
	_dialogue_box.show_choices(cmd.options, color)
	if auto_choose_first:
		await _wait_seconds(0.12)
		var options: Array = cmd.get("options", [])
		var chosen_flag: String = ""
		if not options.is_empty():
			chosen_flag = str(options[0].get("flag", ""))
		if chosen_flag != "":
			if _dialogue_box and is_instance_valid(_dialogue_box) and _dialogue_box.has_method("_select_choice"):
				_dialogue_box.call("_select_choice", chosen_flag)
			GameState.set_flag(chosen_flag, true)
		return
	var chosen_flag = await EventBus.choice_made
	GameState.set_flag(chosen_flag, true)


func _cmd_set_style(cmd: Dictionary) -> void:
	if not _board:
		return
	var style = _resolve_style(cmd.style)
	if not style:
		return
	match cmd.target:
		"player":
			_board.set_player_style(style)
		"opponent":
			_board.set_opponent_style(style)


func _cmd_set_emotion(cmd: Dictionary) -> void:
	if not _board:
		return
	match cmd.target:
		"player":
			_board.set_piece_emotion(true, cmd.emotion)
		"opponent":
			_board.set_piece_emotion(false, cmd.emotion)


func _cmd_music(cmd: Dictionary) -> void:
	_setup_audio_players()
	if _music_player == null:
		return

	var track: String = cmd.get("track", "")
	if track == "":
		push_warning("SceneRunner: [music] requires a track path")
		return

	# Don't restart if the same track is already playing (e.g. next scene
	# re-issues the same [music] tag).
	if track == _last_music and _music_player.playing:
		return

	var stream: AudioStream = _load_audio_stream(track)
	if stream == null:
		push_warning("SceneRunner: music track not found or unsupported: %s" % track)
		return

	# Loop is configured in the .import files for every music track, so we
	# don't need to mutate the stream at runtime.
	_music_player.stream = stream
	_music_player.play()
	_last_music = track
	print("[SceneRunner] music play: %s (playing=%s)" % [track, _music_player.playing])


func _cmd_sfx(cmd: Dictionary) -> void:
	_setup_audio_players()
	if _sfx_player == null:
		return

	var sound: String = cmd.get("sound", "")
	if sound == "":
		push_warning("SceneRunner: [sfx] requires a sound path")
		return

	var stream: AudioStream = _load_audio_stream(sound)
	if stream == null:
		push_warning("SceneRunner: sfx not found or unsupported: %s" % sound)
		return

	_sfx_player.stream = stream
	_sfx_player.play()


func _cmd_stop_music() -> void:
	if _music_player and _music_player.playing:
		_music_player.stop()
	_last_music = ""


func _cmd_transition(cmd: Dictionary) -> void:
	var style: String = cmd.get("style", "fade_black")
	var duration: float = cmd.get("duration", 0.5)
	var half: float = _scaled_duration(duration / 2.0)
	var color := Color.BLACK
	match style:
		"fade_black": color = Color.BLACK
		"fade_white": color = Color.WHITE
		"flash_red": color = Color(0.8, 0.1, 0.1)
		"flash_blue": color = Color(0.1, 0.1, 0.8)

	# Create overlay for transition
	var overlay := ColorRect.new()
	overlay.color = Color(color.r, color.g, color.b, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	_stage.add_child(overlay)

	# Fade to color
	var tween := _stage.create_tween()
	tween.tween_property(overlay, "color:a", 1.0, half)
	await tween.finished

	# Hold briefly
	await _wait_seconds(0.15)

	# Fade back
	var tween2 := _stage.create_tween()
	tween2.tween_property(overlay, "color:a", 0.0, half)
	await tween2.finished

	overlay.queue_free()


func _setup_audio_players() -> void:
	if _stage == null:
		return
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "SceneMusicPlayer"
		_music_player.bus = "Master"
		_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_stage.add_child(_music_player)
	if _sfx_player == null:
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.name = "SceneSfxPlayer"
		_sfx_player.bus = "Master"
		_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_stage.add_child(_sfx_player)
	_update_audio_volumes()


func _update_audio_volumes() -> void:
	# Settings is an autoload; if unavailable, keep sane defaults.
	if _music_player:
		var music_linear := 1.0
		if typeof(Settings) != TYPE_NIL:
			music_linear = clampf(Settings.master_volume * Settings.music_volume, 0.0001, 1.0)
		_music_player.volume_db = linear_to_db(music_linear)
	if _sfx_player:
		var sfx_linear := 1.0
		if typeof(Settings) != TYPE_NIL:
			sfx_linear = clampf(Settings.master_volume * Settings.sfx_volume, 0.0001, 1.0)
		_sfx_player.volume_db = linear_to_db(sfx_linear)


func _load_audio_stream(path_or_key: String) -> AudioStream:
	var candidate := path_or_key.strip_edges()
	if candidate == "":
		return null
	candidate = candidate.replace("\\", "/")

	# Allow direct resource paths.
	if candidate.begins_with("res://") or candidate.begins_with("user://"):
		if ResourceLoader.exists(candidate):
			var stream = load(candidate)
			return stream if stream is AudioStream else null
		return null

	# Convenience lookup by simple name.
	var alias_key := candidate.to_lower().replace(" ", "_").replace("-", "_")
	var aliases := {
		"ryu_pressure": "bgm_tournament_drive",
		"bgm_ryu_pressure": "bgm_tournament_drive",
		"mei_payoff": "bgm_sora_intimate",
		"bgm_mei_payoff": "bgm_sora_intimate",
	}
	if aliases.has(alias_key):
		candidate = aliases[alias_key]

	var candidates = [
		"res://audio/music/%s.ogg" % candidate,
		"res://audio/music/%s.wav" % candidate,
		"res://audio/music/%s.mp3" % candidate,
		"res://audio/sfx/%s.ogg" % candidate,
		"res://audio/sfx/%s.wav" % candidate,
		"res://audio/sfx/%s.mp3" % candidate,
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			var stream = load(p)
			if stream is AudioStream:
				return stream
	return null


# ---- Resolvers ----

func _get_display_name(char_id: String) -> String:
	if _stage._character_registry.has(char_id):
		return _stage._character_registry[char_id].display_name
	return char_id


func _resolve_style(name: String) -> Resource:
	match name:
		"gentle": return PlacementStyleScript.gentle()
		"slam": return PlacementStyleScript.slam()
		"spinning": return PlacementStyleScript.spinning()
		"dramatic": return PlacementStyleScript.dramatic()
		"nervous": return PlacementStyleScript.nervous()
	push_warning("SceneRunner: unknown style '%s'" % name)
	return null


static func _resolve_color(name: String) -> Color:
	match name.to_lower():
		"white": return Color.WHITE
		"black": return Color.BLACK
		"red": return Color.RED
		"blue": return Color.BLUE
		"yellow": return Color.YELLOW
		"green": return Color.GREEN
	if name.begins_with("#"):
		return Color.html(name)
	return Color.WHITE


func _cmd_board_cheat(cmd: Dictionary) -> void:
	## Manipulate the board so the opponent has an immediate winning move.
	## Clears board, places opponent pieces in a near-win configuration,
	## keeps the same amount of already-placed player pieces,
	## plays placement SFX, and applies imprecision.
	var logic = _board.logic
	var rules = logic.rules
	var width: int = rules.get_width()
	var height: int = rules.get_height()
	var total_cells: int = logic.cells.size()
	var ai = _board.ai_piece
	var player = _board.player_piece

	# Keep how many player pieces were already on the board before cheating.
	var previous_player_count := 0
	for cell_value in logic.cells:
		if cell_value == player:
			previous_player_count += 1

	# Build deterministic layout where AI is one move away from winning.
	var ai_cells: Array[int] = []
	if total_cells > 0:
		ai_cells.append(0)
	if total_cells > 1:
		ai_cells.append(1)
	var ai_winning_cell := 2 if total_cells > 2 else -1

	var reserved := {}
	for cell_idx in ai_cells:
		reserved[cell_idx] = true
	if ai_winning_cell >= 0:
		reserved[ai_winning_cell] = true

	var player_candidates: Array[int] = []
	var center_idx := (height / 2) * width + (width / 2)
	if width % 2 == 1 and height % 2 == 1:
		if center_idx >= 0 and center_idx < total_cells and not reserved.has(center_idx):
			player_candidates.append(center_idx)
	var bottom_left := (height - 1) * width
	if bottom_left >= 0 and bottom_left < total_cells and not reserved.has(bottom_left):
		if not player_candidates.has(bottom_left):
			player_candidates.append(bottom_left)
	var bottom_right := bottom_left + width - 1
	if bottom_right >= 0 and bottom_right < total_cells and not reserved.has(bottom_right):
		if not player_candidates.has(bottom_right):
			player_candidates.append(bottom_right)
	for idx in range(total_cells):
		if reserved.has(idx):
			continue
		if player_candidates.has(idx):
			continue
		player_candidates.append(idx)

	var max_player_on_board: int = mini(_board.pieces.player_pieces.size(), player_candidates.size())
	var target_player_count: int = mini(previous_player_count, max_player_on_board)

	# Clear the board state completely
	for i in range(logic.cells.size()):
		logic.cells[i] = 0

	for cell_idx in ai_cells:
		logic.cells[cell_idx] = ai

	var player_cells: Array[int] = []
	for i in range(target_player_count):
		var p_cell: int = player_candidates[i]
		player_cells.append(p_cell)
		logic.cells[p_cell] = player

	# Update move history for rotation mode
	logic.move_history = {player: player_cells.duplicate(), ai: ai_cells.duplicate()}
	logic.move_count = ai_cells.size() + player_cells.size()

	# Clear visual pieces and rebuild with imprecision + SFX
	_board.pieces.cell_to_piece.clear()
	for p in _board.pieces.player_pieces:
		if is_instance_valid(p):
			p.modulate.a = 0.0
	for p in _board.pieces.opponent_pieces:
		if is_instance_valid(p):
			p.modulate.a = 0.0

	# Place opponent visual pieces with SFX and imprecision
	var cell_size = _board.pieces.get_cell_size()
	var piece_size = cell_size * _board.pieces.get_piece_ratio()
	var offset_max: float = cell_size.x * 0.25  # Strong imprecision

	var opp_idx := 0
	for cell_idx in ai_cells:
		if opp_idx >= _board.pieces.opponent_pieces.size():
			break
		var piece = _board.pieces.opponent_pieces[opp_idx]
		var target = _board.pieces.get_cell_pos_in_layer(cell_idx)
		var off = (cell_size - piece_size) / 2.0
		var rand_off = Vector2(randf_range(-offset_max, offset_max), randf_range(-offset_max, offset_max))
		piece.position = target + off + rand_off
		piece.placement_offset = rand_off
		piece.size = piece_size
		piece.pivot_offset = piece_size / 2.0
		piece.modulate.a = 1.0
		_board.pieces.cell_to_piece[cell_idx] = piece
		_board.cells[cell_idx].set_occupied(true)
		opp_idx += 1
		# SFX
		if _board.board_audio:
			_board.board_audio.play_sfx("impact_light")
		await _wait_seconds(0.15)

	# Place player visual pieces
	var player_used := 0
	for p_cell in player_cells:
		if player_used >= _board.pieces.player_pieces.size():
			break
		var pp = _board.pieces.player_pieces[player_used]
		var p_target = _board.pieces.get_cell_pos_in_layer(p_cell)
		var p_off = (cell_size - piece_size) / 2.0
		pp.position = p_target + p_off
		pp.placement_offset = Vector2.ZERO
		pp.size = piece_size
		pp.pivot_offset = piece_size / 2.0
		pp.modulate.a = 1.0
		_board.pieces.cell_to_piece[p_cell] = pp
		_board.cells[p_cell].set_occupied(true)
		player_used += 1

	# Sync piece counters with the visual pieces we consumed. Without this the
	# next AI move reuses an already-placed piece, making it look like Mei
	# dragged her last piece to the winning cell.
	_board.pieces.opponent_next = opp_idx
	_board.pieces.player_next = player_used

	# Restore visibility + hand layout for pieces we didn't place on a cell.
	# The earlier blanket modulate.a = 0 pass hid them to clear old positions,
	# but the ones returning to the hand must be visible again.
	for i in range(_board.pieces.opponent_pieces.size()):
		if i >= opp_idx:
			var op_piece = _board.pieces.opponent_pieces[i]
			if is_instance_valid(op_piece):
				op_piece.modulate.a = 1.0
	for i in range(_board.pieces.player_pieces.size()):
		if i >= player_used:
			var pl_piece = _board.pieces.player_pieces[i]
			if is_instance_valid(pl_piece):
				pl_piece.modulate.a = 1.0
	_board.pieces.position_hand_pieces(false)

	# Sync per-cell occupied flag with the cheated logical state so previously
	# filled cells (from pre-cheat moves) stop blocking input / ghosts.
	for i in range(_board.cells.size()):
		_board.cells[i].set_occupied(logic.cells[i] != 0)

	# Set turn to AI so it can make the winning move
	logic.current_turn = ai
	logic.game_over = false
	logic.winner = 0
	logic.winning_pattern.clear()


func _handle_dialogue_trigger(trigger_name: String) -> void:
	match trigger_name:
		"ai_move":
			if _board:
				_board.trigger_ai_turn()  # Fire and forget, don't await


func _scaled_duration(seconds: float) -> float:
	var scale := maxf(time_scale, 0.0)
	return maxf(0.0, seconds * scale)


func _wait_seconds(seconds: float) -> void:
	var tree = _stage.get_tree() if _stage else null
	if tree == null:
		return
	var d := _scaled_duration(seconds)
	if d <= 0.0:
		await tree.process_frame
	else:
		await tree.create_timer(d).timeout
