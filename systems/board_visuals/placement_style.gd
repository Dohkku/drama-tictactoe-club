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
## Number of full rotations during the arc phase (0 = no spin).
@export var spin_rotations: float = 0.0
## Pixel range for jitter/shake during settle (0 = no shake).
@export var shake_amount: float = 0.0


static func _make(
	lift: float, anticipation: float, arc: float, settle: float,
	spin: float = 0.0, shake: float = 0.0
) -> Resource:
	var style = load("res://systems/board_visuals/placement_style.gd").new()
	style.lift_height = lift
	style.anticipation_factor = anticipation
	style.arc_duration = arc
	style.settle_duration = settle
	style.spin_rotations = spin
	style.shake_amount = shake
	return style


static func gentle() -> Resource:
	return _make(6.0, 0.1, 0.8, 0.3)

static func slam() -> Resource:
	return _make(30.0, 0.5, 0.2, 0.08)

static func spinning() -> Resource:
	return _make(12.0, 0.15, 0.7, 0.2, 2.0)

static func dramatic() -> Resource:
	return _make(50.0, 0.6, 0.6, 0.25)

static func nervous() -> Resource:
	return _make(4.0, 0.05, 0.35, 0.4, 0.0, 3.0)
