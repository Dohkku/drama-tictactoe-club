class_name TournamentEditor
extends VBoxContainer

## Visual editor for designing tournament event sequences.
## Each event is a cutscene, a match, or a simultaneous match group.
## Designed to be placed inside a TabContainer tab.

# ─── Constants ───────────────────────────────────────────────────────────────

const STYLE_OPTIONS := ["gentle", "slam", "spinning", "dramatic", "nervous"]
const RULES_OPTIONS := ["standard", "rotating_3", "big_board"]

const COLOR_BG := Color(0.12, 0.13, 0.17)
const COLOR_CARD := Color(0.18, 0.19, 0.24)
const COLOR_CARD_HOVER := Color(0.22, 0.23, 0.30)
const COLOR_ACCENT := Color(0.4, 0.3, 0.8)
const COLOR_CUTSCENE := Color(0.2, 0.45, 0.9)
const COLOR_MATCH := Color(0.9, 0.25, 0.2)
const COLOR_SIMULTANEOUS := Color(0.65, 0.25, 0.85)
const COLOR_TEXT := Color(0.85, 0.85, 0.9)
const COLOR_TEXT_DIM := Color(0.55, 0.55, 0.65)
const COLOR_DELETE := Color(0.9, 0.3, 0.3)
const COLOR_BUTTON_BG := Color(0.25, 0.26, 0.32)
const COLOR_INPUT_BG := Color(0.14, 0.15, 0.20)

# ─── Data ────────────────────────────────────────────────────────────────────

## Array of event dictionaries:
##   {"type": "cutscene"|"match"|"simultaneous", "data": {...}}
var events: Array = []

## Maps event card node -> index in events array (rebuilt on every refresh)
var _card_index_map: Dictionary = {}

# ─── Node references ─────────────────────────────────────────────────────────

var _event_list: VBoxContainer = null
var _scroll: ScrollContainer = null
var _info_label: Label = null


# ═════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	name = "TournamentEditor"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_build_ui()
	_refresh_list()


# ═════════════════════════════════════════════════════════════════════════════
# Public API
# ═════════════════════════════════════════════════════════════════════════════

func get_events() -> Array:
	return events.duplicate(true)


func load_events(data: Array) -> void:
	events = data.duplicate(true)
	_refresh_list()


# ═════════════════════════════════════════════════════════════════════════════
# UI Construction
# ═════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Background panel
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = COLOR_BG
	add_theme_stylebox_override("panel", bg_style)

	# ── Toolbar ──────────────────────────────────────────────────────────
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)

	toolbar.add_child(_make_toolbar_button("+ Cinematica", COLOR_CUTSCENE, _on_add_cutscene))
	toolbar.add_child(_make_toolbar_button("+ Partida", COLOR_MATCH, _on_add_match))
	toolbar.add_child(_make_toolbar_button("+ Simultanea", COLOR_SIMULTANEOUS, _on_add_simultaneous))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	_info_label = Label.new()
	_info_label.text = "Arrastra para reordenar"
	_info_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toolbar.add_child(_info_label)

	# ── Scroll + Event list ──────────────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_event_list = VBoxContainer.new()
	_event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_event_list)


func _make_toolbar_button(text: String, color: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 34)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = color.darkened(0.4)
	style_normal.set_corner_radius_all(4)
	style_normal.content_margin_left = 12
	style_normal.content_margin_right = 12
	style_normal.content_margin_top = 6
	style_normal.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = color.darkened(0.2)
	style_hover.set_corner_radius_all(4)
	style_hover.content_margin_left = 12
	style_hover.content_margin_right = 12
	style_hover.content_margin_top = 6
	style_hover.content_margin_bottom = 6
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = color
	style_pressed.set_corner_radius_all(4)
	style_pressed.content_margin_left = 12
	style_pressed.content_margin_right = 12
	style_pressed.content_margin_top = 6
	style_pressed.content_margin_bottom = 6
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.pressed.connect(callback)
	return btn


# ═════════════════════════════════════════════════════════════════════════════
# Event Card Creation
# ═════════════════════════════════════════════════════════════════════════════

func _create_event_card(event_idx: int) -> PanelContainer:
	var event: Dictionary = events[event_idx]
	var event_type: String = event.get("type", "match")
	var event_data: Dictionary = event.get("data", {})

	# ── Determine type-specific visuals ──────────────────────────────────
	var type_color: Color
	var type_icon: String
	var type_label: String
	match event_type:
		"cutscene":
			type_color = COLOR_CUTSCENE
			type_icon = "C"
			type_label = "Cinematica"
		"simultaneous":
			type_color = COLOR_SIMULTANEOUS
			type_icon = "SS"
			type_label = "Simultanea"
		_:
			type_color = COLOR_MATCH
			type_icon = "VS"
			type_label = "Partida"

	# ── Card panel ───────────────────────────────────────────────────────
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_CARD
	card_style.set_corner_radius_all(6)
	card_style.border_width_left = 4
	card_style.border_color = type_color
	card_style.content_margin_left = 12
	card_style.content_margin_right = 8
	card_style.content_margin_top = 8
	card_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_style)

	# ── Main HBox ────────────────────────────────────────────────────────
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Drag handle
	var drag_handle := Label.new()
	drag_handle.text = "="
	drag_handle.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	drag_handle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drag_handle.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(drag_handle)

	# Type icon
	var icon_label := Label.new()
	icon_label.text = type_icon
	icon_label.add_theme_color_override("font_color", type_color)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.custom_minimum_size = Vector2(30, 0)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)

	# ── Content column ───────────────────────────────────────────────────
	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(content_vbox)

	# Title
	var title := Label.new()
	match event_type:
		"cutscene":
			var script_path: String = event_data.get("script_path", "")
			if script_path != "":
				title.text = "%s — %s" % [type_label, script_path.get_file()]
			else:
				title.text = type_label
		"match":
			var opp: String = event_data.get("opponent_id", "")
			if opp != "":
				title.text = "%s vs %s" % [type_label, opp.capitalize()]
			else:
				title.text = type_label
		"simultaneous":
			var matches: Array = event_data.get("matches", [])
			if matches.size() > 0:
				var names := []
				for m in matches:
					var n: String = m.get("opponent_id", "?")
					names.append(n.capitalize())
				title.text = "%s — %s" % [type_label, ", ".join(names)]
			else:
				title.text = "%s (sin oponentes)" % type_label
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 15)
	content_vbox.add_child(title)

	# ── Details container (collapsible) ──────────────────────────────────
	var details := VBoxContainer.new()
	details.visible = false
	details.add_theme_constant_override("separation", 4)
	details.set_meta("is_details", true)
	content_vbox.add_child(details)

	match event_type:
		"cutscene":
			_build_cutscene_details(details, event_idx, event_data)
		"match":
			_build_match_details(details, event_idx, event_data)
		"simultaneous":
			_build_simultaneous_details(details, event_idx, event_data)

	# ── Button column (right side) ───────────────────────────────────────
	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 2)
	hbox.add_child(btn_col)

	var expand_btn := _make_card_button("v", func(): _toggle_details(card))
	expand_btn.set_meta("is_expand_btn", true)
	btn_col.add_child(expand_btn)

	btn_col.add_child(_make_card_button("x", func(): _delete_event(event_idx), COLOR_DELETE))
	btn_col.add_child(_make_card_button("^", func(): _move_event(event_idx, -1)))
	btn_col.add_child(_make_card_button("v ", func(): _move_event(event_idx, 1)))

	# Store references for expand/collapse
	card.set_meta("details", details)
	card.set_meta("event_idx", event_idx)
	_card_index_map[card] = event_idx

	return card


# ═════════════════════════════════════════════════════════════════════════════
# Detail Builders
# ═════════════════════════════════════════════════════════════════════════════

func _build_cutscene_details(parent: VBoxContainer, event_idx: int, data: Dictionary) -> void:
	_add_line_edit_row(parent, "Ruta del script:", data.get("script_path", ""),
		func(text: String): _update_event_data(event_idx, "script_path", text))


func _build_match_details(parent: VBoxContainer, event_idx: int, data: Dictionary) -> void:
	_add_line_edit_row(parent, "ID oponente:", data.get("opponent_id", ""),
		func(text: String): _update_event_data(event_idx, "opponent_id", text))

	_add_slider_row(parent, "Dificultad IA:", data.get("ai_difficulty", 0.3), 0.0, 1.0, 0.05,
		func(val: float): _update_event_data(event_idx, "ai_difficulty", val))

	_add_option_row(parent, "Reglas:", RULES_OPTIONS, data.get("game_rules_preset", "standard"),
		func(idx: int): _update_event_data(event_idx, "game_rules_preset", RULES_OPTIONS[idx]))

	_add_line_edit_row(parent, "Script intro:", data.get("intro_script", ""),
		func(text: String): _update_event_data(event_idx, "intro_script", text))

	_add_line_edit_row(parent, "Script reacciones:", data.get("reactions_script", ""),
		func(text: String): _update_event_data(event_idx, "reactions_script", text))

	_add_option_row(parent, "Estilo jugador:", STYLE_OPTIONS, data.get("player_style", "slam"),
		func(idx: int): _update_event_data(event_idx, "player_style", STYLE_OPTIONS[idx]))

	_add_option_row(parent, "Estilo oponente:", STYLE_OPTIONS, data.get("opponent_style", "gentle"),
		func(idx: int): _update_event_data(event_idx, "opponent_style", STYLE_OPTIONS[idx]))


func _build_simultaneous_details(parent: VBoxContainer, event_idx: int, data: Dictionary) -> void:
	var matches: Array = data.get("matches", [])

	var sub_list := VBoxContainer.new()
	sub_list.add_theme_constant_override("separation", 8)
	sub_list.set_meta("is_sub_list", true)
	parent.add_child(sub_list)

	for i in range(matches.size()):
		_add_sub_match_card(sub_list, event_idx, i, matches[i])

	var add_btn := _make_toolbar_button("+ Oponente", COLOR_SIMULTANEOUS,
		func(): _add_sub_match(event_idx))
	add_btn.custom_minimum_size = Vector2(100, 28)
	parent.add_child(add_btn)


func _add_sub_match_card(parent: VBoxContainer, event_idx: int, sub_idx: int, data: Dictionary) -> void:
	var sub_panel := PanelContainer.new()
	sub_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sub_style := StyleBoxFlat.new()
	sub_style.bg_color = COLOR_BG
	sub_style.set_corner_radius_all(4)
	sub_style.border_width_left = 3
	sub_style.border_color = COLOR_SIMULTANEOUS.darkened(0.2)
	sub_style.content_margin_left = 10
	sub_style.content_margin_right = 8
	sub_style.content_margin_top = 6
	sub_style.content_margin_bottom = 6
	sub_panel.add_theme_stylebox_override("panel", sub_style)
	parent.add_child(sub_panel)

	var sub_vbox := VBoxContainer.new()
	sub_vbox.add_theme_constant_override("separation", 4)
	sub_panel.add_child(sub_vbox)

	# Header row with opponent label + delete button
	var header_hbox := HBoxContainer.new()
	sub_vbox.add_child(header_hbox)

	var sub_title := Label.new()
	var opp_name: String = data.get("opponent_id", "")
	sub_title.text = "Oponente %d: %s" % [sub_idx + 1, opp_name.capitalize() if opp_name != "" else "?"]
	sub_title.add_theme_color_override("font_color", COLOR_SIMULTANEOUS.lightened(0.3))
	sub_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(sub_title)

	var del_sub_btn := _make_card_button("x", func(): _delete_sub_match(event_idx, sub_idx), COLOR_DELETE)
	header_hbox.add_child(del_sub_btn)

	# Fields
	_add_line_edit_row(sub_vbox, "ID oponente:", data.get("opponent_id", ""),
		func(text: String): _update_sub_match_data(event_idx, sub_idx, "opponent_id", text))

	_add_slider_row(sub_vbox, "Dificultad IA:", data.get("ai_difficulty", 0.3), 0.0, 1.0, 0.05,
		func(val: float): _update_sub_match_data(event_idx, sub_idx, "ai_difficulty", val))

	_add_option_row(sub_vbox, "Reglas:", RULES_OPTIONS, data.get("game_rules_preset", "standard"),
		func(idx: int): _update_sub_match_data(event_idx, sub_idx, "game_rules_preset", RULES_OPTIONS[idx]))

	_add_line_edit_row(sub_vbox, "Script intro:", data.get("intro_script", ""),
		func(text: String): _update_sub_match_data(event_idx, sub_idx, "intro_script", text))

	_add_line_edit_row(sub_vbox, "Script reacciones:", data.get("reactions_script", ""),
		func(text: String): _update_sub_match_data(event_idx, sub_idx, "reactions_script", text))

	_add_option_row(sub_vbox, "Estilo jugador:", STYLE_OPTIONS, data.get("player_style", "slam"),
		func(idx: int): _update_sub_match_data(event_idx, sub_idx, "player_style", STYLE_OPTIONS[idx]))

	_add_option_row(sub_vbox, "Estilo oponente:", STYLE_OPTIONS, data.get("opponent_style", "gentle"),
		func(idx: int): _update_sub_match_data(event_idx, sub_idx, "opponent_style", STYLE_OPTIONS[idx]))


# ═════════════════════════════════════════════════════════════════════════════
# Row Helpers (shared by match and sub-match builders)
# ═════════════════════════════════════════════════════════════════════════════

func _add_line_edit_row(parent: Control, label_text: String, value: String, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 28)

	var edit_style := StyleBoxFlat.new()
	edit_style.bg_color = COLOR_INPUT_BG
	edit_style.set_corner_radius_all(3)
	edit_style.content_margin_left = 6
	edit_style.content_margin_right = 6
	edit_style.content_margin_top = 4
	edit_style.content_margin_bottom = 4
	edit.add_theme_stylebox_override("normal", edit_style)
	edit.add_theme_color_override("font_color", COLOR_TEXT)
	edit.add_theme_color_override("caret_color", COLOR_ACCENT)
	edit.text_changed.connect(on_change)
	row.add_child(edit)


func _add_slider_row(parent: Control, label_text: String, value: float,
		min_val: float, max_val: float, step: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 28)
	row.add_child(slider)

	var val_label := Label.new()
	val_label.text = "%.2f" % value
	val_label.custom_minimum_size = Vector2(40, 0)
	val_label.add_theme_color_override("font_color", COLOR_TEXT)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val_label)

	slider.value_changed.connect(func(val: float):
		val_label.text = "%.2f" % val
		on_change.call(val))


func _add_option_row(parent: Control, label_text: String, options: Array,
		current: String, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.custom_minimum_size = Vector2(0, 28)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INPUT_BG
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	opt.add_theme_stylebox_override("normal", style)
	opt.add_theme_color_override("font_color", COLOR_TEXT)

	for i in range(options.size()):
		opt.add_item(options[i], i)
		if options[i] == current:
			opt.select(i)

	opt.item_selected.connect(on_change)
	row.add_child(opt)


func _make_card_button(text: String, callback: Callable, color: Color = COLOR_TEXT_DIM) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(28, 28)

	var style_n := StyleBoxFlat.new()
	style_n.bg_color = COLOR_BUTTON_BG
	style_n.set_corner_radius_all(3)
	style_n.content_margin_left = 4
	style_n.content_margin_right = 4
	style_n.content_margin_top = 2
	style_n.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", style_n)

	var style_h := StyleBoxFlat.new()
	style_h.bg_color = COLOR_BUTTON_BG.lightened(0.15)
	style_h.set_corner_radius_all(3)
	style_h.content_margin_left = 4
	style_h.content_margin_right = 4
	style_h.content_margin_top = 2
	style_h.content_margin_bottom = 2
	btn.add_theme_stylebox_override("hover", style_h)

	var style_p := StyleBoxFlat.new()
	style_p.bg_color = COLOR_ACCENT
	style_p.set_corner_radius_all(3)
	style_p.content_margin_left = 4
	style_p.content_margin_right = 4
	style_p.content_margin_top = 2
	style_p.content_margin_bottom = 2
	btn.add_theme_stylebox_override("pressed", style_p)

	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color.lightened(0.3))
	btn.pressed.connect(callback)
	return btn


# ═════════════════════════════════════════════════════════════════════════════
# List Management
# ═════════════════════════════════════════════════════════════════════════════

func _refresh_list() -> void:
	_card_index_map.clear()

	# Remove old cards
	for child in _event_list.get_children():
		child.queue_free()

	# Build cards
	for i in range(events.size()):
		var card := _create_event_card(i)
		_event_list.add_child(card)

	# Update info label
	if _info_label:
		if events.size() == 0:
			_info_label.text = "Sin eventos - agrega uno con los botones"
		else:
			_info_label.text = "%d evento(s)" % events.size()


func _toggle_details(card: PanelContainer) -> void:
	var details: VBoxContainer = card.get_meta("details")
	if details:
		details.visible = not details.visible
		# Update expand button text
		var expand_btn := _find_expand_button(card)
		if expand_btn:
			expand_btn.text = "^" if details.visible else "v"


func _find_expand_button(node: Node) -> Button:
	if node is Button and node.has_meta("is_expand_btn"):
		return node
	for child in node.get_children():
		var result := _find_expand_button(child)
		if result:
			return result
	return null


# ═════════════════════════════════════════════════════════════════════════════
# Event Actions
# ═════════════════════════════════════════════════════════════════════════════

func _on_add_cutscene() -> void:
	events.append({
		"type": "cutscene",
		"data": {
			"script_path": ""
		}
	})
	_refresh_list()


func _on_add_match() -> void:
	events.append({
		"type": "match",
		"data": _make_default_match_data()
	})
	_refresh_list()


func _on_add_simultaneous() -> void:
	events.append({
		"type": "simultaneous",
		"data": {
			"matches": []
		}
	})
	_refresh_list()


func _make_default_match_data() -> Dictionary:
	return {
		"opponent_id": "",
		"ai_difficulty": 0.3,
		"game_rules_preset": "standard",
		"intro_script": "",
		"reactions_script": "",
		"player_style": "slam",
		"opponent_style": "gentle"
	}


func _delete_event(idx: int) -> void:
	if idx >= 0 and idx < events.size():
		events.remove_at(idx)
		_refresh_list()


func _move_event(idx: int, direction: int) -> void:
	var new_idx := idx + direction
	if new_idx < 0 or new_idx >= events.size():
		return
	var temp: Dictionary = events[idx]
	events[idx] = events[new_idx]
	events[new_idx] = temp
	_refresh_list()


func _update_event_data(event_idx: int, key: String, value: Variant) -> void:
	if event_idx >= 0 and event_idx < events.size():
		events[event_idx]["data"][key] = value


func _add_sub_match(event_idx: int) -> void:
	if event_idx >= 0 and event_idx < events.size():
		var matches: Array = events[event_idx]["data"].get("matches", [])
		matches.append(_make_default_match_data())
		events[event_idx]["data"]["matches"] = matches
		_refresh_list()


func _delete_sub_match(event_idx: int, sub_idx: int) -> void:
	if event_idx >= 0 and event_idx < events.size():
		var matches: Array = events[event_idx]["data"].get("matches", [])
		if sub_idx >= 0 and sub_idx < matches.size():
			matches.remove_at(sub_idx)
			events[event_idx]["data"]["matches"] = matches
			_refresh_list()


func _update_sub_match_data(event_idx: int, sub_idx: int, key: String, value: Variant) -> void:
	if event_idx >= 0 and event_idx < events.size():
		var matches: Array = events[event_idx]["data"].get("matches", [])
		if sub_idx >= 0 and sub_idx < matches.size():
			matches[sub_idx][key] = value
