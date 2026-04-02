class_name PlacementEffects
extends RefCounted


static func apply(effect_name: String, piece: Control, intensity: float, all_pieces: Array) -> Tween:
	var bus = piece.get_node_or_null("/root/EventBus")
	if bus:
		bus.emit_signal("effect_triggered", effect_name, intensity)

	match effect_name:
		"rotate":
			return _rotate(piece, intensity)
		"slam":
			return _slam(piece, intensity)
		"vibrate":
			return _vibrate(piece, intensity)
		"shockwave":
			return _shockwave(piece, intensity, all_pieces)
		"bounce":
			return _bounce(piece, intensity)
	return null


static func _rotate(piece: Control, intensity: float) -> Tween:
	var tween = piece.create_tween()
	tween.tween_property(piece, "rotation", TAU * intensity, 0.6)
	tween.tween_property(piece, "rotation", 0.0, 0.25)
	return tween


static func _slam(piece: Control, intensity: float) -> Tween:
	var tween = piece.create_tween()
	tween.tween_property(piece, "scale", Vector2(1.5, 1.5) * intensity, 0.15)
	tween.tween_property(piece, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	return tween


static func _vibrate(piece: Control, intensity: float) -> Tween:
	var tween = piece.create_tween()
	var original = piece.position
	var amp = 5.0 * intensity
	for i in range(8):
		var offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		tween.tween_property(piece, "position", original + offset, 0.06)
	tween.tween_property(piece, "position", original, 0.06)
	return tween


static func _shockwave(piece: Control, intensity: float, all_pieces: Array) -> Tween:
	# Radial shockwave: all other pieces get pushed AWAY from this piece simultaneously
	var origin = piece.global_position + piece.size / 2.0
	var push_base = 20.0 * intensity

	var push_data: Array = []  # [{node, original_pos, push_offset}]

	for other in all_pieces:
		if other == piece or not is_instance_valid(other):
			continue

		var other_center = other.global_position + other.size / 2.0
		var diff = other_center - origin
		var distance = diff.length()
		if distance < 1.0:
			continue

		var direction = diff.normalized()
		# Inverse square falloff: closer = bigger push
		var strength = clamp(push_base * (150.0 / max(distance, 30.0)), 2.0, push_base * 2.0)
		var push_offset = direction * strength
		var original_pos = other.position

		push_data.append({"node": other, "original": original_pos, "offset": push_offset})

	if push_data.is_empty():
		return null

	# Single tween with two chained parallel phases
	var tween = piece.create_tween().set_parallel(true)

	# Phase 1: push all outward simultaneously
	for d in push_data:
		tween.tween_property(d.node, "position", d.original + d.offset, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Phase 2: spring back simultaneously (chained after phase 1)
	tween.chain()
	for d in push_data:
		tween.tween_property(d.node, "position", d.original, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	return tween


static func _bounce(piece: Control, intensity: float) -> Tween:
	var tween = piece.create_tween()
	var target_y = piece.position.y
	tween.tween_property(piece, "position:y", target_y - 20.0 * intensity, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "position:y", target_y, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	return tween
