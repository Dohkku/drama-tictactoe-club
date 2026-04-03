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
## Stretch factor during arc movement (0 = none, 0.3 = noticeable).
@export var arc_stretch: float = 0.0
## Squash factor on impact (0 = none, 0.3 = noticeable).
@export var impact_squash: float = 0.0
## Spring oscillations during settle (0 = none, 2-4 = bouncy).
@export var spring_bounces: int = 0


static func _make(
	lift: float, anticipation: float, arc: float, settle: float,
	spin: float = 0.0, shake: float = 0.0,
	stretch: float = 0.0, squash: float = 0.0, bounces: int = 0
) -> Resource:
	var style = load("res://systems/board_visuals/placement_style.gd").new()
	style.lift_height = lift
	style.anticipation_factor = anticipation
	style.arc_duration = arc
	style.settle_duration = settle
	style.spin_rotations = spin
	style.shake_amount = shake
	style.arc_stretch = stretch
	style.impact_squash = squash
	style.spring_bounces = bounces
	return style


static func gentle() -> Resource:
	return _make(6.0, 0.1, 0.8, 0.3, 0.0, 0.0, 0.1, 0.1, 2)

static func slam() -> Resource:
	return _make(30.0, 0.5, 0.2, 0.08, 0.0, 0.0, 0.3, 0.4, 3)

static func spinning() -> Resource:
	return _make(12.0, 0.15, 0.7, 0.2, 2.0, 0.0, 0.15, 0.15, 2)

static func dramatic() -> Resource:
	return _make(50.0, 0.6, 0.6, 0.25, 0.0, 0.0, 0.25, 0.35, 4)

static func nervous() -> Resource:
	return _make(4.0, 0.05, 0.35, 0.4, 0.0, 3.0, 0.2, 0.1, 0)
