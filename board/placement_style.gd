class_name PlacementStyle
extends Resource

## How high (in pixels) the piece lifts before travelling.
@export var lift_height: float = 8.0
## Wind-up distance as a fraction of the total travel distance (0-1).
@export var anticipation_factor: float = 0.3
## Duration of the arc flight to the target cell.
@export var arc_duration: float = 0.25
## Duration of the final settle/snap into place.
@export var settle_duration: float = 0.1


static func _make(lift: float, anticipation: float, arc: float, settle: float) -> Resource:
	var style = load("res://board/placement_style.gd").new()
	style.lift_height = lift
	style.anticipation_factor = anticipation
	style.arc_duration = arc
	style.settle_duration = settle
	return style


static func gentle() -> Resource:
	return _make(8.0, 0.2, 0.6, 0.25)

static func slam() -> Resource:
	return _make(14.0, 0.35, 0.45, 0.18)

static func spinning() -> Resource:
	return _make(8.0, 0.2, 0.6, 0.25)

static func dramatic() -> Resource:
	return _make(18.0, 0.45, 0.5, 0.22)

static func nervous() -> Resource:
	return _make(5.0, 0.15, 0.7, 0.3)
