extends HSplitContainer

const CharacterDataScript = preload("res://characters/character_data.gd")

signal characters_changed()

var characters: Array[Resource] = []
var _selected_index: int = -1
var _updating_ui: bool = false

# Left panel
@onready var character_list: ItemList = %CharacterList
@onready var add_button: Button = %AddCharButton
@onready var delete_button: Button = %DeleteCharButton

# Form fields - Basic
@onready var id_edit: LineEdit = %IDEdit
@onready var name_edit: LineEdit = %NameEdit
@onready var color_picker: ColorPickerButton = %ColorPicker

# Form fields - Style
@onready var style_option: OptionButton = %StyleOption
@onready var pose_edit: LineEdit = %PoseEdit
@onready var direction_option: OptionButton = %DirectionOption

# Form fields - Voice
@onready var pitch_spin: SpinBox = %PitchSpin
@onready var variation_spin: SpinBox = %VariationSpin
@onready var waveform_option: OptionButton = %WaveformOption

# Form fields - Dialogue style
@onready var dialogue_bg_picker: ColorPickerButton = %DialogueBGPicker
@onready var dialogue_border_picker: ColorPickerButton = %DialogueBorderPicker

# Expression list
@onready var expression_list_container: VBoxContainer = %ExpressionListContainer
@onready var add_expression_button: Button = %AddExpressionButton

# Pose list
@onready var pose_list_container: VBoxContainer = %PoseListContainer
@onready var add_pose_button: Button = %AddPoseButton

# Preview
@onready var preview_slot: Control = %PreviewSlot


func _ready() -> void:
	# Connect list selection
	character_list.item_selected.connect(_on_character_selected)

	# Connect add/delete
	add_button.pressed.connect(_on_add_pressed)
	delete_button.pressed.connect(_on_delete_pressed)

	# Connect form fields
	id_edit.text_changed.connect(_on_field_changed.bind("character_id"))
	name_edit.text_changed.connect(_on_name_changed)
	color_picker.color_changed.connect(_on_color_changed)

	style_option.item_selected.connect(_on_style_selected)
	pose_edit.text_changed.connect(_on_field_changed.bind("default_pose"))
	direction_option.item_selected.connect(_on_direction_selected)

	pitch_spin.value_changed.connect(_on_pitch_changed)
	variation_spin.value_changed.connect(_on_variation_changed)
	waveform_option.item_selected.connect(_on_waveform_selected)

	dialogue_bg_picker.color_changed.connect(_on_dialogue_bg_changed)
	dialogue_border_picker.color_changed.connect(_on_dialogue_border_changed)

	# Connect expression/pose add buttons
	add_expression_button.pressed.connect(_on_add_expression)
	add_pose_button.pressed.connect(_on_add_pose)

	# Populate option button items
	_setup_option_buttons()

	# Initial state
	_set_form_enabled(false)


func _setup_option_buttons() -> void:
	style_option.clear()
	for s in ["gentle", "slam", "spinning", "dramatic", "nervous"]:
		style_option.add_item(s)

	direction_option.clear()
	for d in ["left", "center", "right"]:
		direction_option.add_item(d)

	waveform_option.clear()
	for w in ["sine", "square", "triangle"]:
		waveform_option.add_item(w)


func _set_form_enabled(enabled: bool) -> void:
	id_edit.editable = enabled
	name_edit.editable = enabled
	color_picker.disabled = !enabled
	style_option.disabled = !enabled
	pose_edit.editable = enabled
	direction_option.disabled = !enabled
	pitch_spin.editable = enabled
	variation_spin.editable = enabled
	waveform_option.disabled = !enabled
	dialogue_bg_picker.disabled = !enabled
	dialogue_border_picker.disabled = !enabled
	add_expression_button.disabled = !enabled
	add_pose_button.disabled = !enabled
	delete_button.disabled = !enabled


# --- List management ---

func _refresh_list() -> void:
	character_list.clear()
	for ch in characters:
		var label_text: String = ch.get("display_name") if ch.get("display_name") != "" else "(sin nombre)"
		character_list.add_item(label_text)
	if _selected_index >= 0 and _selected_index < character_list.item_count:
		character_list.select(_selected_index)


func _on_add_pressed() -> void:
	var new_char := CharacterDataScript.new()
	new_char.character_id = "char_%d" % (characters.size() + 1)
	new_char.display_name = "Personaje %d" % (characters.size() + 1)
	new_char.color = Color(randf_range(0.3, 1.0), randf_range(0.3, 1.0), randf_range(0.3, 1.0))
	characters.append(new_char)
	_refresh_list()
	_selected_index = characters.size() - 1
	character_list.select(_selected_index)
	_populate_form()
	characters_changed.emit()


func _on_delete_pressed() -> void:
	if _selected_index < 0 or _selected_index >= characters.size():
		return
	characters.remove_at(_selected_index)
	if _selected_index >= characters.size():
		_selected_index = characters.size() - 1
	_refresh_list()
	if _selected_index >= 0:
		_populate_form()
	else:
		_clear_form()
		_set_form_enabled(false)
	characters_changed.emit()


func _on_character_selected(index: int) -> void:
	_selected_index = index
	_populate_form()


# --- Form population ---

func _populate_form() -> void:
	if _selected_index < 0 or _selected_index >= characters.size():
		return
	_updating_ui = true
	_set_form_enabled(true)

	var ch: Resource = characters[_selected_index]

	id_edit.text = ch.character_id
	name_edit.text = ch.display_name
	color_picker.color = ch.color

	# Style
	var style_items := ["gentle", "slam", "spinning", "dramatic", "nervous"]
	var style_idx := style_items.find(ch.default_style)
	style_option.selected = style_idx if style_idx >= 0 else 0

	pose_edit.text = ch.default_pose

	var dir_items := ["left", "center", "right"]
	var dir_idx := dir_items.find(ch.default_look)
	direction_option.selected = dir_idx if dir_idx >= 0 else 1

	# Voice
	pitch_spin.value = ch.voice_pitch
	variation_spin.value = ch.voice_variation
	var wave_items := ["sine", "square", "triangle"]
	var wave_idx := wave_items.find(ch.voice_waveform)
	waveform_option.selected = wave_idx if wave_idx >= 0 else 0

	# Dialogue
	dialogue_bg_picker.color = ch.dialogue_bg_color
	dialogue_border_picker.color = ch.dialogue_border_color

	# Expressions
	_rebuild_expression_list(ch)

	# Poses
	_rebuild_pose_list(ch)

	_updating_ui = false

	# Update preview
	_update_preview()


func _clear_form() -> void:
	_updating_ui = true
	id_edit.text = ""
	name_edit.text = ""
	color_picker.color = Color.WHITE
	style_option.selected = 0
	pose_edit.text = ""
	direction_option.selected = 1
	pitch_spin.value = 220.0
	variation_spin.value = 30.0
	waveform_option.selected = 0
	dialogue_bg_picker.color = Color(0.1, 0.1, 0.15, 0.9)
	dialogue_border_picker.color = Color(0.3, 0.3, 0.4, 1.0)
	_clear_children(expression_list_container)
	_clear_children(pose_list_container)
	_updating_ui = false

	# Clear preview
	_clear_preview()


# --- Field change handlers ---

func _get_current() -> Resource:
	if _selected_index < 0 or _selected_index >= characters.size():
		return null
	return characters[_selected_index]


func _on_field_changed(value: String, field: String) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	ch.set(field, value)
	if field == "character_id":
		characters_changed.emit()


func _on_name_changed(value: String) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	ch.display_name = value
	_refresh_list()
	_update_preview()
	characters_changed.emit()


func _on_color_changed(color: Color) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	ch.color = color
	_update_preview()


func _on_style_selected(index: int) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	var styles := ["gentle", "slam", "spinning", "dramatic", "nervous"]
	ch.default_style = styles[index]


func _on_direction_selected(index: int) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	var dirs := ["left", "center", "right"]
	ch.default_look = dirs[index]
	_update_preview()


func _on_pitch_changed(value: float) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	ch.voice_pitch = value


func _on_variation_changed(value: float) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	ch.voice_variation = value


func _on_waveform_selected(index: int) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	var waves := ["sine", "square", "triangle"]
	ch.voice_waveform = waves[index]


func _on_dialogue_bg_changed(color: Color) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	ch.dialogue_bg_color = color


func _on_dialogue_border_changed(color: Color) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	ch.dialogue_border_color = color


# --- Expressions ---

func _rebuild_expression_list(ch: Resource) -> void:
	_clear_children(expression_list_container)
	for expr_name in ch.expressions.keys():
		var expr_color: Color = ch.expressions[expr_name]
		_add_expression_row(expr_name, expr_color)


func _add_expression_row(expr_name: String = "", expr_color: Color = Color.WHITE) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var name_field := LineEdit.new()
	name_field.text = expr_name
	name_field.placeholder_text = "nombre"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.custom_minimum_size = Vector2(100, 0)
	name_field.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	name_field.add_theme_color_override("font_placeholder_color", Color(0.4, 0.4, 0.5))
	var name_sb := StyleBoxFlat.new()
	name_sb.bg_color = Color(0.12, 0.13, 0.18)
	name_sb.border_color = Color(0.25, 0.25, 0.35)
	name_sb.set_border_width_all(1)
	name_sb.set_corner_radius_all(4)
	name_sb.set_content_margin_all(6)
	name_field.add_theme_stylebox_override("normal", name_sb)
	row.add_child(name_field)

	var color_btn := ColorPickerButton.new()
	color_btn.color = expr_color
	color_btn.custom_minimum_size = Vector2(40, 30)
	row.add_child(color_btn)

	var del_btn := Button.new()
	del_btn.text = "x"
	del_btn.custom_minimum_size = Vector2(30, 30)
	var del_sb := StyleBoxFlat.new()
	del_sb.bg_color = Color(0.4, 0.15, 0.15)
	del_sb.set_corner_radius_all(4)
	del_sb.set_content_margin_all(4)
	del_btn.add_theme_stylebox_override("normal", del_sb)
	del_btn.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	row.add_child(del_btn)

	expression_list_container.add_child(row)

	# Connect signals
	name_field.text_changed.connect(_on_expression_name_changed.bind(row))
	color_btn.color_changed.connect(_on_expression_color_changed.bind(row))
	del_btn.pressed.connect(_on_expression_delete.bind(row))


func _on_add_expression() -> void:
	var ch := _get_current()
	if ch == null:
		return
	var new_name := "expr_%d" % (ch.expressions.size() + 1)
	ch.expressions[new_name] = Color.WHITE
	_add_expression_row(new_name, Color.WHITE)
	_update_preview()


func _on_expression_name_changed(_new_text: String, row: HBoxContainer) -> void:
	if _updating_ui:
		return
	_sync_expressions_from_ui()


func _on_expression_color_changed(_color: Color, row: HBoxContainer) -> void:
	if _updating_ui:
		return
	_sync_expressions_from_ui()
	_update_preview()


func _on_expression_delete(row: HBoxContainer) -> void:
	row.queue_free()
	# Use deferred to let the node actually be removed
	_sync_expressions_from_ui.call_deferred()
	_update_preview.call_deferred()


func _sync_expressions_from_ui() -> void:
	var ch := _get_current()
	if ch == null:
		return
	var new_expressions := {}
	for child in expression_list_container.get_children():
		if child is HBoxContainer and is_instance_valid(child) and child.get_child_count() >= 2:
			var name_field: LineEdit = child.get_child(0) as LineEdit
			var color_btn: ColorPickerButton = child.get_child(1) as ColorPickerButton
			if name_field and color_btn and name_field.text != "":
				new_expressions[name_field.text] = color_btn.color
	ch.expressions = new_expressions


# --- Poses ---

func _rebuild_pose_list(ch: Resource) -> void:
	_clear_children(pose_list_container)
	for pose_name in ch.poses.keys():
		var pose_data: Dictionary = ch.poses[pose_name]
		var energy: float = pose_data.get("energy", 0.5)
		var openness: float = pose_data.get("openness", 0.5)
		_add_pose_row(pose_name, energy, openness)


func _add_pose_row(pose_name: String = "", energy: float = 0.5, openness: float = 0.5) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var name_field := LineEdit.new()
	name_field.text = pose_name
	name_field.placeholder_text = "nombre"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.custom_minimum_size = Vector2(80, 0)
	name_field.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	name_field.add_theme_color_override("font_placeholder_color", Color(0.4, 0.4, 0.5))
	var name_sb := StyleBoxFlat.new()
	name_sb.bg_color = Color(0.12, 0.13, 0.18)
	name_sb.border_color = Color(0.25, 0.25, 0.35)
	name_sb.set_border_width_all(1)
	name_sb.set_corner_radius_all(4)
	name_sb.set_content_margin_all(6)
	name_field.add_theme_stylebox_override("normal", name_sb)
	row.add_child(name_field)

	# Energy label + slider
	var energy_label := Label.new()
	energy_label.text = "E:"
	energy_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	energy_label.add_theme_font_size_override("font_size", 12)
	row.add_child(energy_label)

	var energy_slider := HSlider.new()
	energy_slider.min_value = 0.0
	energy_slider.max_value = 1.0
	energy_slider.step = 0.05
	energy_slider.value = energy
	energy_slider.custom_minimum_size = Vector2(60, 20)
	row.add_child(energy_slider)

	# Openness label + slider
	var open_label := Label.new()
	open_label.text = "A:"
	open_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	open_label.add_theme_font_size_override("font_size", 12)
	row.add_child(open_label)

	var openness_slider := HSlider.new()
	openness_slider.min_value = 0.0
	openness_slider.max_value = 1.0
	openness_slider.step = 0.05
	openness_slider.value = openness
	openness_slider.custom_minimum_size = Vector2(60, 20)
	row.add_child(openness_slider)

	var del_btn := Button.new()
	del_btn.text = "x"
	del_btn.custom_minimum_size = Vector2(30, 30)
	var del_sb := StyleBoxFlat.new()
	del_sb.bg_color = Color(0.4, 0.15, 0.15)
	del_sb.set_corner_radius_all(4)
	del_sb.set_content_margin_all(4)
	del_btn.add_theme_stylebox_override("normal", del_sb)
	del_btn.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	row.add_child(del_btn)

	pose_list_container.add_child(row)

	# Connect signals
	name_field.text_changed.connect(_on_pose_field_changed.bind(row))
	energy_slider.value_changed.connect(_on_pose_field_changed_float.bind(row))
	openness_slider.value_changed.connect(_on_pose_field_changed_float.bind(row))
	del_btn.pressed.connect(_on_pose_delete.bind(row))


func _on_add_pose() -> void:
	var ch := _get_current()
	if ch == null:
		return
	var new_name := "pose_%d" % (ch.poses.size() + 1)
	ch.poses[new_name] = {"description": "", "energy": 0.5, "openness": 0.5}
	_add_pose_row(new_name, 0.5, 0.5)


func _on_pose_field_changed(_new_text: String, _row: HBoxContainer) -> void:
	if _updating_ui:
		return
	_sync_poses_from_ui()


func _on_pose_field_changed_float(_value: float, _row: HBoxContainer) -> void:
	if _updating_ui:
		return
	_sync_poses_from_ui()


func _on_pose_delete(row: HBoxContainer) -> void:
	row.queue_free()
	_sync_poses_from_ui.call_deferred()


func _sync_poses_from_ui() -> void:
	var ch := _get_current()
	if ch == null:
		return
	var new_poses := {}
	for child in pose_list_container.get_children():
		if child is HBoxContainer and is_instance_valid(child) and child.get_child_count() >= 6:
			var name_field: LineEdit = child.get_child(0) as LineEdit
			var energy_slider: HSlider = child.get_child(2) as HSlider
			var openness_slider: HSlider = child.get_child(4) as HSlider
			if name_field and energy_slider and openness_slider and name_field.text != "":
				new_poses[name_field.text] = {
					"description": "",
					"energy": energy_slider.value,
					"openness": openness_slider.value
				}
	ch.poses = new_poses


# --- Preview ---

func _update_preview() -> void:
	var ch := _get_current()
	if ch == null:
		_clear_preview()
		return

	if preview_slot == null:
		return

	# Get portrait and name label from the preview slot
	var portrait: ColorRect = preview_slot.get_node_or_null("VBoxContainer/PortraitRect")
	var name_lbl: Label = preview_slot.get_node_or_null("VBoxContainer/NameLabel")
	var expr_lbl: Label = preview_slot.get_node_or_null("VBoxContainer/PortraitRect/ExpressionLabel")

	if portrait:
		portrait.color = ch.color
	if name_lbl:
		name_lbl.text = ch.display_name
	if expr_lbl:
		expr_lbl.text = "neutral"

	# Show the preview
	preview_slot.visible = true
	preview_slot.modulate.a = 1.0


func _clear_preview() -> void:
	if preview_slot == null:
		return
	var portrait: ColorRect = preview_slot.get_node_or_null("VBoxContainer/PortraitRect")
	var name_lbl: Label = preview_slot.get_node_or_null("VBoxContainer/NameLabel")
	if portrait:
		portrait.color = Color(0.3, 0.3, 0.35)
	if name_lbl:
		name_lbl.text = ""
	preview_slot.modulate.a = 0.3


# --- Public API ---

func get_characters() -> Array:
	return characters


func set_characters(chars: Array) -> void:
	characters.clear()
	for ch in chars:
		if ch is CharacterDataScript:
			characters.append(ch)
	_refresh_list()
	if characters.size() > 0:
		_selected_index = 0
		character_list.select(0)
		_populate_form()
	else:
		_selected_index = -1
		_clear_form()
		_set_form_enabled(false)


# --- Utility ---

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
