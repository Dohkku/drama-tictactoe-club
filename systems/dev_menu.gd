extends Control

## Dev Menu: Launch each system's test scene independently.

const SYSTEMS := [
	{"name": "Board Logic", "scene": "res://systems/board_logic/test_scene.tscn", "color": Color(0.2, 0.6, 0.3), "desc": "Reglas, IA, lógica pura"},
	{"name": "Cinematic Stage", "scene": "res://systems/cinematic/cinematic_sandbox.tscn", "color": Color(0.6, 0.3, 0.9), "desc": "Personajes, cámara, diálogos"},
	{"name": "Layout Manager", "scene": "res://systems/layout/layout_sandbox.tscn", "color": Color(0.9, 0.6, 0.2), "desc": "Paneles, transiciones"},
	{"name": "Board Visuals", "scene": "res://systems/board_visuals/visual_sandbox.tscn", "color": Color(0.2, 0.5, 0.9), "desc": "Tablero visual, fichas, animaciones"},
	{"name": "Scene Runner", "scene": "res://systems/scene_runner/scene_runner_sandbox.tscn", "color": Color(0.9, 0.3, 0.5), "desc": "Parser DSL, ejecución de scripts"},
	{"name": "Match System", "scene": "res://systems/match/test_scene.tscn", "color": Color(0.8, 0.8, 0.2), "desc": "Torneos, partidas, orquestación"},
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
