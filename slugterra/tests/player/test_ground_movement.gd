extends GdUnitTestSuite
## Ground movement, exercised through a real CharacterBody3D against a real
## floor. Jump, coyote time and the jump buffer all depend on `is_on_floor()`,
## which only becomes true after `move_and_slide` has actually resolved a
## collision, so faking it would test nothing worth testing.

const CONFIG_PATH := "res://data/player/ground_movement.tres"
const STEP := 1.0 / 60.0

var _config: MovementConfig
var _provider: GroundMovementProvider
var _body: CharacterBody3D
var _intent: MoveIntent


func before_test() -> void:
	_config = load(CONFIG_PATH).duplicate() as MovementConfig
	_intent = MoveIntent.new()

	_provider = GroundMovementProvider.new()
	_provider.config = _config
	add_child(_provider)

	_body = CharacterBody3D.new()
	_body.collision_layer = 2
	_body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	_body.add_child(shape)
	add_child(_body)

	_provider.activate(_body)


func after_test() -> void:
	if is_instance_valid(_body):
		_body.queue_free()
	if is_instance_valid(_provider):
		_provider.queue_free()


func _add_floor() -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child(floor_body)
	return floor_body


## One real physics step: provider writes velocity, body resolves motion.
func _step() -> void:
	_provider.apply(_body, _intent, STEP)
	_body.move_and_slide()


func _step_many(count: int) -> void:
	for i in count:
		_step()


func _settle_on_floor(timeout := 5000) -> void:
	_add_floor()
	_body.global_position = Vector3(0, 1.2, 0)
	for i in 90:
		_step()
		await get_tree().physics_frame
		if _body.is_on_floor():
			return


# --- Gravity and falling ---------------------------------------------------

func test_gravity_pulls_the_body_down_in_the_air() -> void:
	_body.global_position = Vector3(0, 20, 0)
	_step()
	assert_float(_body.velocity.y).is_less(0.0)


func test_fall_speed_is_capped_at_terminal_velocity() -> void:
	_body.global_position = Vector3(0, 500, 0)
	_step_many(600)
	assert_float(_body.velocity.y).is_greater_equal(-_config.terminal_velocity - 0.001)


# --- Horizontal movement ---------------------------------------------------

func test_no_input_leaves_the_body_horizontally_still() -> void:
	_step_many(10)
	assert_float(Vector2(_body.velocity.x, _body.velocity.z).length()).is_less(0.01)


func test_forward_input_accelerates_toward_walk_speed() -> void:
	_intent.move_axis = Vector2(0, 1)
	_step_many(60)
	var planar := Vector2(_body.velocity.x, _body.velocity.z).length()
	assert_float(planar).is_equal_approx(_config.walk_speed, 0.2)


func test_sprint_reaches_run_speed() -> void:
	_intent.move_axis = Vector2(0, 1)
	_intent.sprint = true
	_step_many(60)
	var planar := Vector2(_body.velocity.x, _body.velocity.z).length()
	assert_float(planar).is_equal_approx(_config.run_speed, 0.2)


func test_aiming_caps_speed_below_walking() -> void:
	_intent.move_axis = Vector2(0, 1)
	_intent.aim = true
	_intent.sprint = true
	_step_many(60)
	var planar := Vector2(_body.velocity.x, _body.velocity.z).length()
	assert_float(planar).is_equal_approx(_config.aim_speed, 0.2)
	assert_float(planar).is_less(_config.walk_speed)


func test_movement_is_relative_to_the_look_basis() -> void:
	# Facing world +X: pushing "forward" must move along +X, not world -Z.
	_intent.look_basis = Basis(Vector3.UP, -PI * 0.5)
	_intent.move_axis = Vector2(0, 1)
	_step_many(30)
	assert_float(_body.velocity.x).is_greater(1.0)
	assert_float(absf(_body.velocity.z)).is_less(0.5)


func test_releasing_input_decelerates_to_a_stop() -> void:
	_intent.move_axis = Vector2(0, 1)
	_step_many(60)
	_intent.move_axis = Vector2.ZERO
	_step_many(60)
	assert_float(Vector2(_body.velocity.x, _body.velocity.z).length()).is_less(0.05)


# --- Jumping ---------------------------------------------------------------

func test_no_jump_in_midair_without_coyote(timeout := 5000) -> void:
	_body.global_position = Vector3(0, 40, 0)
	_step_many(30)
	_intent.jump_pressed = true
	_intent.jump_held = true
	_step()
	assert_float(_body.velocity.y).is_less(0.0)


func test_jump_from_the_ground_launches_upward(timeout := 10000) -> void:
	await _settle_on_floor()
	assert_bool(_body.is_on_floor()).is_true()

	_intent.jump_pressed = true
	_intent.jump_held = true
	_provider.apply(_body, _intent, STEP)
	assert_float(_body.velocity.y).is_equal_approx(_config.jump_velocity, 0.001)


func test_coyote_time_allows_a_jump_just_after_leaving_the_ground(
	timeout := 10000
) -> void:
	await _settle_on_floor()

	# Walk off the edge of the floor, then jump within the coyote window.
	_body.global_position = Vector3(60, 1.0, 0)
	_intent.jump_pressed = false
	_intent.jump_held = false
	_provider.apply(_body, _intent, STEP)
	_body.move_and_slide()
	assert_bool(_body.is_on_floor()).is_false()

	_intent.jump_pressed = true
	_intent.jump_held = true
	_provider.apply(_body, _intent, STEP)
	assert_float(_body.velocity.y).is_equal_approx(_config.jump_velocity, 0.001)


func test_coyote_time_expires(timeout := 10000) -> void:
	await _settle_on_floor()

	_body.global_position = Vector3(60, 20.0, 0)
	var steps := int(_config.coyote_time / STEP) + 6
	_step_many(steps)

	_intent.jump_pressed = true
	_intent.jump_held = true
	_provider.apply(_body, _intent, STEP)
	assert_float(_body.velocity.y).is_less(0.0)


func test_releasing_jump_early_cuts_the_rise(timeout := 10000) -> void:
	await _settle_on_floor()

	_intent.jump_pressed = true
	_intent.jump_held = true
	_provider.apply(_body, _intent, STEP)
	var launch_speed := _body.velocity.y

	# Let go while still rising.
	_intent.jump_pressed = false
	_intent.jump_held = false
	_provider.apply(_body, _intent, STEP)
	assert_float(_body.velocity.y).is_less(launch_speed * _config.jump_cut_multiplier + 0.01)


func test_jump_buffer_fires_on_landing(timeout := 10000) -> void:
	_add_floor()
	_body.global_position = Vector3(0, 1.2, 0)

	# Fall until coyote time has definitely expired, so this proves the buffer
	# and not the coyote window, and until touchdown is close enough to land
	# inside the buffer.
	var airborne_frames := 0
	for i in 120:
		_step()
		await get_tree().physics_frame
		airborne_frames += 1
		var airborne_seconds := airborne_frames * STEP
		if airborne_seconds > _config.coyote_time + 0.05 and _body.global_position.y < 0.25:
			break

	assert_bool(_body.is_on_floor()).is_false()
	assert_float(_body.velocity.y).is_less(0.0)

	# One press, mid-air, with coyote already gone: it must not fire now.
	_intent.jump_pressed = true
	_intent.jump_held = true
	_step()
	assert_float(_body.velocity.y).is_less(0.0)
	_intent.jump_pressed = false

	# It must fire by itself on touchdown.
	var launched := false
	for i in 10:
		await get_tree().physics_frame
		_step()
		if _body.velocity.y > 0.1:
			launched = true
			break

	assert_bool(launched).is_true()
	assert_float(_body.velocity.y).is_equal_approx(_config.jump_velocity, 0.2)


func test_expired_jump_buffer_does_not_fire_on_landing(timeout := 10000) -> void:
	_add_floor()
	_body.global_position = Vector3(0, 6.0, 0)

	# Press once at the top of a long fall; the buffer must lapse before landing.
	_intent.jump_pressed = true
	_intent.jump_held = true
	_step()
	_intent.jump_pressed = false
	_intent.jump_held = false

	for i in 180:
		_step()
		await get_tree().physics_frame
		if _body.is_on_floor():
			break

	assert_bool(_body.is_on_floor()).is_true()
	assert_float(_body.velocity.y).is_less_equal(0.0)


# --- State reporting -------------------------------------------------------

func test_state_is_fall_when_descending() -> void:
	_body.global_position = Vector3(0, 40, 0)
	_step_many(5)
	assert_int(_provider.suggested_state(_body, _intent)).is_equal(PlayerStates.State.FALL)


func test_state_is_idle_then_walk_on_the_ground(timeout := 10000) -> void:
	await _settle_on_floor()
	assert_int(_provider.suggested_state(_body, _intent)).is_equal(PlayerStates.State.IDLE)

	_intent.move_axis = Vector2(0, 1)
	_step_many(40)
	assert_int(_provider.suggested_state(_body, _intent)).is_equal(PlayerStates.State.WALK)


func test_state_is_aim_while_aiming(timeout := 10000) -> void:
	await _settle_on_floor()
	_intent.aim = true
	assert_int(_provider.suggested_state(_body, _intent)).is_equal(PlayerStates.State.AIM)


func test_speed_limit_reports_the_active_cap() -> void:
	assert_float(_provider.current_speed_limit(_intent)).is_equal(_config.walk_speed)
	_intent.sprint = true
	assert_float(_provider.current_speed_limit(_intent)).is_equal(_config.run_speed)
	_intent.aim = true
	assert_float(_provider.current_speed_limit(_intent)).is_equal(_config.aim_speed)
