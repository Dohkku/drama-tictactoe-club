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
var portrait_path_edit: LineEdit = null
var portrait_browse_btn: Button = null
var image_dialog: FileDialog = null

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

# Portrait crop controls (built in _setup_crop_ui)
var crop_zoom_slider: HSlider = null
var crop_offset_x_slider: HSlider = null
var crop_offset_y_slider: HSlider = null
var crop_reset_button: Button = null


func _ready() -> void:
	_setup_image_ui()
	_setup_crop_ui()

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


func _setup_image_ui() -> void:
	# Add Image Row to Basic Section
	var form_vbox = id_edit.get_parent().get_parent()
	var image_row = HBoxContainer.new()
	image_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(image_row)
	form_vbox.move_child(image_row, id_edit.get_parent().get_index() + 2) # After NameRow
	
	var lbl = Label.new()
	lbl.text = "Retrato (Imagen):"
	lbl.custom_minimum_size = Vector2(120, 0)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	lbl.add_theme_font_size_override("font_size", 14)
	image_row.add_child(lbl)
	
	portrait_path_edit = LineEdit.new()
	portrait_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_path_edit.editable = false
	portrait_path_edit.placeholder_text = "res://path/to/image.png"
	portrait_path_edit.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	var edit_style = id_edit.get_theme_stylebox("normal").duplicate()
	portrait_path_edit.add_theme_stylebox_override("normal", edit_style)
	image_row.add_child(portrait_path_edit)
	
	portrait_browse_btn = Button.new()
	portrait_browse_btn.text = "..."
	portrait_browse_btn.custom_minimum_size = Vector2(40, 0)
	portrait_browse_btn.pressed.connect(_on_portrait_browse_pressed)
	image_row.add_child(portrait_browse_btn)
	
	# Setup FileDialog
	image_dialog = FileDialog.new()
	image_dialog.title = "Seleccionar Retrato"
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.access = FileDialog.ACCESS_RESOURCES
	image_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.jpg,*.jpeg ; JPEG Images", "*.webp ; WebP Images"])
	image_dialog.file_selected.connect(_on_portrait_selected)
	add_child(image_dialog)


func _setup_crop_ui() -> void:
	# Add crop controls below the PreviewSlot inside PreviewVBox
	var preview_vbox: VBoxContainer = preview_slot.get_parent()

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.25, 0.25, 0.35, 0.5))
	preview_vbox.add_child(sep)

	var crop_label := Label.new()
	crop_label.text = "Encuadre del Retrato"
	crop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crop_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.85))
	crop_label.add_theme_font_size_override("font_size", 14)
	preview_vbox.add_child(crop_label)

	# Zoom slider row
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 6)
	preview_vbox.add_child(zoom_row)

	var zoom_lbl := Label.new()
	zoom_lbl.text = "Zoom:"
	zoom_lbl.custom_minimum_size = Vector2(70, 0)
	zoom_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	zoom_lbl.add_theme_font_size_override("font_size", 12)
	zoom_row.add_child(zoom_lbl)

	crop_zoom_slider = HSlider.new()
	crop_zoom_slider.min_value = 0.5
	crop_zoom_slider.max_value = 2.0
	crop_zoom_slider.step = 0.05
	crop_zoom_slider.value = 1.0
	crop_zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crop_zoom_slider.custom_minimum_size = Vector2(0, 20)
	crop_zoom_slider.value_changed.connect(_on_crop_zoom_changed)
	zoom_row.add_child(crop_zoom_slider)

	# Offset X slider row
	var ox_row := HBoxContainer.new()
	ox_row.add_theme_constant_override("separation", 6)
	preview_vbox.add_child(ox_row)

	var ox_lbl := Label.new()
	ox_lbl.text = "Pan X:"
	ox_lbl.custom_minimum_size = Vector2(70, 0)
	ox_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	ox_lbl.add_theme_font_size_override("font_size", 12)
	ox_row.add_child(ox_lbl)

	crop_offset_x_slider = HSlider.new()
	crop_offset_x_slider.min_value = -0.5
	crop_offset_x_slider.max_value = 0.5
	crop_offset_x_slider.step = 0.01
	crop_offset_x_slider.value = 0.0
	crop_offset_x_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crop_offset_x_slider.custom_minimum_size = Vector2(0, 20)
	crop_offset_x_slider.value_changed.connect(_on_crop_offset_x_changed)
	ox_row.add_child(crop_offset_x_slider)

	# Offset Y slider row
	var oy_row := HBoxContainer.new()
	oy_row.add_theme_constant_override("separation", 6)
	preview_vbox.add_child(oy_row)

	var oy_lbl := Label.new()
	oy_lbl.text = "Pan Y:"
	oy_lbl.custom_minimum_size = Vector2(70, 0)
	oy_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	oy_lbl.add_theme_font_size_override("font_size", 12)
	oy_row.add_child(oy_lbl)

	crop_offset_y_slider = HSlider.new()
	crop_offset_y_slider.min_value = -0.5
	crop_offset_y_slider.max_value = 0.5
	crop_offset_y_slider.step = 0.01
	crop_offset_y_slider.value = 0.0
	crop_offset_y_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crop_offset_y_slider.custom_minimum_size = Vector2(0, 20)
	crop_offset_y_slider.value_changed.connect(_on_crop_offset_y_changed)
	oy_row.add_child(crop_offset_y_slider)

	# Reset button
	crop_reset_button = Button.new()
	crop_reset_button.text = "Resetear Encuadre"
	crop_reset_button.add_theme_font_size_override("font_size", 12)
	crop_reset_button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	var reset_sb := StyleBoxFlat.new()
	reset_sb.bg_color = Color(0.2, 0.2, 0.28)
	reset_sb.set_corner_radius_all(4)
	reset_sb.set_content_margin_all(4)
	crop_reset_button.add_theme_stylebox_override("normal", reset_sb)
	crop_reset_button.pressed.connect(_on_crop_reset_pressed)
	preview_vbox.add_child(crop_reset_button)


func _on_crop_zoom_changed(value: float) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	ch.portrait_zoom = value
	_update_preview()
	characters_changed.emit()


func _on_crop_offset_x_changed(value: float) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	ch.portrait_offset.x = value
	_update_preview()
	characters_changed.emit()


func _on_crop_offset_y_changed(value: float) -> void:
	if _updating_ui:
		return
	var ch := _get_current()
	if ch == null:
		return
	ch.portrait_offset.y = value
	_update_preview()
	characters_changed.emit()


func _on_crop_reset_pressed() -> void:
	var ch := _get_current()
	if ch == null:
		return
	ch.portrait_zoom = 1.0
	ch.portrait_offset = Vector2.ZERO
	_updating_ui = true
	crop_zoom_slider.value = 1.0
	crop_offset_x_slider.value = 0.0
	crop_offset_y_slider.value = 0.0
	_updating_ui = false
	_update_preview()
	characters_changed.emit()


func _on_portrait_browse_pressed() -> void:
	image_dialog.popup_centered(Vector2i(700, 500))


func _on_portrait_selected(path: String) -> void:
	var ch = _get_current()
	if ch:
		ch.portrait_image = load(path)
		portrait_path_edit.text = path
		_update_preview()
		characters_changed.emit()


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
	if portrait_browse_btn: portrait_browse_btn.disabled = !enabled
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
	if crop_zoom_slider: crop_zoom_slider.editable = enabled
	if crop_offset_x_slider: crop_offset_x_slider.editable = enabled
	if crop_offset_y_slider: crop_offset_y_slider.editable = enabled
	if crop_reset_button: crop_reset_button.disabled = !enabled


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
	
	if portrait_path_edit:
		if ch.portrait_image:
			portrait_path_edit.text = ch.portrait_image.resource_path
		else:
			portrait_path_edit.text = ""

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

	# Portrait crop
	if crop_zoom_slider:
		crop_zoom_slider.value = ch.portrait_zoom
	if crop_offset_x_slider:
		crop_offset_x_slider.value = ch.portrait_offset.x
	if crop_offset_y_slider:
		crop_offset_y_slider.value = ch.portrait_offset.y

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
	if portrait_path_edit: portrait_path_edit.text = ""
	style_option.selected = 0
	pose_edit.text = ""
	direction_option.selected = 1
	pitch_spin.value = 220.0
	variation_spin.value = 30.0
	waveform_option.selected = 0
	dialogue_bg_picker.color = Color(0.1, 0.1, 0.15, 0.9)
	dialogue_border_picker.color = Color(0.3, 0.3, 0.4, 1.0)
	if crop_zoom_slider: crop_zoom_slider.value = 1.0
	if crop_offset_x_slider: crop_offset_x_slider.value = 0.0
	if crop_offset_y_slider: crop_offset_y_slider.value = 0.0
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
		var img_path: String = ""
		if ch.expression_images.has(expr_name):
			var tex: Texture2D = ch.expression_images[expr_name]
			if tex and tex.resource_path != "":
				img_path = tex.resource_path
		_add_expression_row(expr_name, expr_color, img_path)


func _add_expression_row(expr_name: String = "", expr_color: Color = Color.WHITE, img_path: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_field := LineEdit.new()
	name_field.text = expr_name
	name_field.placeholder_text = "nombre"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.custom_minimum_size = Vector2(80, 0)
	name_field.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	name_field.add_theme_color_override("font_placeholder_color", Color(0.4, 0.4, 0.5))
	name_field.add_theme_font_size_override("font_size", 12)
	var name_sb := StyleBoxFlat.new()
	name_sb.bg_color = Color(0.12, 0.13, 0.18)
	name_sb.border_color = Color(0.25, 0.25, 0.35)
	name_sb.set_border_width_all(1)
	name_sb.set_corner_radius_all(4)
	name_sb.set_content_margin_all(4)
	name_field.add_theme_stylebox_override("normal", name_sb)
	row.add_child(name_field)

	var color_btn := ColorPickerButton.new()
	color_btn.color = expr_color
	color_btn.custom_minimum_size = Vector2(30, 26)
	row.add_child(color_btn)

	# Image path for this expression
	var img_field := LineEdit.new()
	img_field.text = img_path
	img_field.placeholder_text = "imagen..."
	img_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img_field.custom_minimum_size = Vector2(60, 0)
	img_field.add_theme_font_size_override("font_size", 10)
	img_field.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	img_field.add_theme_color_override("font_placeholder_color", Color(0.35, 0.35, 0.45))
	var img_sb := StyleBoxFlat.new()
	img_sb.bg_color = Color(0.1, 0.12, 0.16)
	img_sb.border_color = Color(0.2, 0.2, 0.3)
	img_sb.set_border_width_all(1)
	img_sb.set_corner_radius_all(3)
	img_sb.set_content_margin_all(3)
	img_field.add_theme_stylebox_override("normal", img_sb)
	row.add_child(img_field)

	var img_browse := Button.new()
	img_browse.text = "📁"
	img_browse.custom_minimum_size = Vector2(28, 26)
	img_browse.add_theme_font_size_override("font_size", 12)
	img_browse.pressed.connect(func(): _browse_expression_image(img_field))
	row.add_child(img_browse)

	var del_btn := Button.new()
	del_btn.text = "x"
	del_btn.custom_minimum_size = Vector2(26, 26)
	var del_sb := StyleBoxFlat.new()
	del_sb.bg_color = Color(0.4, 0.15, 0.15)
	del_sb.set_corner_radius_all(4)
	del_sb.set_content_margin_all(3)
	del_btn.add_theme_stylebox_override("normal", del_sb)
	del_btn.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	del_btn.add_theme_font_size_override("font_size", 12)
	row.add_child(del_btn)

	expression_list_container.add_child(row)

	name_field.text_changed.connect(_on_expression_name_changed.bind(row))
	color_btn.color_changed.connect(_on_expression_color_changed.bind(row))
	img_field.text_changed.connect(func(_t: String) -> void: _sync_expression_images_from_ui())
	del_btn.pressed.connect(func() -> void: _delete_expression_row(row))
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


func _delete_expression_row(row: HBoxContainer) -> void:
	row.queue_free()
	await get_tree().process_frame
	_sync_expressions_from_ui()
	_sync_expression_images_from_ui()
	_update_preview()


func _sync_expression_images_from_ui() -> void:
	var ch := _get_current()
	if ch == null:
		return
	var new_images := {}
	for child in expression_list_container.get_children():
		if child is HBoxContainer and is_instance_valid(child) and child.get_child_count() >= 4:
			var name_field: LineEdit = child.get_child(0) as LineEdit
			var img_field: LineEdit = child.get_child(2) as LineEdit
			if name_field and img_field and name_field.text != "" and img_field.text != "":
				var tex: Texture2D = _try_load_texture(img_field.text)
				if tex:
					new_images[name_field.text] = tex
	ch.expression_images = new_images


func _try_load_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		return res
	return null


func _browse_expression_image(target_field: LineEdit) -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	dialog.title = "Seleccionar imagen de expresión"
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	dialog.size = Vector2i(700, 500)
	add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		target_field.text = path
		_sync_expression_images_from_ui()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


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

	# CharacterSlot handles its own rendering (including fallback to color)
	preview_slot.character_data = ch
	preview_slot._apply_expression("neutral")
	
	var name_lbl: Label = preview_slot.get_node_or_null("VBoxContainer/NameLabel")
	if name_lbl:
		name_lbl.text = ch.display_name

	# Show the preview
	preview_slot.visible = true
	preview_slot.modulate.a = 1.0


func _clear_preview() -> void:
	if preview_slot == null:
		return
	preview_slot.character_data = null
	preview_slot.portrait_rect.texture = null
	preview_slot.portrait_rect.modulate = Color(0.3, 0.3, 0.35)
	
	var name_lbl: Label = preview_slot.get_node_or_null("VBoxContainer/NameLabel")
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
