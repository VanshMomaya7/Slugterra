extends GdUnitTestSuite
## The charge curve is the skill gate. If the notch and the maths disagree, the
## player is being taught the wrong timing, so these are the tightest tests in
## the player layer.

const CONFIG_PATH := "res://data/player/charge_default.tres"

var _config: ChargeConfig


func before_test() -> void:
	_config = load(CONFIG_PATH).duplicate() as ChargeConfig


func test_shipped_config_loads_with_its_script() -> void:
	assert_object(_config).is_not_null()
	assert_float(_config.charge_time).is_greater(0.0)
	assert_object(_config.curve).is_not_null()


func test_endpoints_match_min_and_max_speed() -> void:
	assert_float(_config.speed_for_charge(0.0)).is_equal_approx(_config.min_speed, 0.001)
	assert_float(_config.speed_for_charge(1.0)).is_equal_approx(_config.max_speed, 0.001)


func test_charge_is_clamped_outside_zero_to_one() -> void:
	assert_float(_config.speed_for_charge(-5.0)).is_equal_approx(_config.min_speed, 0.001)
	assert_float(_config.speed_for_charge(9.0)).is_equal_approx(_config.max_speed, 0.001)


func test_speed_is_monotonic_across_the_curve() -> void:
	var previous := -INF
	for i in 201:
		var speed := _config.speed_for_charge(float(i) / 200.0)
		assert_float(speed).is_greater_equal(previous - 0.0001)
		previous = speed


## Without this the notch cannot be trusted anywhere on the bar.
func test_charge_for_speed_round_trips() -> void:
	for i in 21:
		var target := lerpf(_config.min_speed, _config.max_speed, float(i) / 20.0)
		var charge := _config.charge_for_speed(target)
		assert_float(_config.speed_for_charge(charge)).is_equal_approx(target, 0.01)


func test_charge_for_speed_saturates_outside_the_range() -> void:
	assert_float(_config.charge_for_speed(_config.min_speed - 10.0)).is_equal(0.0)
	assert_float(_config.charge_for_speed(_config.max_speed + 10.0)).is_equal(1.0)


func test_threshold_notch_sits_inside_the_meter() -> void:
	var marker := _config.threshold_marker()
	assert_float(marker).is_between(0.05, 0.95)
	assert_float(_config.speed_for_charge(marker)).is_equal_approx(
		_config.reference_threshold, 0.01
	)


## The design's whole premise: a panic shot fizzles, a committed shot does not.
func test_dud_band_and_success_band_both_exist() -> void:
	assert_bool(_config.clears_threshold(0.0)).is_false()
	assert_bool(_config.clears_threshold(1.0)).is_true()

	var marker := _config.threshold_marker()
	assert_bool(_config.clears_threshold(marker - 0.02)).is_false()
	assert_bool(_config.clears_threshold(minf(marker + 0.02, 1.0))).is_true()


func test_threshold_marker_follows_a_per_slug_threshold() -> void:
	# A slower slug clears earlier on the bar; a faster one later. The notch is
	# never a fixed fraction of the meter.
	var easy := _config.threshold_marker(30.0)
	var hard := _config.threshold_marker(58.0)
	assert_float(easy).is_less(hard)


func test_canonical_hundred_mph_is_forty_four_point_seven_mps() -> void:
	assert_float(ChargeConfig.mps_to_mph(44.7)).is_equal_approx(100.0, 0.05)
	assert_float(ChargeConfig.mph_to_mps(100.0)).is_equal_approx(44.7, 0.01)


func test_charge_after_ramps_over_charge_time_and_clamps() -> void:
	_config.charge_time = 0.6
	assert_float(_config.charge_after(0.0)).is_equal(0.0)
	assert_float(_config.charge_after(0.3)).is_equal_approx(0.5, 0.0001)
	assert_float(_config.charge_after(0.6)).is_equal(1.0)
	assert_float(_config.charge_after(5.0)).is_equal(1.0)


func test_missing_curve_falls_back_to_linear() -> void:
	_config.curve = null
	assert_float(_config.curve_value(0.5)).is_equal_approx(0.5, 0.0001)
	assert_float(_config.speed_for_charge(0.5)).is_equal_approx(
		lerpf(_config.min_speed, _config.max_speed, 0.5), 0.001
	)


func test_perfect_window_is_off_by_default_and_works_when_widened() -> void:
	assert_bool(_config.is_perfect(1.0)).is_false()

	_config.perfect_window = 0.1
	assert_bool(_config.is_perfect(1.0)).is_true()
	assert_bool(_config.is_perfect(0.95)).is_true()
	assert_bool(_config.is_perfect(0.80)).is_false()
