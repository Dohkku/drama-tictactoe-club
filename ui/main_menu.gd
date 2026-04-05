extends Control

## Main Menu: Public-facing entry point for Drama Tic Tac Toe Club.

# Button data: [text, scene_path_or_action]
const MENU_ITEMS := [
	["Jugar Demo", "res://main.tscn"],
	["Editor", "res://editor/graph/graph_editor_main.tscn"],
	["Sandbox", "res://systems/dev_menu.tscn"],
	["Créditos", ""],  # empty = special action
]

var _buttons: Array[Button] = []
var _credits_dimmer: ColorRect
var _credits_panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label


func _ready() -> void:
	_build_ui()
	_animate_entrance()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Subtle gradient overlay (darker at top, lighter at bottom-center)
	var gradient_rect := ColorRect.new()
	gradient_rect.color = Color(0.12, 0.08, 0.2, 0.3)
	gradient_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(gradient_rect)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	center.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "Drama Tic Tac Toe Club"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 52)
	_title_label.add_theme_color_override("font_color", Color(0.92, 0.85, 1.0))
	vbox.add_child(_title_label)

	# Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.text = "Cada partida cuenta una historia"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 20)
	_subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.8, 0.8))
	vbox.add_child(_subtitle_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	# Button container
	var btn_box := VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 14)
	btn_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_box.custom_minimum_size.x = 300
	vbox.add_child(btn_box)

	# Build menu buttons
	for item in MENU_ITEMS:
		var btn := _create_menu_button(item[0])
		var scene_path: String = item[1]

		if scene_path != "":
			# Check if scene exists
			var exists := ResourceLoader.exists(scene_path)
			btn.disabled = not exists
			if exists:
				btn.pressed.connect(func(): get_tree().change_scene_to_file(scene_path))
			else:
				btn.tooltip_text = "Escena no encontrada: %s" % scene_path
		else:
			# Credits button
			btn.pressed.connect(_show_credits)

		_buttons.append(btn)
		btn_box.add_child(btn)

	# Version label (bottom right)
	var version := Label.new()
	version.text = "v0.1 — Pre-Alpha"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.add_theme_font_size_override("font_size", 13)
	version.add_theme_color_override("font_color", Color(0.4, 0.35, 0.5, 0.5))
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -160.0
	version.offset_top = -30.0
	add_child(version)

	# Credits overlay (hidden)
	_build_credits_overlay()


func _create_menu_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(300, 0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.6, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.35, 0.5, 0.5))

	# Normal style
	var style_n := StyleBoxFlat.new()
	style_n.bg_color = Color(0.15, 0.16, 0.25)
	style_n.border_color = Color(0.35, 0.25, 0.65, 0.6)
	style_n.set_border_width_all(2)
	style_n.set_corner_radius_all(12)
	style_n.content_margin_left = 30.0
	style_n.content_margin_right = 30.0
	style_n.content_margin_top = 14.0
	style_n.content_margin_bottom = 14.0
	btn.add_theme_stylebox_override("normal", style_n)

	# Hover style
	var style_h := StyleBoxFlat.new()
	style_h.bg_color = Color(0.22, 0.18, 0.38)
	style_h.border_color = Color(0.5, 0.35, 0.85, 0.9)
	style_h.set_border_width_all(2)
	style_h.set_corner_radius_all(12)
	style_h.content_margin_left = 30.0
	style_h.content_margin_right = 30.0
	style_h.content_margin_top = 14.0
	style_h.content_margin_bottom = 14.0
	btn.add_theme_stylebox_override("hover", style_h)

	# Pressed style
	var style_p := StyleBoxFlat.new()
	style_p.bg_color = Color(0.25, 0.2, 0.45)
	style_p.border_color = Color(0.6, 0.4, 1.0)
	style_p.set_border_width_all(2)
	style_p.set_corner_radius_all(12)
	style_p.content_margin_left = 30.0
	style_p.content_margin_right = 30.0
	style_p.content_margin_top = 14.0
	style_p.content_margin_bottom = 14.0
	btn.add_theme_stylebox_override("pressed", style_p)

	# Disabled style
	var style_d := StyleBoxFlat.new()
	style_d.bg_color = Color(0.1, 0.1, 0.15, 0.6)
	style_d.border_color = Color(0.2, 0.2, 0.3, 0.3)
	style_d.set_border_width_all(2)
	style_d.set_corner_radius_all(12)
	style_d.content_margin_left = 30.0
	style_d.content_margin_right = 30.0
	style_d.content_margin_top = 14.0
	style_d.content_margin_bottom = 14.0
	btn.add_theme_stylebox_override("disabled", style_d)

	# Hover scale effect
	btn.mouse_entered.connect(func():
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15)
	)
	btn.mouse_exited.connect(func():
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.15)
	)

	# Pivot at center for scale
	btn.pivot_offset = btn.custom_minimum_size / 2.0

	return btn


func _build_credits_overlay() -> void:
	# Dimmer
	_credits_dimmer = ColorRect.new()
	_credits_dimmer.color = Color(0, 0, 0, 0.7)
	_credits_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_dimmer.visible = false
	add_child(_credits_dimmer)

	# Panel
	_credits_panel = PanelContainer.new()
	_credits_panel.set_anchors_preset(Control.PRESET_CENTER)
	_credits_panel.offset_left = -280.0
	_credits_panel.offset_top = -180.0
	_credits_panel.offset_right = 280.0
	_credits_panel.offset_bottom = 180.0
	_credits_panel.visible = false

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.16, 0.95)
	panel_style.border_color = Color(0.35, 0.25, 0.65, 0.7)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 40.0
	panel_style.content_margin_right = 40.0
	panel_style.content_margin_top = 30.0
	panel_style.content_margin_bottom = 30.0
	_credits_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_credits_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	_credits_panel.add_child(vbox)

	# Credits title
	var credits_title := Label.new()
	credits_title.text = "Créditos"
	credits_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_title.add_theme_font_size_override("font_size", 28)
	credits_title.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	vbox.add_child(credits_title)

	# Credits lines
	var lines := [
		"Hecho con Godot 4",
		"",
		"Concepto: Tic-tac-toe como vehículo narrativo",
		"",
		"Cada partida cuenta una historia.",
		"Cada movimiento tiene drama.",
	]
	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.85))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Cerrar"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.custom_minimum_size = Vector2(160, 0)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0))
	close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 1.0))

	var close_style_n := StyleBoxFlat.new()
	close_style_n.bg_color = Color(0.15, 0.16, 0.25)
	close_style_n.border_color = Color(0.35, 0.25, 0.65, 0.6)
	close_style_n.set_border_width_all(2)
	close_style_n.set_corner_radius_all(12)
	close_style_n.content_margin_left = 20.0
	close_style_n.content_margin_right = 20.0
	close_style_n.content_margin_top = 10.0
	close_style_n.content_margin_bottom = 10.0
	close_btn.add_theme_stylebox_override("normal", close_style_n)

	var close_style_h := StyleBoxFlat.new()
	close_style_h.bg_color = Color(0.22, 0.18, 0.38)
	close_style_h.border_color = Color(0.5, 0.35, 0.85, 0.9)
	close_style_h.set_border_width_all(2)
	close_style_h.set_corner_radius_all(12)
	close_style_h.content_margin_left = 20.0
	close_style_h.content_margin_right = 20.0
	close_style_h.content_margin_top = 10.0
	close_style_h.content_margin_bottom = 10.0
	close_btn.add_theme_stylebox_override("hover", close_style_h)

	close_btn.pressed.connect(_hide_credits)
	vbox.add_child(close_btn)


# ---------------------------------------------------------------------------
# Entrance animations
# ---------------------------------------------------------------------------

func _animate_entrance() -> void:
	# Hide everything initially
	_title_label.modulate.a = 0.0
	_title_label.position.y -= 60.0
	_subtitle_label.modulate.a = 0.0
	for btn in _buttons:
		btn.modulate.a = 0.0

	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Title slides down and fades in
	tween.tween_property(_title_label, "position:y", _title_label.position.y + 60.0, 0.7)
	tween.parallel().tween_property(_title_label, "modulate:a", 1.0, 0.5)

	# Subtitle fades in
	tween.tween_property(_subtitle_label, "modulate:a", 1.0, 0.4)

	# Buttons fade in sequentially
	for btn in _buttons:
		tween.tween_property(btn, "modulate:a", 1.0, 0.3)


# ---------------------------------------------------------------------------
# Credits
# ---------------------------------------------------------------------------

func _show_credits() -> void:
	_credits_dimmer.visible = true
	_credits_panel.visible = true
	_credits_panel.modulate.a = 0.0
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_credits_panel, "modulate:a", 1.0, 0.3)


func _hide_credits() -> void:
	var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_credits_panel, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		_credits_dimmer.visible = false
		_credits_panel.visible = false
	)
