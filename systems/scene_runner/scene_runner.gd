
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
var _music_player: AudioStreamPlayer = null
var _sfx_player: AudioStreamPlayer = null


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


func execute(data: Dictionary) -> void:
	if data.get("background") != "" and data.get("background") != null:
		_stage.set_background(data.background)
	await _run(data.commands)


func trigger_reaction(event_name: String) -> void:
	if not _reactions.has(event_name):
		return
	if _running:
		return  # Don't stack reactions
	await _run(_reactions[event_name])


# ---- Execution engine ----

func _run(commands: Array) -> void:
	_running = true
	var skip_depth := 0  # > 0 = inside a false if-branch

	for cmd in commands:
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
				await _stage.get_tree().create_timer(cmd.duration).timeout
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
				EventBus.layout_transition_requested.emit(cmd.mode)
				await EventBus.layout_transition_finished
			"depth":
				var depth_dur = cmd.get("duration", 0.4)
				_stage.set_character_depth(cmd.character, cmd.get("depth", 1.0), depth_dur)
				await _stage.get_tree().create_timer(depth_dur).timeout
			"close_up":
				_stage.camera_close_up(cmd.character, cmd.get("zoom", 1.4), cmd.get("duration", 0.5))
				var close_cam = _stage.get_camera()
				var close_dur = CinematicCameraScript.SNAPPY_DURATION if close_cam and close_cam.get_mode() == CinematicCameraScript.Mode.SNAPPY else CinematicCameraScript.SMOOTH_DURATION
				await _stage.get_tree().create_timer(close_dur).timeout
			"pull_back":
				_stage.camera_pull_back(cmd.character, cmd.get("zoom", 0.8), cmd.get("duration", 0.5))
				var pull_cam = _stage.get_camera()
				var pull_dur = CinematicCameraScript.SNAPPY_DURATION if pull_cam and pull_cam.get_mode() == CinematicCameraScript.Mode.SNAPPY else CinematicCameraScript.SMOOTH_DURATION
				await _stage.get_tree().create_timer(pull_dur).timeout
			"camera_reset":
				_stage.camera_reset(cmd.get("duration", 0.4))
				var reset_cam = _stage.get_camera()
				var reset_dur = CinematicCameraScript.SNAPPY_DURATION if reset_cam and reset_cam.get_mode() == CinematicCameraScript.Mode.SNAPPY else CinematicCameraScript.SMOOTH_DURATION
				await _stage.get_tree().create_timer(reset_dur).timeout
			"camera_mode":
				_stage.set_camera_mode(cmd.mode)
			"camera_snap":
				_stage.camera_snap_to(cmd.character, cmd.get("zoom", 1.4))
				await _stage.get_tree().create_timer(CinematicCameraScript.SNAPPY_DURATION).timeout
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

	_running = false


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
		_dialogue_box.show_dialogue("%s → %s" % [display_name, target_name], text, color, char_data)
	else:
		_dialogue_box.show_dialogue(display_name, text, color, char_data)

	await EventBus.dialogue_finished

	if not is_player:
		_stage.set_character_speaking(char_id, false)
		if target != "":
			_stage.set_talk_target(char_id, "")


func _cmd_choose(cmd: Dictionary) -> void:
	var color = _stage.get_character_color("player")
	_dialogue_box.show_choices(cmd.options, color)
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

	var stream: AudioStream = _load_audio_stream(track)
	if stream == null:
		push_warning("SceneRunner: music track not found or unsupported: %s" % track)
		return

	_music_player.stream = stream
	_music_player.play()


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
	var candidates = [
		"res://audio/music/%s.ogg" % candidate,
		"res://audio/music/%s.wav" % candidate,
		"res://audio/sfx/%s.ogg" % candidate,
		"res://audio/sfx/%s.wav" % candidate,
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


func _handle_dialogue_trigger(trigger_name: String) -> void:
	match trigger_name:
		"ai_move":
			if _board:
				_board.trigger_ai_turn()  # Fire and forget, don't await
