extends Node2D

## Manages CPUParticles2D for trail and impact effects on a piece.

var effect: Resource = null  # PieceEffect
var _trail_particles: CPUParticles2D = null
var _tracked_piece: Control = null
var _trailing: bool = false


func setup(piece_effect: Resource) -> void:
	effect = piece_effect


func start_trail(piece: Control) -> void:
	if effect == null or not effect.trail_enabled:
		return
	_tracked_piece = piece
	_trailing = true

	_trail_particles = CPUParticles2D.new()
	_trail_particles.emitting = true
	_trail_particles.one_shot = false
	_trail_particles.amount = effect.trail_amount
	_trail_particles.lifetime = effect.trail_lifetime
	_trail_particles.explosiveness = 0.0
	_trail_particles.direction = Vector2(0, -1)
	_trail_particles.spread = effect.trail_spread
	_trail_particles.initial_velocity_min = effect.trail_velocity_min
	_trail_particles.initial_velocity_max = effect.trail_velocity_max
	_trail_particles.scale_amount_min = effect.trail_scale * 0.5
	_trail_particles.scale_amount_max = effect.trail_scale
	_trail_particles.gravity = effect.trail_gravity
	_trail_particles.color = effect.trail_color

	var fade_gradient := Gradient.new()
	fade_gradient.set_color(0, effect.trail_color)
	fade_gradient.set_color(1, Color(effect.trail_color, 0.0))
	_trail_particles.color_ramp = fade_gradient

	add_child(_trail_particles)
	_update_trail_position()


func stop_trail() -> void:
	_trailing = false
	_tracked_piece = null
	if _trail_particles and is_instance_valid(_trail_particles):
		_trail_particles.emitting = false
		var lifetime: float = _trail_particles.lifetime
		var particles_ref: CPUParticles2D = _trail_particles
		_trail_particles = null
		get_tree().create_timer(lifetime).timeout.connect(func():
			if is_instance_valid(particles_ref):
				particles_ref.queue_free()
		)


func play_impact(impact_pos: Vector2) -> void:
	if effect == null or not effect.impact_enabled:
		return

	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = effect.impact_amount
	particles.lifetime = effect.impact_lifetime
	particles.explosiveness = 0.95
	particles.direction = Vector2(0, -1)
	particles.spread = effect.impact_spread
	particles.initial_velocity_min = effect.impact_velocity_min
	particles.initial_velocity_max = effect.impact_velocity_max
	particles.scale_amount_min = effect.impact_scale * 0.3
	particles.scale_amount_max = effect.impact_scale
	particles.gravity = effect.impact_gravity
	particles.color = effect.impact_color
	particles.position = impact_pos - global_position

	var fade_gradient := Gradient.new()
	fade_gradient.set_color(0, effect.impact_color)
	fade_gradient.set_color(1, Color(effect.impact_color, 0.0))
	particles.color_ramp = fade_gradient

	add_child(particles)

	get_tree().create_timer(effect.impact_lifetime + 0.1).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _process(_delta: float) -> void:
	if _trailing:
		_update_trail_position()


func _update_trail_position() -> void:
	if _trail_particles and _tracked_piece and is_instance_valid(_tracked_piece):
		var piece_center: Vector2 = _tracked_piece.global_position + _tracked_piece.size / 2.0
		_trail_particles.position = piece_center - global_position
