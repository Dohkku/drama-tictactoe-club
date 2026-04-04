class_name BackgroundManager
extends Control

## Manages different types of backgrounds: static images, animated textures, or video.

var _current_bg_node: Node = null


func set_background(source: Variant) -> void:
	## source can be:
	## - Color: solid color background
	## - String (path): ".png", ".jpg", ".ogv" (video), etc.
	## - Texture2D: direct texture assignment
	
	_clear_current()
	
	if source is Color:
		_setup_color(source)
	elif source is String:
		_setup_from_path(source)
	elif source is Texture2D:
		_setup_texture(source)


func _clear_current() -> void:
	if _current_bg_node:
		_current_bg_node.queue_free()
		_current_bg_node = null


func _setup_color(color: Color) -> void:
	var cr := ColorRect.new()
	cr.color = color
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cr)
	_current_bg_node = cr


func _setup_texture(tex: Texture2D) -> void:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tr)
	_current_bg_node = tr


func set_gradient(top_color: Color, bottom_color: Color) -> void:
	_clear_current()
	var grad := _GradientBG.new()
	grad.top_color = top_color
	grad.bottom_color = bottom_color
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(grad)
	_current_bg_node = grad


func _setup_from_path(path: String) -> void:
	# Support "gradient:top_hex:bottom_hex" syntax
	if path.begins_with("gradient:"):
		var parts: PackedStringArray = path.split(":")
		if parts.size() >= 3:
			set_gradient(Color.html(parts[1]), Color.html(parts[2]))
			return
	if path.begins_with("#"):
		_setup_color(Color.html(path))
		return
		
	if not FileAccess.file_exists(path):
		push_warning("BackgroundManager: file not found at %s" % path)
		return
		
	var ext = path.get_extension().to_lower()
	match ext:
		"png", "jpg", "jpeg", "webp":
			var tex = load(path)
			if tex: _setup_texture(tex)
		"ogv": # Godot's native video format
			_setup_video(path)
		_:
			push_warning("BackgroundManager: unsupported extension '%s'" % ext)


func _setup_video(path: String) -> void:
	var vp := VideoStreamPlayer.new()
	vp.stream = load(path)
	vp.autoplay = true
	vp.loop = true
	vp.expand = true
	vp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vp)
	_current_bg_node = vp
	vp.play()


class _GradientBG extends Control:
	var top_color: Color = Color.BLACK
	var bottom_color: Color = Color.BLACK

	func _draw() -> void:
		var steps: int = 32
		var h: float = size.y / float(steps)
		for i in steps:
			var t: float = float(i) / float(steps)
			var col: Color = top_color.lerp(bottom_color, t)
			draw_rect(Rect2(0, i * h, size.x, h + 1.0), col)
