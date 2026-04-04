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


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -300
	vbox.offset_right = 300
	vbox.offset_top = -250
	vbox.offset_bottom = 250
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

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

	# Tech Demo button — runs the full integrated game
	var demo_btn := Button.new()
	demo_btn.custom_minimum_size = Vector2(0, 58)
	demo_btn.text = "  ▶  TECH DEMO  —  Historia completa con todos los sistemas"
	demo_btn.add_theme_font_size_override("font_size", 17)
	demo_btn.add_theme_color_override("font_color", Color.WHITE)
	var demo_style := StyleBoxFlat.new()
	demo_style.bg_color = Color(0.6, 0.2, 0.1)
	demo_style.set_corner_radius_all(8)
	demo_style.content_margin_left = 16
	demo_btn.add_theme_stylebox_override("normal", demo_style)
	var demo_hover := StyleBoxFlat.new()
	demo_hover.bg_color = Color(0.8, 0.3, 0.15)
	demo_hover.set_corner_radius_all(8)
	demo_hover.content_margin_left = 16
	demo_btn.add_theme_stylebox_override("hover", demo_hover)
	demo_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	vbox.add_child(demo_btn)

	# Editor button
	var editor_btn := Button.new()
	editor_btn.custom_minimum_size = Vector2(0, 52)
	editor_btn.text = "  ✎  EDITOR  —  Personajes, escenas, partidas, tablero"
	editor_btn.add_theme_font_size_override("font_size", 16)
	editor_btn.add_theme_color_override("font_color", Color.WHITE)
	var editor_style := StyleBoxFlat.new()
	editor_style.bg_color = Color(0.15, 0.35, 0.5)
	editor_style.set_corner_radius_all(8)
	editor_style.content_margin_left = 16
	editor_btn.add_theme_stylebox_override("normal", editor_style)
	var editor_hover := StyleBoxFlat.new()
	editor_hover.bg_color = Color(0.2, 0.45, 0.6)
	editor_hover.set_corner_radius_all(8)
	editor_hover.content_margin_left = 16
	editor_btn.add_theme_stylebox_override("hover", editor_hover)
	var editor_exists: bool = ResourceLoader.exists("res://editor/editor_main.tscn")
	editor_btn.disabled = not editor_exists
	editor_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://editor/editor_main.tscn"))
	vbox.add_child(editor_btn)

	# Editor 2.0 (Canvas) button
	var canvas_btn := Button.new()
	canvas_btn.custom_minimum_size = Vector2(0, 52)
	canvas_btn.text = "  ◈  EDITOR 2.0  —  Canvas visual basado en nodos"
	canvas_btn.add_theme_font_size_override("font_size", 16)
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
