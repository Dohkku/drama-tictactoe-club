class_name CinematicCamera
extends RefCounted

## Virtual camera for the Control-based cinematic stage.
## Manipulates the CharacterLayer's position, scale, and pivot_offset
## to simulate pan/zoom without requiring a Camera2D node.
##
## Math: a local point `p` maps to parent-space as:
##   parent = position + pivot + scale * (p - pivot)
## To center `world_pos` on screen at a given zoom:
##   pivot  = world_pos          (scale around the target)
##   position = stage_center - world_pos   (shift so target lands at center)
## At zoom=1 + position=0 + any pivot, every point maps to itself (identity).

enum Mode { SMOOTH, SNAPPY }

var _layer: Control = null
var _stage: Control = null
var _mode: Mode = Mode.SMOOTH
var _current_tween: Tween = null
var _default_zoom: float = 1.0

# Timing constants
const SMOOTH_DURATION := 0.6
const SNAPPY_DURATION := 0.2


func setup(layer: Control, stage: Control) -> void:
	_layer = layer
	_stage = stage


func focus_character(char_position: Vector2, char_size: Vector2, zoom: float = 1.3, mode: int = -1) -> void:
	## Zoom into a character so they appear centered on stage.
	var center = char_position + char_size / 2.0
	focus_position(center, zoom, mode)


func focus_position(world_pos: Vector2, zoom: float = 1.3, mode: int = -1) -> void:
	## Zoom into an arbitrary position within the layer.
	if not _layer or not _stage:
		return

	var resolved_mode := _resolve_mode(mode)
	_kill_current_tween()

	var stage_center := _stage.size / 2.0

	# 1. Set pivot to the target point INSTANTLY, and compensate position
	#    so nothing visually jumps. With uniform scale s:
	#    pos_new = pos_old + (pivot_old - pivot_new) * (1.0 - s)
	var old_pivot := _layer.pivot_offset
	var old_scale := _layer.scale.x
	_layer.pivot_offset = world_pos
	_layer.position += (old_pivot - world_pos) * (1.0 - old_scale)

	# 2. Target state: pivot=world_pos, scale=zoom, position centers the target.
	#    parent(world_pos) = position + pivot + scale*(world_pos - pivot)
	#                      = position + world_pos
	#    Want it at stage_center => position = stage_center - world_pos
	var target_position := stage_center - world_pos

	var tween := _layer.create_tween()
	_current_tween = tween
	_apply_timing(tween, resolved_mode)
	tween.set_parallel(true)
	tween.tween_property(_layer, "scale", Vector2(zoom, zoom), _duration(resolved_mode))
	tween.tween_property(_layer, "position", target_position, _duration(resolved_mode))


func reset(mode: int = -1) -> void:
	## Reset camera to default: no zoom, centered, identity transform.
	if not _layer or not _stage:
		return

	var resolved_mode := _resolve_mode(mode)
	_kill_current_tween()

	var stage_center := _stage.size / 2.0

	# Snap pivot to center, compensate position
	var old_pivot := _layer.pivot_offset
	var old_scale := _layer.scale.x
	_layer.pivot_offset = stage_center
	_layer.position += (old_pivot - stage_center) * (1.0 - old_scale)

	var tween := _layer.create_tween()
	_current_tween = tween
	_apply_timing(tween, resolved_mode)
	tween.set_parallel(true)
	tween.tween_property(_layer, "scale", Vector2(_default_zoom, _default_zoom), _duration(resolved_mode))
	tween.tween_property(_layer, "position", Vector2.ZERO, _duration(resolved_mode))


func set_mode(mode: Mode) -> void:
	_mode = mode


func get_mode() -> Mode:
	return _mode


func is_active() -> bool:
	return _layer != null and _layer.scale != Vector2(_default_zoom, _default_zoom)


# ---- Internal helpers ----

func _resolve_mode(mode: int) -> Mode:
	if mode >= 0:
		return mode as Mode
	return _mode


func _duration(mode: Mode) -> float:
	return SNAPPY_DURATION if mode == Mode.SNAPPY else SMOOTH_DURATION


func _apply_timing(tween: Tween, mode: Mode) -> void:
	if mode == Mode.SNAPPY:
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)


func _kill_current_tween() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null
