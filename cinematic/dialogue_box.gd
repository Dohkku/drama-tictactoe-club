extends PanelContainer

var is_active: bool = false
var is_typing: bool = false
var _full_text: String = ""
var _char_speed: float = 0.03

var name_label: Label
var text_label: RichTextLabel
var advance_indicator: Label


func _ready() -> void:
	# Find children by unique name through owner (Main scene)
	name_label = owner.get_node("%SpeakerName") if owner else get_node("MarginContainer/VBoxContainer/SpeakerName")
	text_label = owner.get_node("%DialogueText") if owner else get_node("MarginContainer/VBoxContainer/DialogueText")
	advance_indicator = owner.get_node("%AdvanceIndicator") if owner else get_node("MarginContainer/VBoxContainer/AdvanceIndicator")
	visible = false
	if advance_indicator:
		advance_indicator.visible = false


func _input(event: InputEvent) -> void:
	if not is_active:
		return

	# Accept mouse click or touch anywhere on screen
	var is_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_touch = event is InputEventScreenTouch and event.pressed

	if is_click or is_touch:
		get_viewport().set_input_as_handled()
		if is_typing:
			_finish_typing()
		else:
			hide_dialogue()
			EventBus.dialogue_finished.emit()


func show_dialogue(speaker: String, text: String, speaker_color: Color = Color.WHITE) -> void:
	_full_text = text
	name_label.text = speaker
	name_label.add_theme_color_override("font_color", speaker_color)
	text_label.text = ""
	text_label.visible_characters = 0

	visible = true
	is_active = true
	if advance_indicator:
		advance_indicator.visible = false

	text_label.text = _full_text
	text_label.visible_characters = 0
	is_typing = true
	_type_text()


func hide_dialogue() -> void:
	visible = false
	is_active = false
	is_typing = false


func _type_text() -> void:
	var total_chars := _full_text.length()
	for i in range(total_chars):
		if not is_typing:
			return
		text_label.visible_characters = i + 1
		await get_tree().create_timer(_char_speed).timeout
	_finish_typing()


func _finish_typing() -> void:
	is_typing = false
	text_label.visible_characters = -1
	if advance_indicator:
		advance_indicator.visible = true
