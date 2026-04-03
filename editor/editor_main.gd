extends Control

const ProjectDataScript = preload("res://data/project_data.gd")
const MatchConfigScript = preload("res://match_system/match_config.gd")
const TournamentEventScript = preload("res://data/tournament_event.gd")
const BoardConfigScript = preload("res://data/board_config.gd")

@onready var back_button: Button = %BackButton
@onready var project_name_label: Label = %ProjectNameLabel
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var tab_container: TabContainer = %TabContainer
@onready var load_dialog: FileDialog = %LoadDialog
@onready var character_editor: HSplitContainer = %CharacterEditor
@onready var tournament_editor = %TournamentEditor
@onready var scene_editor = %SceneEditor
@onready var board_editor = %BoardEditor
@onready var top_bar_hbox: HBoxContainer = $Background/VBoxContainer/TopBar/HBox

var play_button: Button = null
var current_project: Resource = null
const SAVE_PATH := "user://current_project.tres"


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	load_dialog.file_selected.connect(_on_load_file_selected)
	
	if character_editor:
		character_editor.characters_changed.connect(_on_characters_changed)
	
	_setup_play_button()

	# Initialize with existing project or default
	if ResourceLoader.exists(SAVE_PATH):
		_on_load_file_selected(SAVE_PATH)
	else:
		var default_res = load("res://data/resources/default_project.tres")
		if default_res:
			current_project = default_res
			_apply_data()
	
	_update_title()


func _setup_play_button() -> void:
	play_button = Button.new()
	play_button.text = "¡JUGAR!"
	play_button.custom_minimum_size = Vector2(100, 0)
	
	# Reuse styles from save button if possible, or create a distinct "Play" style
	var style_normal = save_button.get_theme_stylebox("normal").duplicate()
	style_normal.bg_color = Color(0.2, 0.6, 0.3)
	play_button.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover = save_button.get_theme_stylebox("hover").duplicate()
	style_hover.bg_color = Color(0.3, 0.7, 0.4)
	play_button.add_theme_stylebox_override("hover", style_hover)
	
	play_button.add_theme_color_override("font_color", Color.WHITE)
	play_button.add_theme_font_size_override("font_size", 16)
	
	# Insert after spacer
	top_bar_hbox.add_child(play_button)
	top_bar_hbox.move_child(play_button, save_button.get_index())
	
	play_button.pressed.connect(_on_play_pressed)


func _on_play_pressed() -> void:
	_on_save_pressed()
	# Short delay to show the "saved" flash before switching
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://main.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_characters_changed() -> void:
	if tournament_editor and character_editor:
		tournament_editor.set_available_characters(character_editor.get_characters())


func _on_save_pressed() -> void:
	_collect_data()
	var err := ResourceSaver.save(current_project, SAVE_PATH)
	if err == OK:
		print("[Editor] Proyecto guardado en: ", SAVE_PATH)
		_flash_button(save_button, Color(0.3, 0.8, 0.3))
	else:
		push_error("[Editor] Error al guardar proyecto: %s" % error_string(err))
		_flash_button(save_button, Color(0.8, 0.3, 0.3))


func _on_load_pressed() -> void:
	load_dialog.popup_centered(Vector2i(700, 500))


func _on_load_file_selected(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("[Editor] Archivo no encontrado: %s" % path)
		return

	var loaded := ResourceLoader.load(path)
	if loaded is ProjectDataScript:
		current_project = loaded
		_apply_data()
		_update_title()
		print("[Editor] Proyecto cargado: ", path)
	else:
		push_error("[Editor] El archivo no es un ProjectData valido")


func _collect_data() -> void:
	if current_project == null:
		current_project = ProjectDataScript.new()

	# Collect characters
	if character_editor:
		var chars: Array = character_editor.get_characters()
		current_project.characters.clear()
		for ch in chars:
			current_project.characters.append(ch)

	# Collect tournament events
	if tournament_editor:
		var event_dicts: Array = tournament_editor.get_events()
		current_project.events.clear()
		for dict in event_dicts:
			var te = _dict_to_tournament_event(dict)
			if te:
				current_project.events.append(te)

	# Collect board config
	if board_editor:
		current_project.board_config = board_editor.get_config()


func _apply_data() -> void:
	if current_project == null:
		return

	# Apply characters
	if character_editor:
		character_editor.set_characters(current_project.characters)

	# Migrate: ensure board_config exists with game_rules
	if current_project.board_config == null:
		current_project.board_config = BoardConfigScript.create_default()
	else:
		current_project.board_config.get_rules()

	# Apply board config
	if board_editor:
		board_editor.set_config(current_project.board_config)

	# Apply tournament events
	if tournament_editor:
		if character_editor:
			tournament_editor.set_available_characters(character_editor.get_characters())
		
		var event_dicts: Array = []
		for i in range(current_project.events.size()):
			var te = current_project.events[i]
			var dict = _tournament_event_to_dict(te)
			if dict:
				event_dicts.append(dict)
		tournament_editor.load_events(event_dicts)


func _update_title() -> void:
	if current_project:
		project_name_label.text = "Editor — %s" % current_project.project_name
	else:
		project_name_label.text = "Editor de Proyecto"


func _flash_button(btn: Button, color: Color) -> void:
	var orig_color := btn.get_theme_color("font_color")
	btn.add_theme_color_override("font_color", color)
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func(): btn.add_theme_color_override("font_color", orig_color))


# --- Conversion between tournament editor dicts and TournamentEvent resources ---

func _dict_to_tournament_event(dict: Dictionary) -> Resource:
	var te = TournamentEventScript.new()
	te.event_type = dict.get("type", "match")
	var data: Dictionary = dict.get("data", {})

	match te.event_type:
		"cutscene":
			te.event_name = "Cinemática"
			te.cutscene_script_path = data.get("script_path", "")
		"match":
			te.event_name = "vs %s" % data.get("opponent_id", "???")
			var mc = _dict_to_match_config(data)
			te.match_config = mc
		"simultaneous":
			te.event_name = "Simultánea"
			var matches: Array = data.get("matches", [])
			for m in matches:
				var mc = _dict_to_match_config(m)
				mc.match_id = "sim_%s" % m.get("opponent_id", "")
				te.simultaneous_configs.append(mc)
	return te


func _dict_to_match_config(data: Dictionary) -> Resource:
	var mc = MatchConfigScript.new()
	mc.match_id = data.get("opponent_id", "match")
	mc.opponent_id = data.get("opponent_id", "")
	mc.ai_difficulty = data.get("ai_difficulty", 0.3)
	mc.game_rules_preset = data.get("game_rules_preset", "standard")
	mc.intro_script = data.get("intro_script", "")
	mc.reactions_script = data.get("reactions_script", "")
	mc.player_style = data.get("player_style", "slam")
	mc.opponent_style = data.get("opponent_style", "gentle")

	# Build per-match BoardConfig from custom rules if enabled
	if data.get("custom_rules", false):
		var rules_data: Dictionary = data.get("board_rules", {})
		if not rules_data.is_empty():
			var board_cfg = BoardConfigScript.create_default()
			var rules = board_cfg.get_rules()
			rules.board_size = rules_data.get("board_size", 3)
			rules.win_length = rules_data.get("win_length", 3)
			rules.max_pieces_per_player = rules_data.get("max_pieces", -1)
			rules.overflow_mode = rules_data.get("overflow_mode", "rotate")
			rules.allow_draw = rules_data.get("allow_draw", true)
			mc.board_config = board_cfg
	return mc


func _tournament_event_to_dict(te: Resource) -> Dictionary:
	match te.event_type:
		"cutscene":
			return {"type": "cutscene", "data": {"script_path": te.cutscene_script_path}}
		"match":
			var mc = te.match_config
			if mc == null:
				return {"type": "match", "data": {}}
			return {"type": "match", "data": _match_config_to_dict(mc)}
		"simultaneous":
			var matches: Array = []
			for mc in te.simultaneous_configs:
				matches.append(_match_config_to_dict(mc))
			return {"type": "simultaneous", "data": {"matches": matches}}
	return {}


func _match_config_to_dict(mc: Resource) -> Dictionary:
	var dict := {
		"opponent_id": mc.opponent_id,
		"ai_difficulty": mc.ai_difficulty,
		"game_rules_preset": mc.game_rules_preset,
		"intro_script": mc.intro_script,
		"reactions_script": mc.reactions_script,
		"player_style": mc.player_style,
		"opponent_style": mc.opponent_style,
		"custom_rules": mc.board_config != null,
	}
	if mc.board_config != null:
		var rules = mc.board_config.get_rules()
		dict["board_rules"] = {
			"board_size": rules.board_size,
			"win_length": rules.win_length,
			"max_pieces": rules.max_pieces_per_player,
			"overflow_mode": rules.overflow_mode,
			"allow_draw": rules.allow_draw,
		}
	else:
		dict["board_rules"] = {}
	return dict
