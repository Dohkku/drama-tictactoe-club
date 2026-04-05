extends Control

signal entrance_finished()
signal exit_finished()

var character_data: Resource = null
var current_expression: String = "neutral"
var is_speaking: bool = false
var _base_position: Vector2 = Vector2.ZERO

# --- Rich state ---
var body_state: String = "idle"
var look_target: String = ""       # character_id, "left", "right", "away", ""
var talk_target: String = ""       # character_id being addressed

const ENTER_DURATION := 0.5
const EXIT_DURATION := 0.4
const EXPRESSION_FADE_DURATION := 0.15

@onready var portrait_rect: TextureRect = %PortraitRect
@onready var name_label: Label = %NameLabel
@onready var expression_label: Label = %ExpressionLabel

var _state_label: Label
var _look_indicator: Label
var _body_tween: Tween = null

# Crop base transforms (set from CharacterData portrait_zoom/offset)
var _crop_base_scale: Vector2 = Vector2.ONE
var _crop_base_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	resized.connect(_update_pivot)
	_update_pivot()

	# VBoxContainer order: NameLabel, _state_label, _look_indicator, PortraitRect
	# Name and debug labels at TOP so they're never hidden by dialogue box

	# Move NameLabel to top
	$VBoxContainer.move_child(name_label, 0)

	_state_label = Label.new()
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.add_theme_font_size_override("font_size", 9)
	_state_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_state_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_state_label.add_theme_constant_override("outline_size", 2)
	$VBoxContainer.add_child(_state_label)
	$VBoxContainer.move_child(_state_label, 1)

	_look_indicator = Label.new()
	_look_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_look_indicator.add_theme_font_size_override("font_size", 8)
	_look_indicator.add_theme_color_override("font_color", Color(1, 1, 0.7, 0.6))
	_look_indicator.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_look_indicator.add_theme_constant_override("outline_size", 2)
	$VBoxContainer.add_child(_look_indicator)
	$VBoxContainer.move_child(_look_indicator, 2)

	_update_state_display()


var show_debug_border: bool = true

func _update_pivot() -> void:
	pivot_offset = size / 2.0


func _draw() -> void:
	if show_debug_border and character_data:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0, 1, 0, 0.7), false, 2.0)
		# Corner marks
		var corner_len: float = minf(size.x, size.y) * 0.1
		var col := Color(0, 1, 0, 0.9)
		# Top-left
		draw_line(Vector2.ZERO, Vector2(corner_len, 0), col, 2.0)
		draw_line(Vector2.ZERO, Vector2(0, corner_len), col, 2.0)
		# Top-right
		draw_line(Vector2(size.x, 0), Vector2(size.x - corner_len, 0), col, 2.0)
		draw_line(Vector2(size.x, 0), Vector2(size.x, corner_len), col, 2.0)
		# Bottom-left
		draw_line(Vector2(0, size.y), Vector2(corner_len, size.y), col, 2.0)
		draw_line(Vector2(0, size.y), Vector2(0, size.y - corner_len), col, 2.0)
		# Bottom-right
		draw_line(Vector2(size.x, size.y), Vector2(size.x - corner_len, size.y), col, 2.0)
		draw_line(Vector2(size.x, size.y), Vector2(size.x, size.y - corner_len), col, 2.0)


func enter_character(data: Resource, from_direction: String = "right") -> void:
	character_data = data
	visible = true
	_apply_expression("neutral")
	name_label.text = data.display_name

	if data.get("default_pose"):
		set_body_state(data.default_pose)
	if data.get("default_look"):
		set_look_direction(data.default_look)

	_base_position = position
	modulate.a = 0.0

	# Slide in from off-screen
	var slide_offset: float = 0.0
	if from_direction == "left":
		slide_offset = -size.x * 1.5
	elif from_direction == "right":
		slide_offset = size.x * 1.5
	var start_pos := Vector2(position.x + slide_offset, position.y)
	position = start_pos

	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, ENTER_DURATION * 0.6)
	tween.tween_property(self, "position", _base_position, ENTER_DURATION)
	await tween.finished
	position = _base_position
	entrance_finished.emit()


func exit_character(to_direction: String = "right") -> void:
	_stop_body_tween()

	var slide_offset: float = 0.0
	if to_direction == "left":
		slide_offset = -size.x * 1.5
	elif to_direction == "right":
		slide_offset = size.x * 1.5
	var target_pos := Vector2(position.x + slide_offset, position.y)

	var tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, EXIT_DURATION)
	if slide_offset != 0.0:
		tween.tween_property(self, "position", target_pos, EXIT_DURATION)
	await tween.finished

	character_data = null
	visible = false
	position = _base_position
	body_state = "idle"
	look_target = ""
	talk_target = ""
	exit_finished.emit()


func set_expression(expr_name: String) -> void:
	if expr_name == current_expression:
		return
	var tween := create_tween()
	tween.tween_property(portrait_rect, "modulate:a", 0.7, EXPRESSION_FADE_DURATION)
	tween.tween_callback(_apply_expression.bind(expr_name))
	tween.tween_property(portrait_rect, "modulate:a", 1.0, EXPRESSION_FADE_DURATION)


func set_speaking(speaking: bool) -> void:
	is_speaking = speaking
	var target_scale := Vector2(1.05, 1.05) if speaking else Vector2.ONE
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", target_scale, 0.15)


# --- Rich state methods ---

func set_body_state(new_state: String) -> void:
	if body_state == new_state:
		return
	body_state = new_state
	_stop_body_tween()
	_apply_body_state()
	_update_state_display()


func set_look_direction(target: String) -> void:
	look_target = target
	_apply_look_direction()
	_update_state_display()


func set_talk_to(target: String) -> void:
	talk_target = target
	_update_state_display()


func set_focus(focused: bool) -> void:
	## Highlight this character (dim others should be handled by stage)
	var target_mod = 1.0 if focused else 0.5
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", target_mod, 0.2)


# --- Visual state application ---

func _apply_body_state() -> void:
	# Reset to crop base first — no rotation ever
	portrait_rect.rotation = 0.0
	portrait_rect.scale = _crop_base_scale
	portrait_rect.position = _crop_base_position
	portrait_rect.modulate = Color.WHITE
	portrait_rect.pivot_offset = portrait_rect.size / 2.0

	match body_state:
		"idle":
			pass
		"thinking":
			# Darken slightly — introspective
			var tween := create_tween()
			tween.tween_property(portrait_rect, "modulate", Color(0.85, 0.85, 0.95), 0.3)
		"arms_crossed":
			portrait_rect.scale = _crop_base_scale * Vector2(0.95, 1.0)
		"leaning_forward":
			var tween := create_tween().set_ease(Tween.EASE_OUT)
			tween.tween_property(portrait_rect, "scale", _crop_base_scale * Vector2(1.08, 1.08), 0.3)
		"leaning_back":
			var tween := create_tween().set_ease(Tween.EASE_OUT)
			tween.tween_property(portrait_rect, "scale", _crop_base_scale * Vector2(0.92, 0.92), 0.3)
		"excited":
			# Bouncing loop + bright tint
			portrait_rect.modulate = Color(1.1, 1.1, 1.0)
			_body_tween = create_tween().set_loops()
			_body_tween.tween_property(portrait_rect, "position:y", _crop_base_position.y - 6.0, 0.2).set_ease(Tween.EASE_OUT)
			_body_tween.tween_property(portrait_rect, "position:y", _crop_base_position.y, 0.2).set_ease(Tween.EASE_IN)
		"tense":
			# Red tint + micro-vibration
			portrait_rect.modulate = Color(1.1, 0.9, 0.9)
			_body_tween = create_tween().set_loops()
			_body_tween.tween_property(portrait_rect, "position", _crop_base_position + Vector2(2, 0), 0.05)
			_body_tween.tween_property(portrait_rect, "position", _crop_base_position + Vector2(-2, 0), 0.05)
			_body_tween.tween_property(portrait_rect, "position", _crop_base_position, 0.05)
		"confident":
			var tween := create_tween().set_ease(Tween.EASE_OUT)
			tween.tween_property(portrait_rect, "scale", _crop_base_scale * Vector2(1.05, 1.05), 0.3)
			portrait_rect.modulate = Color(1.05, 1.05, 1.1)
		"defeated":
			# Desaturate + shrink — no rotation
			var tween := create_tween().set_ease(Tween.EASE_OUT)
			tween.tween_property(portrait_rect, "scale", _crop_base_scale * Vector2(0.88, 0.95), 0.4)
			tween.parallel().tween_property(portrait_rect, "modulate", Color(0.7, 0.7, 0.75), 0.4)


func _apply_look_direction() -> void:
	# Flip portrait horizontally based on look direction.
	# Default portraits face left, so "right" = flip on X axis.
	var target_scale_x: float = _crop_base_scale.x
	match look_target:
		"right":
			target_scale_x = -_crop_base_scale.x  # Flip to face right
		"left", "center", "":
			target_scale_x = _crop_base_scale.x   # Normal (faces left)
		"away":
			target_scale_x = _crop_base_scale.x

	var target_scale := Vector2(target_scale_x, _crop_base_scale.y)
	if portrait_rect.scale != target_scale:
		var tween := create_tween().set_ease(Tween.EASE_OUT)
		tween.tween_property(portrait_rect, "scale", target_scale, 0.2)

	rotation = 0.0
	portrait_rect.rotation = 0.0


func _stop_body_tween() -> void:
	if _body_tween and _body_tween.is_valid():
		_body_tween.kill()
		_body_tween = null
		# Reset portrait to crop base
		portrait_rect.position = _crop_base_position
		portrait_rect.scale = _crop_base_scale
		portrait_rect.rotation = 0.0


func _update_state_display() -> void:
	if _state_label:
		var parts: Array[String] = []
		if body_state != "idle":
			parts.append("[%s]" % body_state)
		if current_expression != "" and current_expression != "neutral":
			parts.append(current_expression)
		_state_label.text = " ".join(parts)
	if _look_indicator:
		var parts: Array[String] = []
		if look_target != "" and look_target != "center":
			parts.append("eyes → %s" % look_target)
		if talk_target != "":
			parts.append("to: %s" % talk_target)
		_look_indicator.text = " | ".join(parts)


func _apply_expression(expr_name: String) -> void:
	current_expression = expr_name
	expression_label.text = expr_name
	_update_state_display()

	if character_data == null:
		return

	# 1. Try to find a specific image for this expression
	var img = character_data.expression_images.get(expr_name)
	if img == null:
		# 2. Fallback to base portrait image
		img = character_data.portrait_image

	if img != null:
		portrait_rect.texture = img
		portrait_rect.modulate = Color.WHITE # Clear any previous tinting
	else:
		# 3. Last fallback: Generate a solid color texture from the character color
		var color = character_data.expressions.get(expr_name, character_data.color)
		_set_solid_color_fallback(color)

	_apply_portrait_crop()


func _apply_portrait_crop() -> void:
	if character_data == null:
		return

	var zoom: float = 1.0
	var offset: Vector2 = Vector2.ZERO
	if "portrait_zoom" in character_data:
		zoom = character_data.portrait_zoom
	if "portrait_offset" in character_data:
		offset = character_data.portrait_offset

	zoom = clampf(zoom, 0.5, 2.0)
	offset = Vector2(clampf(offset.x, -0.5, 0.5), clampf(offset.y, -0.5, 0.5))

	_crop_base_scale = Vector2(zoom, zoom)
	_crop_base_position = offset * portrait_rect.size

	portrait_rect.pivot_offset = portrait_rect.size / 2.0
	portrait_rect.scale = _crop_base_scale

	# Only apply position offset if non-zero (VBoxContainer manages position otherwise)
	if offset != Vector2.ZERO:
		portrait_rect.position += _crop_base_position

	# Never clip at slot level — the stage handles overflow clipping
	clip_children = CanvasItem.CLIP_CHILDREN_DISABLED


func _set_solid_color_fallback(color: Color) -> void:
	# Create a tiny 1x1 image and scale it to fill
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex = ImageTexture.create_from_image(img)
	portrait_rect.texture = tex
	portrait_rect.modulate = Color.WHITE
