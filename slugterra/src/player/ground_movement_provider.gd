class_name GroundMovementProvider
extends MovementProvider
## On-foot movement: walk, sprint, aim-walk, jump, fall.
##
## Deterministic and tunable, per the design doc's choice of [CharacterBody3D]
## over [RigidBody3D]. All numbers live in [MovementConfig] so playtest tuning
## never edits this script.

@export var config: MovementConfig

var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _was_on_floor := false
## Set on the frame a jump is launched, cleared once the body is rising freely.
## Guards the ground-stick from cancelling the jump on its first frame.
var _jump_latch := false


func _init() -> void:
	provider_id = &"ground"


func activate(body: CharacterBody3D) -> void:
	super.activate(body)
	if config != null:
		body.floor_max_angle = deg_to_rad(config.max_slope_deg)
	body.floor_stop_on_slope = true
	body.floor_block_on_wall = true
	body.up_direction = Vector3.UP
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_jump_latch = false
	_was_on_floor = body.is_on_floor()


func apply(body: CharacterBody3D, intent: MoveIntent, delta: float) -> void:
	if config == null:
		push_error("GroundMovementProvider has no MovementConfig; body will not move.")
		return

	var on_floor := body.is_on_floor()
	# Vector3 is a value type in GDScript, so these helpers take and return the
	# velocity rather than mutating a copy of it.
	var velocity := body.velocity

	_tick_timers(intent, on_floor, delta)
	velocity = _apply_horizontal(velocity, intent, on_floor, delta)
	velocity = _apply_vertical(velocity, intent, on_floor, delta)

	body.velocity = velocity
	_was_on_floor = on_floor


func _tick_timers(intent: MoveIntent, on_floor: bool, delta: float) -> void:
	# Coyote time: keep jumping legal for a moment after walking off a ledge.
	if on_floor:
		_coyote_left = config.coyote_time
		_jump_latch = false
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)

	# Jump buffer: remember a press made just before landing.
	if intent.jump_pressed:
		_jump_buffer_left = config.jump_buffer
	else:
		_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)


func _apply_horizontal(
	velocity: Vector3, intent: MoveIntent, on_floor: bool, delta: float
) -> Vector3:
	var wish := intent.world_direction()
	var target := wish * _target_speed(intent)

	var rate := config.acceleration if wish.length_squared() > 0.0 else config.deceleration
	if not on_floor:
		rate *= config.air_control

	var planar := Vector3(velocity.x, 0.0, velocity.z)
	planar = planar.move_toward(target, rate * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	return velocity


func _apply_vertical(
	velocity: Vector3, intent: MoveIntent, on_floor: bool, delta: float
) -> Vector3:
	var can_jump := _jump_buffer_left > 0.0 and (on_floor or _coyote_left > 0.0)

	if can_jump:
		velocity.y = config.jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		_jump_latch = true
		movement_event.emit(&"jump")
		return velocity

	# Variable jump height: releasing early cuts the rise short.
	if velocity.y > 0.0 and not intent.jump_held and config.jump_cut_multiplier < 1.0:
		velocity.y *= config.jump_cut_multiplier

	velocity.y -= config.gravity() * delta
	velocity.y = maxf(velocity.y, -config.terminal_velocity)

	# Hold a small downward bias while grounded so the body stays snapped to
	# slopes instead of stepping off them and re-landing every frame.
	if on_floor and not _jump_latch and velocity.y < 0.0:
		velocity.y = -config.ground_stick_speed

	return velocity


func _target_speed(intent: MoveIntent) -> float:
	if intent.aim:
		return config.aim_speed
	if intent.sprint:
		return config.run_speed
	return config.walk_speed


func current_speed_limit(intent: MoveIntent) -> float:
	if config == null:
		return 0.0
	return _target_speed(intent)


func suggested_state(body: CharacterBody3D, intent: MoveIntent) -> int:
	if not body.is_on_floor():
		return PlayerStates.State.JUMP if body.velocity.y > 0.0 else PlayerStates.State.FALL

	if intent.aim:
		return PlayerStates.State.AIM

	var planar_speed := Vector2(body.velocity.x, body.velocity.z).length()
	var epsilon: float = config.idle_speed_epsilon if config != null else 0.15
	if planar_speed <= epsilon:
		return PlayerStates.State.IDLE

	if intent.sprint and config != null and planar_speed > config.walk_speed * 1.05:
		return PlayerStates.State.RUN

	return PlayerStates.State.WALK
