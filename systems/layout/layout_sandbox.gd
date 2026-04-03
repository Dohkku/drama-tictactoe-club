extends Control

## Interactive sandbox for the Layout system.
## Tests: layout modes (fullscreen, split, board_only), animated transitions,
## separator visibility, panel highlights.

const LayoutManagerScript = preload("res://systems/layout/layout_manager.gd")
const PanelHighlightScript = preload("res://systems/layout/panel_highlight.gd")
const PanelSeparatorScript = preload("res://systems/layout/panel_separator.gd")

var layout: RefCounted = null

# Panels managed by the layout manager
var cinematic_panel: PanelContainer = null
var board_panel: PanelContainer = null
var separator: Control = null

# Highlights
var cinematic_highlight: Control = null
var board_highlight: Control = null

# UI controls
var mode_label: Label = null
var duration_slider: HSlider = null
var duration_value_label: Label = null
var separator_check: CheckBox = null
var highlight_check: CheckBox = null
var layout_area: Control = null
var log_label: RichTextLabel = null
var log_lines: Array[String] = []


func _ready() -> void:
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://systems/dev_menu.tscn")


func _build_ui() -> void:
	# Background
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
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 0.25
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

	_lbl(left, "LAYOUT MANAGER", 16, Color(0.9, 0.6, 0.2))
	left.add_child(HSeparator.new())

	# Current mode display
	_lbl(left, "Modo actual", 13, Color(0.6, 0.6, 0.75))
	mode_label = Label.new()
	mode_label.text = "split"
	mode_label.add_theme_font_size_override("font_size", 18)
	mode_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	left.add_child(mode_label)

	left.add_child(HSeparator.new())

	# Mode buttons
	_lbl(left, "Transiciones", 13, Color(0.6, 0.6, 0.75))

	var fullscreen_btn := Button.new()
	fullscreen_btn.text = "Fullscreen (Cinematic)"
	fullscreen_btn.pressed.connect(func() -> void: _transition_to("fullscreen"))
	_style_btn(fullscreen_btn, Color(0.6, 0.3, 0.6))
	left.add_child(fullscreen_btn)

	var split_btn := Button.new()
	split_btn.text = "Split (Both)"
	split_btn.pressed.connect(func() -> void: _transition_to("split"))
	_style_btn(split_btn, Color(0.3, 0.5, 0.6))
	left.add_child(split_btn)

	var board_only_btn := Button.new()
	board_only_btn.text = "Board Only"
	board_only_btn.pressed.connect(func() -> void: _transition_to("board_only"))
	_style_btn(board_only_btn, Color(0.2, 0.5, 0.8))
	left.add_child(board_only_btn)

	left.add_child(HSeparator.new())

	# Instant mode buttons
	_lbl(left, "Instant (sin animacion)", 13, Color(0.6, 0.6, 0.75))

	var instant_row := HBoxContainer.new()
	instant_row.add_theme_constant_override("separation", 4)
	left.add_child(instant_row)

	for m: String in ["fullscreen", "split", "board_only"]:
		var btn := Button.new()
		btn.text = m
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mode_str: String = m
		btn.pressed.connect(func() -> void: _set_instant(mode_str))
		_style_btn(btn, Color(0.35, 0.35, 0.4))
		instant_row.add_child(btn)

	left.add_child(HSeparator.new())

	# Split ratio slider
	_lbl(left, "Ratio split (cinematic)", 13, Color(0.6, 0.6, 0.75))
	var ratio_row := HBoxContainer.new()
	ratio_row.add_theme_constant_override("separation", 6)
	left.add_child(ratio_row)
	var ratio_slider := HSlider.new()
	ratio_slider.min_value = 0.2
	ratio_slider.max_value = 0.8
	ratio_slider.step = 0.05
	ratio_slider.value = 0.5
	ratio_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ratio_val_label := Label.new()
	ratio_val_label.text = "50%"
	ratio_val_label.add_theme_font_size_override("font_size", 13)
	ratio_val_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	ratio_val_label.custom_minimum_size = Vector2(40, 0)
	ratio_slider.value_changed.connect(func(val: float) -> void:
		layout.split_ratio = val
		ratio_val_label.text = "%d%%" % int(val * 100)
		if layout.get_current_mode() == "split":
			layout.set_instant("split")
	)
	ratio_row.add_child(ratio_slider)
	ratio_row.add_child(ratio_val_label)

	left.add_child(HSeparator.new())

	# Duration slider
	_lbl(left, "Duracion transicion", 13, Color(0.6, 0.6, 0.75))

	var dur_row := HBoxContainer.new()
	dur_row.add_theme_constant_override("separation", 6)
	left.add_child(dur_row)

	duration_slider = HSlider.new()
	duration_slider.min_value = 0.1
	duration_slider.max_value = 3.0
	duration_slider.step = 0.1
	duration_slider.value = 0.8
	duration_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_slider.value_changed.connect(func(val: float) -> void: duration_value_label.text = "%.1fs" % val)
	dur_row.add_child(duration_slider)

	duration_value_label = Label.new()
	duration_value_label.text = "0.8s"
	duration_value_label.add_theme_font_size_override("font_size", 13)
	duration_value_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	duration_value_label.custom_minimum_size = Vector2(40, 0)
	dur_row.add_child(duration_value_label)

	left.add_child(HSeparator.new())

	# Toggles
	_lbl(left, "Opciones", 13, Color(0.6, 0.6, 0.75))

	separator_check = CheckBox.new()
	separator_check.text = "Mostrar separador"
	separator_check.button_pressed = true
	separator_check.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	separator_check.toggled.connect(_on_separator_toggled)
	left.add_child(separator_check)

	highlight_check = CheckBox.new()
	highlight_check.text = "Panel highlights"
	highlight_check.button_pressed = false
	highlight_check.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	highlight_check.toggled.connect(_on_highlight_toggled)
	left.add_child(highlight_check)

	left.add_child(HSeparator.new())

	# Highlight controls (which panel to highlight)
	_lbl(left, "Highlight manual", 13, Color(0.6, 0.6, 0.75))

	var hl_row := HBoxContainer.new()
	hl_row.add_theme_constant_override("separation", 4)
	left.add_child(hl_row)

	var hl_cine_btn := Button.new()
	hl_cine_btn.text = "Cinematic"
	hl_cine_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl_cine_btn.pressed.connect(func() -> void:
		cinematic_highlight.set_highlighted(true)
		board_highlight.set_highlighted(false)
		_log("Highlight: cinematic")
	)
	_style_btn(hl_cine_btn, Color(0.5, 0.3, 0.5))
	hl_row.add_child(hl_cine_btn)

	var hl_board_btn := Button.new()
	hl_board_btn.text = "Board"
	hl_board_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl_board_btn.pressed.connect(func() -> void:
		cinematic_highlight.set_highlighted(false)
		board_highlight.set_highlighted(true)
		_log("Highlight: board")
	)
	_style_btn(hl_board_btn, Color(0.2, 0.4, 0.6))
	hl_row.add_child(hl_board_btn)

	var hl_none_btn := Button.new()
	hl_none_btn.text = "None"
	hl_none_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl_none_btn.pressed.connect(func() -> void:
		cinematic_highlight.set_highlighted(false)
		board_highlight.set_highlighted(false)
		_log("Highlight: none")
	)
	_style_btn(hl_none_btn, Color(0.3, 0.3, 0.35))
	hl_row.add_child(hl_none_btn)

	# -- CENTER: Layout preview --
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 0.55
	center.add_theme_constant_override("separation", 4)
	root.add_child(center)

	_lbl(center, "Vista previa", 14, Color(0.7, 0.7, 0.8))

	var preview_container := PanelContainer.new()
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.05, 0.05, 0.08)
	preview_style.set_corner_radius_all(4)
	preview_container.add_theme_stylebox_override("panel", preview_style)
	center.add_child(preview_container)

	# Layout area — plain Control, no BoxContainer (we manage positions directly)
	layout_area = Control.new()
	layout_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_container.add_child(layout_area)

	# Cinematic panel (purple-ish)
	cinematic_panel = PanelContainer.new()
	var cine_style := StyleBoxFlat.new()
	cine_style.bg_color = Color(0.18, 0.1, 0.28)
	cinematic_panel.add_theme_stylebox_override("panel", cine_style)
	layout_area.add_child(cinematic_panel)

	var cine_label := Label.new()
	cine_label.text = "CINEMATIC"
	cine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cine_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cine_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cine_label.add_theme_font_size_override("font_size", 22)
	cine_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.8, 0.6))
	cinematic_panel.add_child(cine_label)

	cinematic_highlight = Control.new()
	cinematic_highlight.set_script(PanelHighlightScript)
	cinematic_panel.add_child(cinematic_highlight)

	# Separator
	separator = Control.new()
	separator.set_script(PanelSeparatorScript)
	layout_area.add_child(separator)

	# Board panel (blue-ish)
	board_panel = PanelContainer.new()
	var board_style := StyleBoxFlat.new()
	board_style.bg_color = Color(0.1, 0.15, 0.28)
	board_panel.add_theme_stylebox_override("panel", board_style)
	layout_area.add_child(board_panel)

	var board_label := Label.new()
	board_label.text = "BOARD"
	board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_label.add_theme_font_size_override("font_size", 22)
	board_label.add_theme_color_override("font_color", Color(0.3, 0.5, 0.8, 0.6))
	board_panel.add_child(board_label)

	board_highlight = Control.new()
	board_highlight.set_script(PanelHighlightScript)
	board_panel.add_child(board_highlight)

	# -- RIGHT: Log --
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.2
	root.add_child(right_col)

	_lbl(right_col, "Eventos", 14, Color(0.7, 0.7, 0.8))
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 11)
	log_label.add_theme_color_override("default_color", Color(0.65, 0.65, 0.7))
	right_col.add_child(log_label)

	# -- Initialize LayoutManager --
	layout = LayoutManagerScript.new()
	layout.setup(layout_area, cinematic_panel, board_panel, separator)
	layout.transition_finished.connect(_on_transition_finished)
	layout.set_instant("split")
	_update_mode_label()
	_log("Layout sandbox ready — mode: split")


# -- Actions ------------------------------------------------------------------

func _transition_to(mode: String) -> void:
	if layout.is_transitioning():
		_log("[color=red]Transition in progress...[/color]")
		return
	var dur: float = duration_slider.value
	_log("Transition → %s (%.1fs)" % [mode, dur])
	layout.transition_to(mode, dur)


func _set_instant(mode: String) -> void:
	layout.set_instant(mode)
	_update_mode_label()
	_log("Instant → %s" % mode)


func _on_transition_finished(mode: String) -> void:
	_update_mode_label()
	_log("[color=green]Finished → %s[/color]" % mode)


func _on_separator_toggled(on: bool) -> void:
	layout.separator_enabled = on
	if layout.get_current_mode() == "split":
		layout.set_instant("split")
	_log("Separator: %s" % ("visible" if on else "hidden"))


func _on_highlight_toggled(on: bool) -> void:
	cinematic_highlight.set_highlighted(on)
	board_highlight.set_highlighted(on)
	_log("Highlights: %s" % ("on" if on else "off"))


func _update_mode_label() -> void:
	mode_label.text = layout.get_current_mode()


# -- Helpers -------------------------------------------------------------------

func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 80:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)


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
