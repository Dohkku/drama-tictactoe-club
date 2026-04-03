extends Control

const CharacterSlotScene = preload("res://cinematic/character_slot.tscn")
const CameraEffectsScript = preload("res://cinematic/camera_effects.gd")
const CinematicCameraScript = preload("res://cinematic/cinematic_camera.gd")
const SpeedLinesEffectScript = preload("res://cinematic/speed_lines_effect.gd")

## Named stage positions as fractions of stage width (0.0 = left edge, 1.0 = right edge)
const POSITIONS = {
	"far_left": 0.08,
	"left": 0.22,
	"center_left": 0.36,
	"center": 0.50,
	"center_right": 0.64,
	"right": 0.78,
	"far_right": 0.92,
}

const CHAR_ASPECT := 0.55       # Character width / height ratio (fixed, never squishes)
const CHAR_HEIGHT_RATIO := 0.85 # Character height as fraction of stage height
const MOVE_DURATION := 0.5

var characters_on_stage: Dictionary = {}    # character_id -> CharacterSlot node
var _character_registry: Dictionary = {}    # character_id -> CharacterData resource
var _character_positions: Dictionary = {}   # character_id -> position name
var _character_depth: Dictionary = {}       # character_id -> float (1.0 = normal, >1 = closer, <1 = farther)
var _camera_active: bool = false            # True during close_up/pull_back to avoid resize conflicts
var camera_effects: Node = null
var _camera = null   # CinematicCamera instance
var _speed_lines = null  # SpeedLinesEffect node

@onready var background: Control = %Background
@onready var character_layer: Control = %CharacterLayer
@onready var speed_lines = %SpeedLinesEffect


func _ready() -> void:
	camera_effects = Node.new()
	camera_effects.set_script(CameraEffectsScript)
	add_child(camera_effects)
	camera_effects.setup(character_layer, self)

	# Virtual camera system
	_camera = CinematicCameraScript.new()
	_camera.setup(character_layer, self)

	# Speed lines reference from scene tree
	_speed_lines = speed_lines

	character_layer.resized.connect(_on_layer_resized)

	# Initial default background
	background.set_background(Color(0.95, 0.91, 0.85))


func register_character(data: Resource) -> void:
	_character_registry[data.character_id] = data


func get_character_data(character_id: String) -> Resource:
	return _character_registry.get(character_id)


# --- Enter / Exit ---

func enter_character(character_id: String, position_name: String = "center", enter_from: String = "") -> void:
	if characters_on_stage.has(character_id):
		return
	if not _character_registry.has(character_id):
		push_warning("Character not registered: %s" % character_id)
		return
	if character_id == "player":
		return  # No visual representation for player

	var data = _character_registry[character_id]
	var char_slot = CharacterSlotScene.instantiate()
	character_layer.add_child(char_slot)

	var pos_fraction = POSITIONS.get(position_name, 0.5)
	_apply_slot_position(char_slot, pos_fraction)

	characters_on_stage[character_id] = char_slot
	_character_positions[character_id] = position_name
	_character_depth[character_id] = 1.0

	# Determine enter direction: explicit, or auto from position
	var from_dir = enter_from
	if from_dir == "":
		from_dir = "left" if pos_fraction < 0.5 else "right"

	await char_slot.enter_character(data, from_dir)
	_reposition_all()  # Adapt sizes if needed for multiple characters
	EventBus.character_entered.emit(character_id)


func exit_character(character_id: String, direction: String = "") -> void:
	if not characters_on_stage.has(character_id):
		return

	var char_slot = characters_on_stage[character_id]
	if direction == "":
		var pos_name = _character_positions.get(character_id, "center")
		var fraction = POSITIONS.get(pos_name, 0.5)
		direction = "left" if fraction < 0.5 else "right"

	await char_slot.exit_character(direction)
	char_slot.queue_free()
	characters_on_stage.erase(character_id)
	_character_positions.erase(character_id)
	_character_depth.erase(character_id)
	_reposition_all()  # Re-adapt sizes after removal
	EventBus.character_exited.emit(character_id)


# --- Movement ---

func move_character(character_id: String, new_position: String) -> void:
	if not characters_on_stage.has(character_id):
		return
	var char_slot = characters_on_stage[character_id]
	var pos_fraction = POSITIONS.get(new_position, 0.5)
	var target = _calc_slot_position(pos_fraction)

	var tween = char_slot.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(char_slot, "position", target, MOVE_DURATION)
	_character_positions[character_id] = new_position
	await tween.finished


# --- Depth (simulated z-depth) ---

func set_character_depth(character_id: String, depth: float, duration: float = 0.4) -> void:
	## depth > 1.0 = closer (bigger, lower on screen)
	## depth < 1.0 = farther (smaller, higher on screen)
	## depth = 1.0 = normal
	if not characters_on_stage.has(character_id):
		return

	_character_depth[character_id] = depth
	var slot = characters_on_stage[character_id]
	slot.pivot_offset = slot.size / 2.0

	# Scale for depth
	var target_scale = Vector2(depth, depth)

	# Y offset: closer = lower, farther = higher
	var base_pos = _calc_slot_position(POSITIONS.get(_character_positions.get(character_id, "center"), 0.5))
	var y_shift = (depth - 1.0) * 30.0  # +30px when depth=2, -30px when depth=0
	var target_pos = Vector2(base_pos.x, base_pos.y + y_shift)

	var tween = slot.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD).set_parallel(true)
	tween.tween_property(slot, "scale", target_scale, duration)
	tween.tween_property(slot, "position", target_pos, duration)

	# Z-order: closer characters in front
	slot.z_index = int(depth * 10)


# --- Expressions and state ---

func set_character_expression(character_id: String, expression: String) -> void:
	if characters_on_stage.has(character_id):
		characters_on_stage[character_id].set_expression(expression)


func set_character_speaking(character_id: String, speaking: bool) -> void:
	for id in characters_on_stage:
		characters_on_stage[id].set_speaking(id == character_id and speaking)


func set_body_state(character_id: String, state: String) -> void:
	if characters_on_stage.has(character_id):
		characters_on_stage[character_id].set_body_state(state)


func set_look_at(character_id: String, target: String) -> void:
	if not characters_on_stage.has(character_id):
		return

	var slot = characters_on_stage[character_id]

	var resolved = target
	if characters_on_stage.has(target):
		var my_pos = _character_positions.get(character_id, "center")
		var their_pos = _character_positions.get(target, "center")
		var my_frac = POSITIONS.get(my_pos, 0.5)
		var their_frac = POSITIONS.get(their_pos, 0.5)
		resolved = "right" if their_frac > my_frac else "left"

	slot.set_look_direction(resolved)
	slot.look_target = target


func set_talk_target(character_id: String, target: String) -> void:
	if characters_on_stage.has(character_id):
		characters_on_stage[character_id].set_talk_to(target)
		set_look_at(character_id, target)


func set_focus(character_id: String) -> void:
	for id in characters_on_stage:
		characters_on_stage[id].set_focus(id == character_id)


func clear_focus() -> void:
	for id in characters_on_stage:
		characters_on_stage[id].set_focus(true)


# --- Camera / Zoom (virtual camera on CharacterLayer) ---

func camera_close_up(character_id: String, zoom: float = 1.4, _duration: float = 0.5) -> void:
	if not characters_on_stage.has(character_id):
		return
	_camera_active = true
	var slot = characters_on_stage[character_id]
	_camera.focus_character(slot.position, slot.size, zoom)

	# Dim non-target characters for cinematic focus
	var mode = _camera.get_mode()
	var dim_dur = CinematicCameraScript.SNAPPY_DURATION if mode == CinematicCameraScript.Mode.SNAPPY else CinematicCameraScript.SMOOTH_DURATION
	for id in characters_on_stage:
		if id != character_id:
			var other = characters_on_stage[id]
			var tween = other.create_tween().set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(other, "modulate:a", 0.3, dim_dur)


func camera_pull_back(character_id: String, zoom: float = 0.8, _duration: float = 0.5) -> void:
	if not characters_on_stage.has(character_id):
		return
	_camera_active = true
	var slot = characters_on_stage[character_id]
	_camera.focus_character(slot.position, slot.size, zoom)


func camera_snap_to(character_id: String, zoom: float = 1.4) -> void:
	## Snap-zoom to a character using SNAPPY mode with speed lines.
	if not characters_on_stage.has(character_id):
		return
	_camera_active = true
	var slot = characters_on_stage[character_id]
	_camera.focus_character(slot.position, slot.size, zoom, CinematicCameraScript.Mode.SNAPPY)
	if _speed_lines:
		_speed_lines.play()

	# Dim non-target characters quickly
	for id in characters_on_stage:
		if id != character_id:
			var other = characters_on_stage[id]
			var tween = other.create_tween().set_ease(Tween.EASE_OUT)
			tween.tween_property(other, "modulate:a", 0.3, CinematicCameraScript.SNAPPY_DURATION)


func camera_reset(_duration: float = 0.4) -> void:
	_camera.reset()

	# Restore all character modulate
	var mode = _camera.get_mode()
	var reset_dur = CinematicCameraScript.SNAPPY_DURATION if mode == CinematicCameraScript.Mode.SNAPPY else CinematicCameraScript.SMOOTH_DURATION
	for id in characters_on_stage:
		var slot = characters_on_stage[id]
		_character_depth[id] = 1.0
		var tween = slot.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(slot, "modulate:a", 1.0, reset_dur)
	_camera_active = false


func set_camera_mode(mode_str: String) -> void:
	match mode_str.to_lower():
		"snappy":
			_camera.set_mode(CinematicCameraScript.Mode.SNAPPY)
		"smooth", _:
			_camera.set_mode(CinematicCameraScript.Mode.SMOOTH)


func get_camera():
	return _camera


# --- Stage management ---

func set_background(source: Variant) -> void:
	background.set_background(source)


func clear_stage() -> void:
	for id in characters_on_stage.keys():
		characters_on_stage[id].queue_free()
	characters_on_stage.clear()
	_character_positions.clear()
	_character_depth.clear()
	if _camera:
		_camera.reset()
	_camera_active = false


func get_character_color(character_id: String) -> Color:
	if _character_registry.has(character_id):
		return _character_registry[character_id].color
	return Color.WHITE


func get_characters_on_stage() -> Array:
	return characters_on_stage.keys()


# --- Positioning helpers ---

func _apply_slot_position(slot: Control, fraction: float) -> void:
	slot.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var pos = _calc_slot_position(fraction)
	var sz = _calc_slot_size()
	slot.position = pos
	slot.size = sz
	slot.pivot_offset = sz / 2.0


func _calc_slot_position(fraction: float) -> Vector2:
	var layer_size = character_layer.size
	var sz = _calc_slot_size()
	var x = layer_size.x * fraction - sz.x / 2.0
	var y = (layer_size.y - sz.y) / 2.0
	return Vector2(x, y)


func _calc_slot_size() -> Vector2:
	var layer_size = character_layer.size
	# Height-based sizing: aspect ratio is ALWAYS preserved
	var h = layer_size.y * CHAR_HEIGHT_RATIO
	var w = h * CHAR_ASPECT

	# Scale down if too many characters for available width
	var char_count = max(1, characters_on_stage.size())
	var max_w = layer_size.x / max(char_count, 2.0) * 0.85
	if w > max_w:
		w = max_w
		h = w / CHAR_ASPECT

	return Vector2(w, h)


func _reposition_all() -> void:
	var count = characters_on_stage.size()
	for id in characters_on_stage:
		var slot = characters_on_stage[id]
		var pos_name = _character_positions.get(id, "center")
		var fraction = POSITIONS.get(pos_name, 0.5)
		# Auto-center when only one character on stage
		if count == 1:
			fraction = 0.5
		_apply_slot_position(slot, fraction)
		var depth = _character_depth.get(id, 1.0)
		if depth != 1.0:
			slot.scale = Vector2(depth, depth)


func _on_layer_resized() -> void:
	if not _camera_active:
		_reposition_all()
