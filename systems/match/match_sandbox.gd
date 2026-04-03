extends Control

## Interactive sandbox for the Match Orchestrator system.
## Shows match configuration, event types, and simulates a demo sequence log.

const MatchConfigScript: GDScript = preload("res://systems/match/match_config.gd")

# UI references
var log_label: RichTextLabel
var log_lines: Array[String] = []
var status_label: Label
var demo_btn: Button
var clear_events_btn: Button

# Config controls
var opponent_option: OptionButton
var difficulty_slider: HSlider
var difficulty_value: Label
var board_size_option: OptionButton
var turns_spin: SpinBox
var style_option: OptionButton

# Event queue display
var event_list: ItemList
var add_match_btn: Button
var add_cutscene_btn: Button
var add_sim_btn: Button

# Info panel
var info_label: RichTextLabel

# State
var _events: Array[Dictionary] = []
var _running: bool = false

const OPPONENTS := ["rival", "bully", "nerd", "coach", "shadow"]
const STYLES := ["gentle", "slam", "spinning", "dramatic", "nervous"]
const BOARD_SIZES := [3, 4, 5]


func _ready() -> void:
	_build_ui()
	_update_info()
	_log("[color=cyan]Match Sandbox initialized[/color]")
	_log("This system orchestrates tournaments: sequences of matches, cutscenes, and simultaneous round-robin matches.")
	_log("")
	_log("Add events to the queue, then run the demo sequence.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://systems/dev_menu.tscn")


# ---- Event queue management ----

func _add_match_event() -> void:
	var opp: String = OPPONENTS[opponent_option.selected]
	var diff: float = difficulty_slider.value
	var size: int = BOARD_SIZES[board_size_option.selected]
	var style: String = STYLES[style_option.selected]
	var turns: int = int(turns_spin.value)

	var ev := {
		"type": "match",
		"opponent": opp,
		"difficulty": diff,
		"board_size": size,
		"style": style,
		"turns_per_visit": turns,
	}
	_events.append(ev)
	event_list.add_item("MATCH: %s (diff=%.1f, %dx%d)" % [opp, diff, size, size])
	_log("Added match: %s (difficulty=%.1f, board=%dx%d, style=%s)" % [opp, diff, size, size, style])


func _add_cutscene_event() -> void:
	var ev := {"type": "cutscene", "script": "intro_%d.dscn" % (_events.size() + 1)}
	_events.append(ev)
	event_list.add_item("CUTSCENE: %s" % ev.script)
	_log("Added cutscene: %s" % ev.script)


func _add_simultaneous_event() -> void:
	var opp1: String = OPPONENTS[opponent_option.selected]
	var opp2: String = OPPONENTS[(opponent_option.selected + 1) % OPPONENTS.size()]
	var ev := {
		"type": "simultaneous",
		"opponents": [opp1, opp2],
		"turns_per_visit": int(turns_spin.value),
	}
	_events.append(ev)
	event_list.add_item("SIMULTANEOUS: %s vs %s" % [opp1, opp2])
	_log("Added simultaneous: [%s, %s] (turns/visit=%d)" % [opp1, opp2, ev.turns_per_visit])


func _clear_events() -> void:
	_events.clear()
	event_list.clear()
	_log("[color=yellow]Event queue cleared[/color]")


func _run_demo_sequence() -> void:
	if _events.is_empty():
		_log("[color=red]No events in queue. Add some first.[/color]")
		return
	if _running:
		_log("[color=red]Demo already running[/color]")
		return

	_running = true
	_update_button_states()
	_log("")
	_log("[color=cyan]===== DEMO SEQUENCE START =====[/color]")
	_log("MatchManager.start() called with %d events" % _events.size())
	_log("")

	for i in range(_events.size()):
		var ev: Dictionary = _events[i]
		_log("[color=white]--- Event %d/%d ---[/color]" % [i + 1, _events.size()])

		match ev.type:
			"match":
				await _demo_match(ev)
			"cutscene":
				await _demo_cutscene(ev)
			"simultaneous":
				await _demo_simultaneous(ev)

		if i < _events.size() - 1:
			_log("[color=gray]  Waiting 0.8s between events...[/color]")
			await get_tree().create_timer(0.4).timeout

	_log("")
	_log("[color=cyan]===== TOURNAMENT COMPLETE =====[/color]")
	_log("EventBus.scene_script_finished -> 'tournament_complete'")
	_running = false
	_update_button_states()


func _demo_match(ev: Dictionary) -> void:
	_log("[color=green]MATCH[/color] vs %s" % ev.opponent)
	_log("  1. _configure_board(config)")
	_log("     - Board size: %dx%d" % [ev.board_size, ev.board_size])
	_log("     - AI difficulty: %.1f" % ev.difficulty)
	_log("     - Opponent style: %s" % ev.style)
	await get_tree().create_timer(0.15).timeout
	_log("  2. Load reactions script (if any)")
	_log("  3. Enable pre_move_hook")
	_log("  4. Execute intro cutscene (if any)")
	await get_tree().create_timer(0.15).timeout
	_log("  5. Await EventBus.match_ended")

	var outcomes: Array[String] = ["win", "lose", "draw"]
	var result: String = outcomes[randi() % outcomes.size()]
	_log("  6. Result: [color=yellow]%s[/color]" % result)
	_log("  7. trigger_reaction('%s')" % _result_to_reaction(result))
	_log("  8. GameState.record_match('%s', '%s')" % [ev.opponent, result])
	await get_tree().create_timer(0.1).timeout


func _demo_cutscene(ev: Dictionary) -> void:
	_log("[color=magenta]CUTSCENE[/color]: %s" % ev.script)
	_log("  1. stage.clear_stage()")
	_log("  2. SceneParser.parse_file('%s')" % ev.script)
	_log("  3. runner.execute(data)")
	_log("  4. Await completion")
	await get_tree().create_timer(0.2).timeout


func _demo_simultaneous(ev: Dictionary) -> void:
	var opps: Array = ev.opponents
	_log("[color=orange]SIMULTANEOUS[/color]: %s" % str(opps))
	_log("  turns_per_visit: %d" % ev.turns_per_visit)
	await get_tree().create_timer(0.1).timeout

	_log("  1. Run intros for each opponent:")
	for opp in opps:
		_log("     - Configure board for %s, run intro, save state" % str(opp))
	await get_tree().create_timer(0.1).timeout

	_log("  2. Preload reactions per opponent")
	_log("  3. Set board: external_input_control=true, auto_ai=false")
	_log("  4. Round-robin loop:")

	var round_count: int = 2
	for r in range(round_count):
		for opp in opps:
			_log("     [Round %d] Rotate to %s" % [r + 1, str(opp)])
			_log("       - sim_board_rotate signal")
			_log("       - Player gets %d turn(s)" % ev.turns_per_visit)
			_log("       - AI responds on next visit")
			await get_tree().create_timer(0.05).timeout

	var results: Array[String] = ["win", "lose"]
	for j in range(opps.size()):
		var res: String = results[j % results.size()]
		_log("  Result vs %s: [color=yellow]%s[/color]" % [str(opps[j]), res])

	_log("  5. Restore normal board mode")
	await get_tree().create_timer(0.1).timeout


func _result_to_reaction(result: String) -> String:
	match result:
		"win": return "player_wins"
		"lose": return "opponent_wins"
		"draw": return "draw"
	return "unknown"


func _update_button_states() -> void:
	demo_btn.disabled = _running
	add_match_btn.disabled = _running
	add_cutscene_btn.disabled = _running
	add_sim_btn.disabled = _running
	clear_events_btn.disabled = _running


# ---- Info panel ----

func _update_info() -> void:
	var text := ""
	text += "[color=white][b]Match Orchestrator[/b][/color]\n"
	text += "Sequences tournament events and manages board/stage transitions.\n\n"

	text += "[color=yellow][b]MatchConfig Properties[/b][/color]\n"
	text += "[color=gray]"
	text += "  match_id: String\n"
	text += "  opponent_id: String\n"
	text += "  ai_difficulty: float (0.0 - 1.0)\n"
	text += "  game_rules_preset: String (deprecated)\n"
	text += "  intro_script: String (.dscn path)\n"
	text += "  reactions_script: String (.dscn path)\n"
	text += "  player_style: String\n"
	text += "  opponent_style: String\n"
	text += "  turns_per_visit: int (simultaneous)\n"
	text += "  board_config: Resource (BoardConfig)\n"
	text += "[/color]\n"

	text += "[color=yellow][b]Event Types[/b][/color]\n"
	text += "[color=green]  match[/color] — Single match vs opponent\n"
	text += "[color=magenta]  cutscene[/color] — .dscn script execution\n"
	text += "[color=orange]  simultaneous[/color] — Round-robin multi-match\n\n"

	text += "[color=yellow][b]API[/b][/color]\n"
	text += "[color=gray]"
	text += "  setup(runner, board, stage, project_board_config)\n"
	text += "  add_match(config: MatchConfig)\n"
	text += "  add_cutscene(script_path: String)\n"
	text += "  add_simultaneous(configs: Array)\n"
	text += "  start() -> awaitable\n"
	text += "  get_current_index() -> int\n"
	text += "  get_event_count() -> int\n"
	text += "[/color]\n"

	text += "[color=yellow][b]Signals Used (EventBus)[/b][/color]\n"
	text += "[color=gray]"
	text += "  match_ended(result)\n"
	text += "  turn_changed(whose_turn)\n"
	text += "  before_ai_move()\n"
	text += "  pre_move_complete()\n"
	text += "  sim_board_rotate(opp_id, idx, total)\n"
	text += "  scene_script_finished(id)\n"
	text += "[/color]\n"

	text += "[color=yellow][b]Dependencies[/b][/color]\n"
	text += "[color=gray]"
	text += "  Board (visual + logic)\n"
	text += "  CinematicStage\n"
	text += "  DialogueBox\n"
	text += "  SceneRunner / SceneParser\n"
	text += "  GameState (autoload)\n"
	text += "  EventBus (autoload)\n"
	text += "[/color]"

	info_label.text = text


# ---- UI construction ----

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# -- LEFT: Controls --
	_build_left_panel(root)

	# -- CENTER: Info --
	_build_center_panel(root)

	# -- RIGHT: Log --
	_build_right_panel(root)


func _build_left_panel(root: HBoxContainer) -> void:
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 0.28
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(left_scroll)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 5)
	left_scroll.add_child(left)

	var back := Button.new()
	back.text = "< Dev Menu (Esc)"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://systems/dev_menu.tscn"))
	left.add_child(back)

	_lbl(left, "MATCH SYSTEM", 16, Color(0.8, 0.8, 0.2))
	left.add_child(HSeparator.new())

	# -- Match config --
	_lbl(left, "Match Config", 13, Color(0.6, 0.6, 0.75))

	# Opponent
	var opp_row := HBoxContainer.new()
	left.add_child(opp_row)
	_lbl(opp_row, "Opponent:", 12, Color(0.55, 0.55, 0.65))
	opponent_option = OptionButton.new()
	opponent_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opponent_option.add_theme_font_size_override("font_size", 12)
	for opp in OPPONENTS:
		opponent_option.add_item(opp)
	opp_row.add_child(opponent_option)

	# Difficulty
	var diff_row := HBoxContainer.new()
	left.add_child(diff_row)
	_lbl(diff_row, "Difficulty:", 12, Color(0.55, 0.55, 0.65))
	difficulty_slider = HSlider.new()
	difficulty_slider.min_value = 0.0
	difficulty_slider.max_value = 1.0
	difficulty_slider.step = 0.1
	difficulty_slider.value = 0.5
	difficulty_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_slider.custom_minimum_size = Vector2(80, 0)
	difficulty_slider.value_changed.connect(func(val: float) -> void: difficulty_value.text = "%.1f" % val)
	diff_row.add_child(difficulty_slider)
	difficulty_value = Label.new()
	difficulty_value.text = "0.5"
	difficulty_value.add_theme_font_size_override("font_size", 12)
	difficulty_value.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	diff_row.add_child(difficulty_value)

	# Board size
	var size_row := HBoxContainer.new()
	left.add_child(size_row)
	_lbl(size_row, "Board:", 12, Color(0.55, 0.55, 0.65))
	board_size_option = OptionButton.new()
	board_size_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_size_option.add_theme_font_size_override("font_size", 12)
	for s in BOARD_SIZES:
		board_size_option.add_item("%dx%d" % [s, s])
	size_row.add_child(board_size_option)

	# Style
	var style_row := HBoxContainer.new()
	left.add_child(style_row)
	_lbl(style_row, "Style:", 12, Color(0.55, 0.55, 0.65))
	style_option = OptionButton.new()
	style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_option.add_theme_font_size_override("font_size", 12)
	for s in STYLES:
		style_option.add_item(s)
	style_row.add_child(style_option)

	# Turns per visit
	var turns_row := HBoxContainer.new()
	left.add_child(turns_row)
	_lbl(turns_row, "Turns/visit:", 12, Color(0.55, 0.55, 0.65))
	turns_spin = SpinBox.new()
	turns_spin.min_value = 1
	turns_spin.max_value = 5
	turns_spin.value = 1
	turns_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turns_spin.add_theme_font_size_override("font_size", 12)
	turns_row.add_child(turns_spin)

	left.add_child(HSeparator.new())

	# -- Add event buttons --
	_lbl(left, "Add Events", 13, Color(0.6, 0.6, 0.75))

	add_match_btn = Button.new()
	add_match_btn.text = "+ Match"
	add_match_btn.pressed.connect(_add_match_event)
	_style_btn(add_match_btn, Color(0.2, 0.5, 0.2))
	left.add_child(add_match_btn)

	add_cutscene_btn = Button.new()
	add_cutscene_btn.text = "+ Cutscene"
	add_cutscene_btn.pressed.connect(_add_cutscene_event)
	_style_btn(add_cutscene_btn, Color(0.4, 0.2, 0.5))
	left.add_child(add_cutscene_btn)

	add_sim_btn = Button.new()
	add_sim_btn.text = "+ Simultaneous"
	add_sim_btn.pressed.connect(_add_simultaneous_event)
	_style_btn(add_sim_btn, Color(0.5, 0.4, 0.15))
	left.add_child(add_sim_btn)

	left.add_child(HSeparator.new())

	# -- Event queue --
	_lbl(left, "Event Queue", 13, Color(0.6, 0.6, 0.75))
	event_list = ItemList.new()
	event_list.custom_minimum_size = Vector2(0, 120)
	event_list.add_theme_font_size_override("font_size", 11)
	event_list.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	left.add_child(event_list)

	clear_events_btn = Button.new()
	clear_events_btn.text = "Clear Queue"
	clear_events_btn.pressed.connect(_clear_events)
	_style_btn(clear_events_btn, Color(0.5, 0.15, 0.15))
	left.add_child(clear_events_btn)

	left.add_child(HSeparator.new())

	# -- Run demo --
	demo_btn = Button.new()
	demo_btn.text = "Run Demo Sequence"
	demo_btn.pressed.connect(_run_demo_sequence)
	_style_btn(demo_btn, Color(0.6, 0.5, 0.1))
	left.add_child(demo_btn)

	# Status
	status_label = Label.new()
	status_label.text = "Estado: Idle"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	left.add_child(status_label)


func _build_center_panel(root: HBoxContainer) -> void:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 0.42
	root.add_child(center)

	_lbl(center, "System Info", 14, Color(0.7, 0.7, 0.8))

	var info_panel := PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	info_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(info_panel)

	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.scroll_active = true
	info_label.add_theme_font_size_override("normal_font_size", 12)
	info_label.add_theme_color_override("default_color", Color(0.65, 0.65, 0.7))
	info_panel.add_child(info_label)


func _build_right_panel(root: HBoxContainer) -> void:
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.3
	root.add_child(right_col)

	_lbl(right_col, "Event Log", 14, Color(0.7, 0.7, 0.8))
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 11)
	log_label.add_theme_color_override("default_color", Color(0.65, 0.65, 0.7))
	right_col.add_child(log_label)

	var clear_log_btn := Button.new()
	clear_log_btn.text = "Clear Log"
	clear_log_btn.pressed.connect(func() -> void:
		log_lines.clear()
		log_label.text = ""
	)
	_style_btn(clear_log_btn, Color(0.3, 0.3, 0.4))
	right_col.add_child(clear_log_btn)


# ---- Helpers ----

func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 200:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
	await get_tree().process_frame
	log_label.scroll_to_line(log_label.get_line_count() - 1)


func _lbl(parent: Control, text: String, sz: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)


func _style_btn(btn: Button, color: Color) -> void:
	btn.custom_minimum_size = Vector2(0, 32)
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = color
	hover.set_corner_radius_all(4)
	hover.content_margin_left = 8
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 13)
