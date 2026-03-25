extends SceneTree

const CharacterDataScript = preload("res://characters/character_data.gd")
const ProjectDataScript = preload("res://data/project_data.gd")
const TournamentEventScript = preload("res://data/tournament_event.gd")
const MatchConfigScript = preload("res://match_system/match_config.gd")

func _init():
	print("=== Restoring Project Data with Multimedia Support ===")
	
	# --- CHARACTERS ---
	var akira = CharacterDataScript.new()
	akira.character_id = "akira"
	akira.display_name = "Akira"
	akira.color = Color(0.9, 0.2, 0.2)
	akira.expressions = {"neutral": Color(0.9, 0.2, 0.2), "smirk": Color(0.95, 0.3, 0.15), "angry": Color(0.8, 0.1, 0.1)}
	akira.default_style = "spinning"
	ResourceSaver.save(akira, "res://characters/data/akira.tres")

	var mei = CharacterDataScript.new()
	mei.character_id = "mei"
	mei.display_name = "Mei"
	mei.color = Color(0.6, 0.3, 0.9)
	mei.expressions = {"neutral": Color(0.6, 0.3, 0.9), "analytical": Color(0.5, 0.25, 0.95)}
	mei.default_style = "gentle"
	ResourceSaver.save(mei, "res://characters/data/mei.tres")

	var player = CharacterDataScript.new()
	player.character_id = "player"
	player.display_name = "Tú"
	player.color = Color(0.2, 0.5, 1.0)
	player.expressions = {"neutral": Color(0.2, 0.5, 1.0), "determined": Color(0.1, 0.4, 1.0)}
	ResourceSaver.save(player, "res://characters/data/player.tres")

	# --- PROJECT ---
	var project = ProjectDataScript.new()
	project.project_name = "Drama Tic Tac Toe Club"
	project.characters = [akira, mei, player]
	
	# Prologue
	var e1 = TournamentEventScript.new()
	e1.event_type = "cutscene"
	e1.event_name = "Prólogo"
	e1.cutscene_script_path = "res://scene_scripts/scripts/prologue.dscn"
	e1.order_index = 0
	project.events.append(e1)
	
	# Match 1
	var e2 = TournamentEventScript.new()
	e2.event_type = "match"
	e2.event_name = "vs Akira"
	e2.order_index = 1
	var m1 = MatchConfigScript.new()
	m1.match_id = "match_01"
	m1.opponent_id = "akira"
	m1.ai_difficulty = 0.3
	m1.intro_script = "res://scene_scripts/scripts/match_01_intro.dscn"
	m1.reactions_script = "res://scene_scripts/scripts/match_01_reactions.dscn"
	e2.match_config = m1
	project.events.append(e2)

	# Save both res:// and user:// to be sure
	ResourceSaver.save(project, "res://data/resources/default_project.tres")
	ResourceSaver.save(project, "user://current_project.tres")
	
	print("=== Restore Complete! ===")
	quit()
