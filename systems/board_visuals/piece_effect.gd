class_name PieceEffect
extends Resource

## Configures particle effects for piece movement and landing.

# Trail (emitted while piece flies through the air)
@export var trail_enabled: bool = false
@export var trail_color: Color = Color.WHITE
@export var trail_amount: int = 20
@export var trail_lifetime: float = 0.4
@export var trail_spread: float = 15.0
@export var trail_velocity_min: float = 20.0
@export var trail_velocity_max: float = 60.0
@export var trail_scale: float = 3.0
@export var trail_gravity: Vector2 = Vector2.ZERO

# Impact (burst when piece lands)
@export var impact_enabled: bool = false
@export var impact_color: Color = Color.WHITE
@export var impact_amount: int = 30
@export var impact_lifetime: float = 0.5
@export var impact_spread: float = 180.0
@export var impact_velocity_min: float = 40.0
@export var impact_velocity_max: float = 120.0
@export var impact_scale: float = 4.0
@export var impact_gravity: Vector2 = Vector2(0, 100.0)

# Board shake on impact
@export var board_shake_intensity: float = 0.0
@export var board_shake_duration: float = 0.15

# Screen flash on impact
@export var screen_flash_enabled: bool = false
@export var screen_flash_color: Color = Color.WHITE
@export var screen_flash_duration: float = 0.1

# Propagation ring on impact
@export var propagation_enabled: bool = false
@export var propagation_color: Color = Color.WHITE
@export var propagation_duration: float = 0.3


static func _make(
	t_enabled: bool, t_color: Color, t_amount: int, t_lifetime: float,
	t_spread: float, t_vel_min: float, t_vel_max: float, t_scale: float, t_gravity: Vector2,
	i_enabled: bool, i_color: Color, i_amount: int, i_lifetime: float,
	i_spread: float, i_vel_min: float, i_vel_max: float, i_scale: float, i_gravity: Vector2,
	shake_intensity: float, shake_duration: float
) -> Resource:
	var e: Resource = load("res://systems/board_visuals/piece_effect.gd").new()
	e.trail_enabled = t_enabled
	e.trail_color = t_color
	e.trail_amount = t_amount
	e.trail_lifetime = t_lifetime
	e.trail_spread = t_spread
	e.trail_velocity_min = t_vel_min
	e.trail_velocity_max = t_vel_max
	e.trail_scale = t_scale
	e.trail_gravity = t_gravity
	e.impact_enabled = i_enabled
	e.impact_color = i_color
	e.impact_amount = i_amount
	e.impact_lifetime = i_lifetime
	e.impact_spread = i_spread
	e.impact_velocity_min = i_vel_min
	e.impact_velocity_max = i_vel_max
	e.impact_scale = i_scale
	e.impact_gravity = i_gravity
	e.board_shake_intensity = shake_intensity
	e.board_shake_duration = shake_duration
	return e


static func none() -> Resource:
	return load("res://systems/board_visuals/piece_effect.gd").new()


static func fire() -> Resource:
	var e: Resource = _make(
		true, Color(1.0, 0.5, 0.1), 25, 0.35,
		20.0, 30.0, 80.0, 4.0, Vector2(0, -30),
		true, Color(1.0, 0.4, 0.0), 40, 0.4,
		180.0, 60.0, 150.0, 5.0, Vector2(0, 80),
		3.0, 0.15
	)
	e.screen_flash_enabled = true
	e.screen_flash_color = Color(1.0, 0.4, 0.0, 0.6)
	e.screen_flash_duration = 0.08
	e.propagation_enabled = true
	e.propagation_color = Color(1.0, 0.5, 0.1)
	e.propagation_duration = 0.3
	return e


static func sparkle() -> Resource:
	return _make(
		true, Color(1.0, 1.0, 0.6), 15, 0.5,
		30.0, 15.0, 50.0, 2.5, Vector2.ZERO,
		true, Color(1.0, 0.95, 0.7), 30, 0.6,
		180.0, 40.0, 100.0, 3.0, Vector2(0, 20),
		0.0, 0.0
	)


static func smoke() -> Resource:
	return _make(
		true, Color(0.6, 0.6, 0.6), 12, 0.6,
		25.0, 10.0, 40.0, 5.0, Vector2(0, -20),
		true, Color(0.5, 0.5, 0.5), 20, 0.7,
		180.0, 20.0, 60.0, 6.0, Vector2(0, -15),
		0.0, 0.0
	)


static func shockwave() -> Resource:
	var e: Resource = _make(
		false, Color.WHITE, 0, 0.0,
		0.0, 0.0, 0.0, 0.0, Vector2.ZERO,
		true, Color(0.9, 0.9, 1.0), 50, 0.3,
		180.0, 80.0, 200.0, 3.0, Vector2.ZERO,
		6.0, 0.2
	)
	e.screen_flash_enabled = true
	e.screen_flash_color = Color(0.9, 0.9, 1.0, 0.7)
	e.screen_flash_duration = 0.06
	e.propagation_enabled = true
	e.propagation_color = Color(0.9, 0.9, 1.0)
	e.propagation_duration = 0.25
	return e


static func all_effects() -> Array:
	return [none(), fire(), sparkle(), smoke(), shockwave()]


static func effect_names() -> PackedStringArray:
	return PackedStringArray(["Ninguno", "Fuego", "Chispas", "Humo", "Onda"])
