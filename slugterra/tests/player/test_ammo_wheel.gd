extends GdUnitTestSuite
## Ammo wheel selection and, more importantly, its time-scale bookkeeping.
##
## The wheel is the first thing in the project to touch global time scale. If it
## ever leaks a pushed scale the whole game silently runs at quarter speed, so
## the balance of push/pop is asserted directly rather than assumed.

var _wheel: AmmoWheel
var _belt: FakeBelt


class FakeInstance:
	extends RefCounted
	var nickname := ""


class FakeBelt:
	extends RefCounted
	var active_index := 0
	var slots: Array = [null, null, null, null, null, null]
	var selected: Array[int] = []

	func get_slot(index: int) -> Object:
		return slots[index] if index >= 0 and index < slots.size() else null

	func select(index: int) -> void:
		active_index = index
		selected.append(index)


func before_test() -> void:
	TimeController.reset()
	_belt = FakeBelt.new()
	_belt.slots[0] = FakeInstance.new()
	_belt.slots[2] = FakeInstance.new()

	_wheel = AmmoWheel.new()
	_wheel.size = Vector2(800, 600)
	add_child(_wheel)
	_wheel.bind(_belt, null)


func after_test() -> void:
	if is_instance_valid(_wheel):
		_wheel.queue_free()
	TimeController.reset()


func test_starts_closed_and_hidden() -> void:
	assert_bool(_wheel.is_open()).is_false()
	assert_bool(_wheel.visible).is_false()


func test_opening_slows_time_and_closing_restores_it() -> void:
	_wheel.open()
	assert_bool(_wheel.is_open()).is_true()
	assert_bool(_wheel.visible).is_true()
	assert_float(Engine.time_scale).is_equal_approx(_wheel.wheel_time_scale, 0.001)

	_wheel.close()
	assert_bool(_wheel.is_open()).is_false()
	assert_float(Engine.time_scale).is_equal_approx(1.0, 0.001)


func test_repeated_opens_do_not_stack_the_slow_motion() -> void:
	_wheel.open()
	_wheel.open()
	_wheel.open()
	assert_float(Engine.time_scale).is_equal_approx(_wheel.wheel_time_scale, 0.001)

	_wheel.close()
	assert_float(Engine.time_scale).is_equal_approx(1.0, 0.001)


func test_closing_while_already_closed_is_harmless() -> void:
	_wheel.close()
	_wheel.close()
	assert_float(Engine.time_scale).is_equal_approx(1.0, 0.001)


## The wheel must not be able to strand the game in slow motion.
func test_freeing_the_wheel_while_open_releases_the_time_scale() -> void:
	_wheel.open()
	assert_float(Engine.time_scale).is_less(1.0)

	_wheel.free()
	_wheel = null
	assert_float(Engine.time_scale).is_equal_approx(1.0, 0.001)


## A hitstop starting during the wheel must survive the wheel closing - the
## whole reason the scale is a keyed stack rather than a single value.
func test_closing_the_wheel_does_not_cancel_another_pushed_scale() -> void:
	_wheel.open()
	TimeController.push_scale(&"test_hitstop", 0.05)
	assert_float(Engine.time_scale).is_equal_approx(0.05, 0.001)

	_wheel.close()
	assert_float(Engine.time_scale).is_equal_approx(0.05, 0.001)

	TimeController.pop_scale(&"test_hitstop")
	assert_float(Engine.time_scale).is_equal_approx(1.0, 0.001)


func test_opening_cancels_an_in_progress_charge() -> void:
	var blaster := Blaster.new()
	blaster.charge_config = load("res://data/player/charge_default.tres") as ChargeConfig
	add_child(blaster)
	_wheel.bind(_belt, blaster)

	blaster.begin_charge()
	assert_bool(blaster.is_charging()).is_true()

	_wheel.open()
	assert_bool(blaster.is_charging()).is_false()

	_wheel.close()
	blaster.queue_free()


func test_closing_without_moving_the_pointer_keeps_the_current_slot() -> void:
	_belt.active_index = 2
	_wheel.open()
	_wheel.close()
	assert_int(_belt.active_index).is_equal(2)


func test_pointer_up_selects_the_first_slot() -> void:
	_wheel.open()
	_wheel._pointer = Vector2(0, -120)
	_wheel._update_selection()
	_wheel.close()
	assert_int(_belt.active_index).is_equal(0)


func test_pointer_sweeps_through_every_sector_in_order() -> void:
	# Six sectors, slot 0 centred on straight up, increasing clockwise.
	var expected := [0, 1, 2, 3, 4, 5]
	for i in 6:
		var angle := -PI * 0.5 + float(i) * TAU / 6.0
		_wheel.open()
		_wheel._pointer = Vector2(cos(angle), sin(angle)) * 120.0
		_wheel._update_selection()
		_wheel.close()
		assert_int(_belt.active_index).is_equal(expected[i])


func test_pointer_inside_the_deadzone_does_not_change_selection() -> void:
	_belt.active_index = 4
	_wheel.open()
	_wheel._pointer = Vector2(0, -(AmmoWheel.SELECT_DEADZONE - 5.0))
	_wheel._update_selection()
	_wheel.close()
	assert_int(_belt.active_index).is_equal(4)
