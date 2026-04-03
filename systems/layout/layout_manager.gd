extends RefCounted

## Manages layout transitions between three panel modes:
## - "fullscreen": cinematic panel fills the space, board hidden
## - "split": both panels share equal space
## - "board_only": board panel fills the space, cinematic hidden
##
## Uses Tweens on size_flags_stretch_ratio for animated transitions.
## Standalone — no EventBus dependency. The caller wires signals as needed.

signal transition_finished(mode: String)

const MODES := ["fullscreen", "split", "board_only"]

## The minimum stretch ratio used instead of 0.0 to avoid layout collapse.
const MIN_RATIO := 0.001

var _cinematic_panel: PanelContainer = null
var _board_panel: PanelContainer = null
var _separator: Control = null
var _current_mode: String = "split"
var _layout_tween: Tween = null
var _transitioning: bool = false
var _tree: SceneTree = null


func setup(cinematic_panel: PanelContainer, board_panel: PanelContainer, separator: Control) -> void:
	_cinematic_panel = cinematic_panel
	_board_panel = board_panel
	_separator = separator
	# Cache the tree from one of the panels so we can create tweens
	_tree = cinematic_panel.get_tree()


func get_current_mode() -> String:
	return _current_mode


func is_transitioning() -> bool:
	return _transitioning


func set_instant(mode: String) -> void:
	## Snap to a layout mode without animation.
	if mode not in MODES:
		push_error("LayoutManager: unknown mode '%s'" % mode)
		return
	_current_mode = mode
	_apply_instant()


func transition_to(mode: String, duration: float = 0.8) -> void:
	## Animated transition to a layout mode. Emits transition_finished when done.
	if mode not in MODES:
		push_error("LayoutManager: unknown mode '%s'" % mode)
		return
	if mode == _current_mode:
		transition_finished.emit(mode)
		return

	_kill_tween()
	_transitioning = true
	_current_mode = mode

	# Make both panels visible during animation so the tween is smooth
	_cinematic_panel.visible = true
	_board_panel.visible = true

	var target_cinematic: float = _cinematic_ratio_for(mode)
	var target_board: float = _board_ratio_for(mode)

	# Show separator early for split mode
	if mode == "split":
		_separator.visible = true

	_layout_tween = _cinematic_panel.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_layout_tween.tween_property(_cinematic_panel, "size_flags_stretch_ratio", target_cinematic, duration)
	_layout_tween.parallel().tween_property(_board_panel, "size_flags_stretch_ratio", target_board, duration)
	await _layout_tween.finished

	# After animation: hide collapsed panel and separator
	_apply_visibility()
	_transitioning = false
	transition_finished.emit(mode)


# -- Private ------------------------------------------------------------------

func _apply_instant() -> void:
	_cinematic_panel.size_flags_stretch_ratio = _cinematic_ratio_for(_current_mode)
	_board_panel.size_flags_stretch_ratio = _board_ratio_for(_current_mode)
	_apply_visibility()


func _apply_visibility() -> void:
	match _current_mode:
		"fullscreen":
			_cinematic_panel.visible = true
			_board_panel.visible = false
			_separator.visible = false
		"split":
			_cinematic_panel.visible = true
			_board_panel.visible = true
			_separator.visible = true
		"board_only":
			_cinematic_panel.visible = false
			_board_panel.visible = true
			_separator.visible = false


func _cinematic_ratio_for(mode: String) -> float:
	match mode:
		"fullscreen": return 1.0
		"split": return 1.0
		"board_only": return MIN_RATIO
	return 1.0


func _board_ratio_for(mode: String) -> float:
	match mode:
		"fullscreen": return MIN_RATIO
		"split": return 1.0
		"board_only": return 1.0
	return 1.0


func _kill_tween() -> void:
	if _layout_tween and _layout_tween.is_valid():
		_layout_tween.kill()
	_layout_tween = null
