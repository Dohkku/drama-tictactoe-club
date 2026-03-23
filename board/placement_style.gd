class_name PlacementStyle
extends Resource

@export var move_duration: float = 0.35
@export var move_ease: Tween.EaseType = Tween.EASE_OUT
@export var move_trans: Tween.TransitionType = Tween.TRANS_BACK
@export var effects: Array[String] = []
@export var intensity: float = 1.0
@export var move_rotation: float = 0.0


static func create(fx: Array[String], duration: float = 0.35, rot: float = 0.0, intense: float = 1.0) -> Resource:
	var style = load("res://board/placement_style.gd").new()
	style.effects = fx
	style.move_duration = duration
	style.move_rotation = rot
	style.intensity = intense
	return style


static func gentle() -> Resource:
	return create(["bounce"], 0.6, 0.0, 0.5)

static func slam() -> Resource:
	return create(["slam", "shockwave"], 0.45, 0.0, 1.2)

static func spinning() -> Resource:
	return create(["rotate", "bounce"], 0.55, 720.0, 1.0)

static func dramatic() -> Resource:
	return create(["slam", "shockwave", "vibrate"], 0.35, 0.0, 1.5)

static func nervous() -> Resource:
	return create(["vibrate"], 0.7, 0.0, 0.7)
