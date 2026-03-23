extends Node

var _target: Control = null


func setup(target: Control) -> void:
	_target = target


func shake(intensity: float = 1.0, duration: float = 0.3) -> void:
	if not _target:
		return
	var original_pos := _target.position
	var tween := _target.create_tween()
	var steps := int(duration / 0.03)
	for i in range(steps):
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * intensity * 10.0
		tween.tween_property(_target, "position", original_pos + offset, 0.03)
	tween.tween_property(_target, "position", original_pos, 0.03)


func flash(color: Color = Color.WHITE, duration: float = 0.3) -> void:
	if not _target:
		return
	var flash_rect := ColorRect.new()
	flash_rect.color = color
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target.add_child(flash_rect)

	var tween := flash_rect.create_tween()
	tween.tween_property(flash_rect, "modulate:a", 0.0, duration)
	tween.tween_callback(flash_rect.queue_free)
