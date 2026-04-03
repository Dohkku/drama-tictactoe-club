extends RefCounted

## Manages layout transitions between panel modes.
## Panels are positioned manually inside a clipped parent Control.
## Collapsed panels have width 0 — clip_contents hides their content.
## No visibility toggling = no snapping.

signal transition_finished(mode: String)

const MODES := ["fullscreen", "split", "board_only"]

var _parent: Control = null
var _cinematic: Control = null
var _board: Control = null
var _separator: Control = null
var _current_mode: String = "split"
var _tween: Tween = null
var _transitioning: bool = false
var split_ratio: float = 0.5
var separator_width: float = 6.0
var separator_enabled: bool = true


func setup(parent: Control, cinematic: Control, board: Control, sep: Control) -> void:
	_parent = parent
	_cinematic = cinematic
	_board = board
	_separator = sep
	# Clip everything — panels at width 0 are invisible
	_parent.clip_contents = true
	_cinematic.clip_contents = true
	_board.clip_contents = true
	_parent.resized.connect(func(): _apply_instant() if not _transitioning else null)


func get_current_mode() -> String:
	return _current_mode


func is_transitioning() -> bool:
	return _transitioning


func set_instant(mode: String) -> void:
	if mode not in MODES:
		return
	_current_mode = mode
	_apply_instant()


func transition_to(mode: String, duration: float = 0.8) -> void:
	if mode not in MODES:
		return
	if mode == _current_mode:
		transition_finished.emit(mode)
		return

	_kill_tween()
	_transitioning = true
	_current_mode = mode

	var t: Dictionary = _calc(mode)

	_tween = _parent.create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	_tween.tween_property(_cinematic, "position:x", t.cx, duration)
	_tween.tween_property(_cinematic, "size:x", t.cw, duration)
	_tween.tween_property(_board, "position:x", t.bx, duration)
	_tween.tween_property(_board, "size:x", t.bw, duration)
	_tween.tween_property(_separator, "position:x", t.sx, duration)
	_tween.tween_property(_separator, "modulate:a", t.sa, duration * 0.6)

	await _tween.finished
	_transitioning = false
	transition_finished.emit(mode)


func _apply_instant() -> void:
	var t: Dictionary = _calc(_current_mode)
	var h: float = _parent.size.y
	_cinematic.position = Vector2(t.cx, 0)
	_cinematic.size = Vector2(t.cw, h)
	_board.position = Vector2(t.bx, 0)
	_board.size = Vector2(t.bw, h)
	_separator.position = Vector2(t.sx, 0)
	_separator.size = Vector2(separator_width, h)
	_separator.modulate.a = t.sa


func _calc(mode: String) -> Dictionary:
	var w: float = _parent.size.x
	var sw: float = separator_width if separator_enabled else 0.0
	# cx=cinematic x, cw=cinematic width, bx=board x, bw=board width, sx=sep x, sa=sep alpha
	match mode:
		"fullscreen":
			return {"cx": 0.0, "cw": w, "bx": w, "bw": 0.0, "sx": w, "sa": 0.0}
		"board_only":
			return {"cx": 0.0, "cw": 0.0, "bx": 0.0, "bw": w, "sx": 0.0, "sa": 0.0}
		_:  # split
			var cw: float = (w - sw) * split_ratio
			return {"cx": 0.0, "cw": cw, "bx": cw + sw, "bw": w - cw - sw, "sx": cw, "sa": 1.0}


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
