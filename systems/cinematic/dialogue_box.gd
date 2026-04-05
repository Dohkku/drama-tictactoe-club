extends PanelContainer

const DialogueTextProcessorScript = preload("res://systems/cinematic/dialogue_text_processor.gd")
const DialogueAudioScript = preload("res://systems/cinematic/dialogue_audio.gd")

var is_active: bool = false
var is_typing: bool = false
var _full_text: String = ""
var _char_speed: float = 0.03

var name_label: Label
var text_label: RichTextLabel
var advance_indicator: Label
var _choice_container: VBoxContainer = null
var _in_choice_mode: bool = false
var _type_id: int = 0  # Incremented to invalidate old typing coroutines

var _text_processor: RefCounted = null
var _dialogue_audio: Node = null
var _processed: Dictionary = {}  # Result from DialogueTextProcessor
var _current_character_data: Resource = null
var _default_stylebox: StyleBox = null  # Original panel style for restoring


func _ready() -> void:
	name_label = owner.get_node("%SpeakerName") if owner else get_node("MarginContainer/VBoxContainer/SpeakerName")
	text_label = owner.get_node("%DialogueText") if owner else get_node("MarginContainer/VBoxContainer/DialogueText")
	advance_indicator = owner.get_node("%AdvanceIndicator") if owner else get_node("MarginContainer/VBoxContainer/AdvanceIndicator")
	if text_label:
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.scroll_active = false
	visible = false
	if advance_indicator:
		advance_indicator.visible = false

	# Choice buttons container (added dynamically)
	_choice_container = VBoxContainer.new()
	_choice_container.visible = false
	_choice_container.add_theme_constant_override("separation", 6)
	var vbox = name_label.get_parent()
	vbox.add_child(_choice_container)

	# Text processor
	_text_processor = DialogueTextProcessorScript.new()

	# Dialogue audio
	_dialogue_audio = DialogueAudioScript.new()
	add_child(_dialogue_audio)

	# Save the original panel style for restoring later
	_default_stylebox = get_theme_stylebox("panel").duplicate() if has_theme_stylebox("panel") else null


var _advance_cooldown: bool = false

func _input(event: InputEvent) -> void:
	if not is_active or _in_choice_mode:
		return

	var is_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_touch = event is InputEventScreenTouch and event.pressed

	if is_click or is_touch:
		get_viewport().set_input_as_handled()
		if is_typing:
			_finish_typing()
			# Brief cooldown so fast clicks don't skip the completed text
			_advance_cooldown = true
			get_tree().create_timer(0.15).timeout.connect(func(): _advance_cooldown = false)
		elif not _advance_cooldown:
			hide_dialogue()
			EventBus.dialogue_finished.emit()


func show_dialogue(speaker: String, text: String, speaker_color: Color = Color.WHITE, character_data: Resource = null) -> void:
	_current_character_data = character_data

	# Process text through DSL tag processor
	_processed = _text_processor.process(text)

	_full_text = _processed.bbcode
	name_label.text = speaker
	name_label.add_theme_color_override("font_color", speaker_color)
	text_label.text = ""
	text_label.visible_characters = 0

	# Apply per-character styling if character data is available
	_apply_character_style(character_data)

	visible = true
	is_active = true
	if advance_indicator:
		advance_indicator.visible = false

	EventBus.dialogue_started.emit(speaker, text)

	text_label.text = _full_text
	text_label.visible_characters = 0
	is_typing = true
	_type_id += 1
	_type_text(_type_id)


func hide_dialogue() -> void:
	visible = false
	is_active = false
	is_typing = false
	_current_character_data = null


# ── Snapshot for editor preview ────────────────────────────────────────

func save_state() -> Dictionary:
	return {
		"visible": visible,
		"speaker": name_label.text if name_label else "",
		"text": _full_text,
	}


func load_state(state: Dictionary) -> void:
	if not state.get("visible", false):
		hide_dialogue()
		return
	if name_label:
		name_label.text = state.get("speaker", "")
	if text_label:
		text_label.text = state.get("text", "")
		text_label.visible_characters = -1
	visible = true
	is_active = true
	is_typing = false


func _type_text(my_id: int) -> void:
	var total_chars: int = _processed.get("plain_length", 0)
	var triggers: Array = _processed.triggers
	var waits: Array = _processed.waits

	for i in range(total_chars):
		if not is_typing or _type_id != my_id:
			return  # Invalidated by a newer show_dialogue call

		# Check for triggers at this character index
		for trig in triggers:
			if trig.char_index == i:
				EventBus.dialogue_trigger.emit(trig.action)

		# Check for waits at this character index
		for w in waits:
			if w.char_index == i:
				await get_tree().create_timer(w.duration).timeout
				if not is_typing or _type_id != my_id:
					return

		text_label.visible_characters = i + 1

		# Play typing beep (skip spaces)
		var visible_char := _get_visible_char_at(i)
		if visible_char != " " and _current_character_data != null:
			_dialogue_audio.play_char_beep_varied(
				_current_character_data.character_id,
				_current_character_data.voice_pitch,
				_current_character_data.voice_variation,
				_current_character_data.voice_waveform,
			)
		elif visible_char != " ":
			# No character data — use a default beep
			_dialogue_audio.play_char_beep("default", 220.0, "sine")

		await get_tree().create_timer(_char_speed).timeout

	if _type_id == my_id:
		_finish_typing()


func _finish_typing() -> void:
	is_typing = false
	text_label.visible_characters = -1
	if advance_indicator:
		advance_indicator.visible = true


## Try to extract the visible character at a given plain-text index.
## Falls back to a non-space placeholder if unable to determine.
func _get_visible_char_at(plain_index: int) -> String:
	# Walk the bbcode string, counting only non-tag characters
	var bbcode: String = _full_text
	var count := 0
	var idx := 0
	while idx < bbcode.length():
		if bbcode[idx] == "[":
			# Skip past the BBCode tag
			var close := bbcode.find("]", idx)
			if close != -1:
				idx = close + 1
				continue
			# No closing bracket — treat as literal
		if count == plain_index:
			return bbcode[idx]
		count += 1
		idx += 1
	return "a"  # Fallback — will still beep


## Apply character-specific visual styling to the dialogue panel.
func _apply_character_style(character_data: Resource) -> void:
	if character_data == null:
		# Restore default style if we have one
		if _default_stylebox:
			add_theme_stylebox_override("panel", _default_stylebox.duplicate())
		return

	var style := StyleBoxFlat.new()
	style.bg_color = character_data.dialogue_bg_color
	style.border_color = character_data.dialogue_border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)


func show_choices(options: Array, speaker_color: Color = Color.WHITE) -> void:
	visible = true
	is_active = false
	_in_choice_mode = true
	name_label.text = ""
	text_label.visible = false
	if advance_indicator:
		advance_indicator.visible = false

	# Clear old buttons
	for child in _choice_container.get_children():
		child.queue_free()

	# Create choice buttons
	for option in options:
		var btn = Button.new()
		btn.text = "  %s" % option.text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(0.35, 0.28, 0.2))
		var flag = option.flag
		btn.pressed.connect(_select_choice.bind(flag))
		_choice_container.add_child(btn)

	_choice_container.visible = true


func _select_choice(flag: String) -> void:
	for child in _choice_container.get_children():
		child.queue_free()
	_choice_container.visible = false
	text_label.visible = true
	_in_choice_mode = false
	visible = false
	is_active = false
	EventBus.choice_made.emit(flag)
