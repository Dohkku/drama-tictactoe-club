extends Control

## Dev Menu: Launch each system's test scene independently.

const SYSTEMS := [
	{"name": "Board Logic", "scene": "res://systems/board_logic/test_scene.tscn", "color": Color(0.2, 0.6, 0.3), "desc": "Reglas, IA, lógica pura"},
	{"name": "Cinematic Stage", "scene": "res://systems/cinematic/cinematic_sandbox.tscn", "color": Color(0.6, 0.3, 0.9), "desc": "Personajes, cámara, diálogos"},
	{"name": "Layout Manager", "scene": "res://systems/layout/layout_sandbox.tscn", "color": Color(0.9, 0.6, 0.2), "desc": "Paneles, transiciones"},
	{"name": "Board Visuals", "scene": "res://systems/board_visuals/visual_sandbox.tscn", "color": Color(0.2, 0.5, 0.9), "desc": "Tablero visual, fichas, animaciones"},
	{"name": "Scene Runner", "scene": "res://systems/scene_runner/scene_runner_sandbox.tscn", "color": Color(0.9, 0.3, 0.5), "desc": "Parser DSL, ejecución de scripts"},
	{"name": "Match System", "scene": "res://systems/match/match_sandbox.tscn", "color": Color(0.8, 0.8, 0.2), "desc": "Torneos, partidas, orquestación"},
]


func _ready() -> void:
	_build_ui()


func _launch_project(resource_path: String) -> void:
	var project = ResourceLoader.load(resource_path)
	if project:
		ResourceSaver.save(project, "user://current_project.tres")
		get_tree().change_scene_to_file("res://main.tscn")
	else:
		push_error("DevMenu: can't load %s" % resource_path)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 600
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "SYSTEMS DEV MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Testea cada sistema por separado"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	for sys in SYSTEMS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52)

		var exists := ResourceLoader.exists(sys.scene)
		if exists:
			btn.text = "  %s  —  %s" % [sys.name, sys.desc]
		else:
			btn.text = "  %s  —  (pendiente)" % sys.name

		var style_n := StyleBoxFlat.new()
		style_n.bg_color = sys.color.darkened(0.5) if exists else Color(0.15, 0.15, 0.2)
		style_n.set_corner_radius_all(6)
		style_n.content_margin_left = 16
		btn.add_theme_stylebox_override("normal", style_n)

		var style_h := StyleBoxFlat.new()
		style_h.bg_color = sys.color.darkened(0.3) if exists else Color(0.2, 0.2, 0.25)
		style_h.set_corner_radius_all(6)
		style_h.content_margin_left = 16
		btn.add_theme_stylebox_override("hover", style_h)

		var style_p := StyleBoxFlat.new()
		style_p.bg_color = sys.color if exists else Color(0.25, 0.25, 0.3)
		style_p.set_corner_radius_all(6)
		style_p.content_margin_left = 16
		btn.add_theme_stylebox_override("pressed", style_p)

		btn.add_theme_color_override("font_color", Color.WHITE if exists else Color(0.4, 0.4, 0.5))
		btn.add_theme_font_size_override("font_size", 16)
		btn.disabled = not exists

		var scene_path: String = sys.scene
		btn.pressed.connect(func(): get_tree().change_scene_to_file(scene_path))
		vbox.add_child(btn)

	vbox.add_child(HSeparator.new())

	# Demo Story button — 5 chapters, full narrative
	var story_btn := Button.new()
	story_btn.custom_minimum_size = Vector2(0, 58)
	story_btn.text = "  ▶  HISTORIA DEMO  —  5 capitulos, narrativa completa"
	story_btn.add_theme_font_size_override("font_size", 17)
	story_btn.add_theme_color_override("font_color", Color.WHITE)
	var story_style := StyleBoxFlat.new()
	story_style.bg_color = Color(0.6, 0.2, 0.1)
	story_style.set_corner_radius_all(8)
	story_style.content_margin_left = 16
	story_btn.add_theme_stylebox_override("normal", story_style)
	var story_hover := StyleBoxFlat.new()
	story_hover.bg_color = Color(0.8, 0.3, 0.15)
	story_hover.set_corner_radius_all(8)
	story_hover.content_margin_left = 16
	story_btn.add_theme_stylebox_override("hover", story_hover)
	story_btn.pressed.connect(func():
		# Load demo story directly, bypassing user save
		_launch_project("res://data/resources/demo_story_project.tres"))
	vbox.add_child(story_btn)

	# Custom project button (from editor saves)
	var custom_btn := Button.new()
	custom_btn.custom_minimum_size = Vector2(0, 40)
	custom_btn.text = "  ▶  Proyecto guardado (del editor)"
	custom_btn.add_theme_font_size_override("font_size", 13)
	custom_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	var custom_style := StyleBoxFlat.new()
	custom_style.bg_color = Color(0.3, 0.15, 0.1)
	custom_style.set_corner_radius_all(6)
	custom_style.content_margin_left = 16
	custom_btn.add_theme_stylebox_override("normal", custom_style)
	var custom_hover := StyleBoxFlat.new()
	custom_hover.bg_color = Color(0.4, 0.2, 0.12)
	custom_hover.set_corner_radius_all(6)
	custom_hover.content_margin_left = 16
	custom_btn.add_theme_stylebox_override("hover", custom_hover)
	var has_save: bool = ResourceLoader.exists("user://current_project.tres")
	custom_btn.disabled = not has_save
	custom_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	vbox.add_child(custom_btn)

	# Editor 2.0 (Canvas) — PRIMARY editor button
	var canvas_btn := Button.new()
	canvas_btn.custom_minimum_size = Vector2(0, 58)
	canvas_btn.text = "  ◈  EDITOR 2.0  —  Canvas visual basado en nodos"
	canvas_btn.add_theme_font_size_override("font_size", 17)
	canvas_btn.add_theme_color_override("font_color", Color.WHITE)
	var canvas_style := StyleBoxFlat.new()
	canvas_style.bg_color = Color(0.45, 0.25, 0.7)
	canvas_style.set_corner_radius_all(8)
	canvas_style.content_margin_left = 16
	canvas_btn.add_theme_stylebox_override("normal", canvas_style)
	var canvas_hover := StyleBoxFlat.new()
	canvas_hover.bg_color = Color(0.55, 0.35, 0.8)
	canvas_hover.set_corner_radius_all(8)
	canvas_hover.content_margin_left = 16
	canvas_btn.add_theme_stylebox_override("hover", canvas_hover)
	var canvas_exists: bool = ResourceLoader.exists("res://editor/graph/graph_editor_main.tscn")
	canvas_btn.disabled = not canvas_exists
	canvas_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://editor/graph/graph_editor_main.tscn"))
	vbox.add_child(canvas_btn)

	# Editor legacy (secondary, smaller)
	var editor_btn := Button.new()
	editor_btn.custom_minimum_size = Vector2(0, 40)
	editor_btn.text = "  ✎  Editor clasico (tabs)"
	editor_btn.add_theme_font_size_override("font_size", 13)
	editor_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	var editor_style := StyleBoxFlat.new()
	editor_style.bg_color = Color(0.15, 0.17, 0.22)
	editor_style.set_corner_radius_all(6)
	editor_style.content_margin_left = 16
	editor_btn.add_theme_stylebox_override("normal", editor_style)
	var editor_hover := StyleBoxFlat.new()
	editor_hover.bg_color = Color(0.2, 0.25, 0.3)
	editor_hover.set_corner_radius_all(6)
	editor_hover.content_margin_left = 16
	editor_btn.add_theme_stylebox_override("hover", editor_hover)
	var editor_exists: bool = ResourceLoader.exists("res://editor/editor_main.tscn")
	editor_btn.disabled = not editor_exists
	editor_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://editor/editor_main.tscn"))
	vbox.add_child(editor_btn)
