extends Control

const MatchConfigScript = preload("res://match_system/match_config.gd")
const TournamentEventScript = preload("res://data/tournament_event.gd")

@onready var back_button: Button = %BackButton
@onready var project_name_label: Label = %ProjectNameLabel
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var tab_container: TabContainer = %TabContainer
@onready var load_dialog: FileDialog = %LoadDialog
@onready var character_editor: HSplitContainer = %CharacterEditor
@onready var tournament_editor = %TournamentEditor
@onready var scene_editor = %SceneEditor

var current_project: ProjectData = null
const SAVE_PATH := "user://current_project.tres"


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	load_dialog.file_selected.connect(_on_load_file_selected)

	# Initialize with a new project
	current_project = ProjectData.new()
	_update_title()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


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
	if loaded is ProjectData:
		current_project = loaded
		_apply_data()
		_update_title()
		print("[Editor] Proyecto cargado: ", path)
	else:
		push_error("[Editor] El archivo no es un ProjectData valido")


func _collect_data() -> void:
	if current_project == null:
		current_project = ProjectData.new()

	# Collect characters
	if character_editor:
		var chars := character_editor.get_characters()
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


func _apply_data() -> void:
	if current_project == null:
		return

	# Apply characters
	if character_editor:
		character_editor.set_characters(current_project.characters)

	# Apply tournament events
	if tournament_editor:
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
			var mc = MatchConfigScript.new()
			mc.match_id = data.get("opponent_id", "match")
			mc.opponent_id = data.get("opponent_id", "")
			mc.ai_difficulty = data.get("ai_difficulty", 0.3)
			mc.game_rules_preset = data.get("game_rules_preset", "standard")
			mc.intro_script = data.get("intro_script", "")
			mc.reactions_script = data.get("reactions_script", "")
			mc.player_style = data.get("player_style", "slam")
			mc.opponent_style = data.get("opponent_style", "gentle")
			te.match_config = mc
		"simultaneous":
			te.event_name = "Simultánea"
			var matches: Array = data.get("matches", [])
			for m in matches:
				var mc = MatchConfigScript.new()
				mc.match_id = "sim_%s" % m.get("opponent_id", "")
				mc.opponent_id = m.get("opponent_id", "")
				mc.ai_difficulty = m.get("ai_difficulty", 0.3)
				mc.game_rules_preset = m.get("game_rules_preset", "standard")
				mc.intro_script = m.get("intro_script", "")
				mc.reactions_script = m.get("reactions_script", "")
				mc.player_style = m.get("player_style", "slam")
				mc.opponent_style = m.get("opponent_style", "gentle")
				te.simultaneous_configs.append(mc)
	return te


func _tournament_event_to_dict(te: Resource) -> Dictionary:
	match te.event_type:
		"cutscene":
			return {"type": "cutscene", "data": {"script_path": te.cutscene_script_path}}
		"match":
			var mc = te.match_config
			if mc == null:
				return {"type": "match", "data": {}}
			return {"type": "match", "data": {
				"opponent_id": mc.opponent_id,
				"ai_difficulty": mc.ai_difficulty,
				"game_rules_preset": mc.game_rules_preset,
				"intro_script": mc.intro_script,
				"reactions_script": mc.reactions_script,
				"player_style": mc.player_style,
				"opponent_style": mc.opponent_style,
			}}
		"simultaneous":
			var matches: Array = []
			for mc in te.simultaneous_configs:
				matches.append({
					"opponent_id": mc.opponent_id,
					"ai_difficulty": mc.ai_difficulty,
					"game_rules_preset": mc.game_rules_preset,
					"intro_script": mc.intro_script,
					"reactions_script": mc.reactions_script,
					"player_style": mc.player_style,
					"opponent_style": mc.opponent_style,
				})
			return {"type": "simultaneous", "data": {"matches": matches}}
	return {}
