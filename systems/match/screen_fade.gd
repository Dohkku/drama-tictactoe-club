extends CanvasLayer

## Full-screen fade overlay for transitions between tournament events.
## Usage: add as child or autoload, then await fade_out() / fade_in().

var _rect: ColorRect = null
var _tween: Tween = null
var _faded: bool = false  # true when screen is fully black

signal fade_finished


func _ready() -> void:
	layer = 20
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)


func is_faded() -> bool:
	return _faded


func fade_out(duration: float = 0.5) -> void:
	## Fade screen to black. Awaitable.
	if _faded:
		return
	_kill_tween()
	_tween = _rect.create_tween()
	_tween.tween_property(_rect, "modulate:a", 1.0, duration)
	await _tween.finished
	_faded = true
	fade_finished.emit()


func fade_in(duration: float = 0.5) -> void:
	## Fade from black to transparent. Awaitable.
	if not _faded:
		return
	_kill_tween()
	_tween = _rect.create_tween()
	_tween.tween_property(_rect, "modulate:a", 0.0, duration)
	await _tween.finished
	_faded = false
	fade_finished.emit()


func fade_out_in(duration: float = 0.8) -> void:
	## Fade out then back in. Awaitable.
	var half := duration / 2.0
	_kill_tween()
	_faded = false  # Reset so fade_out doesn't bail
	_tween = _rect.create_tween()
	_tween.tween_property(_rect, "modulate:a", 1.0, half)
	_tween.tween_property(_rect, "modulate:a", 0.0, half)
	await _tween.finished
	_faded = false
	fade_finished.emit()


func set_black() -> void:
	## Instantly set to fully black (no animation). Use before first fade_in.
	_kill_tween()
	_rect.modulate.a = 1.0
	_faded = true


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
