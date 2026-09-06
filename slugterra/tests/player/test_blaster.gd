extends GdUnitTestSuite
## Blaster charge, rejection and shot reporting.
##
## The projectile itself is Codex's (B0). These tests cover the boundary this
## side owns: how long you held, how fast it leaves, whether it should
## transform, and whether the shot was allowed at all.

const CONFIG_PATH := "res://data/player/charge_default.tres"

var _blaster: Blaster
var _config: ChargeConfig


func before_test() -> void:
	_config = load(CONFIG_PATH).duplicate() as ChargeConfig
	_blaster = Blaster.new()
	_blaster.charge_config = _config
	_blaster.allow_dry_fire = true
	add_child(_blaster)


func after_test() -> void:
	if is_instance_valid(_blaster):
		_blaster.queue_free()


## Takes manual control of the charge clock so these tests never depend on real
## frame timing. `_physics_process` only advances when it is called.
func _charge_for(seconds: float, step := 0.05) -> void:
	_blaster.begin_charge()
	_blaster.set_physics_process(false)
	var elapsed := 0.0
	while elapsed < seconds - 0.0001:
		var dt: float = minf(step, seconds - elapsed)
		_blaster._physics_process(dt)
		elapsed += dt


func test_starts_idle() -> void:
	assert_bool(_blaster.is_charging()).is_false()
	assert_float(_blaster.get_charge()).is_equal(0.0)


func test_charge_accumulates_and_clamps_at_full() -> void:
	_charge_for(0.3)
	assert_bool(_blaster.is_charging()).is_true()
	assert_float(_blaster.get_charge()).is_equal_approx(0.5, 0.01)

	_blaster._physics_process(2.0)
	assert_float(_blaster.get_charge()).is_equal(1.0)


func test_cancel_resets_the_charge() -> void:
	_charge_for(0.3)
	_blaster.cancel_charge()
	assert_bool(_blaster.is_charging()).is_false()
	assert_float(_blaster.get_charge()).is_equal(0.0)


func test_release_without_charging_is_rejected() -> void:
	var report := _blaster.release()
	assert_bool(report["accepted"]).is_false()
	assert_str(String(report["reason"])).is_equal("not_charging")


## A tap release must be under the threshold. This is the failure band that the
## whole design rests on, so it is asserted rather than assumed.
func test_tap_release_is_a_dud() -> void:
	_charge_for(0.02)
	var report := _blaster.release()
	assert_bool(report["accepted"]).is_true()
	assert_float(report["speed_mps"]).is_less(44.7)
	assert_bool(report["will_transform"]).is_false()


func test_full_charge_clears_the_threshold() -> void:
	_charge_for(0.7)
	var report := _blaster.release()
	assert_bool(report["accepted"]).is_true()
	assert_float(report["speed_mps"]).is_equal_approx(_config.max_speed, 0.01)
	assert_bool(report["will_transform"]).is_true()


## Releasing exactly at the notch must transform: the contract is inclusive
## (>= threshold), and the notch is drawn at that same point.
func test_release_at_the_notch_transforms() -> void:
	var marker := _config.threshold_marker()
	_charge_for(marker * _config.charge_time, 0.001)
	var report := _blaster.release()
	assert_float(report["speed_mps"]).is_greater_equal(report["threshold_mps"] - 0.01)
	assert_bool(report["will_transform"]).is_true()


func test_release_stops_the_charge() -> void:
	_charge_for(0.3)
	_blaster.release()
	assert_bool(_blaster.is_charging()).is_false()


func test_fired_signal_carries_the_report() -> void:
	var received: Array[Dictionary] = []
	_blaster.fired.connect(func(report: Dictionary) -> void: received.append(report))
	_charge_for(0.7)
	_blaster.release()

	assert_int(received.size()).is_equal(1)
	assert_bool(received[0]["will_transform"]).is_true()


func test_threshold_marker_matches_the_config() -> void:
	assert_float(_blaster.get_threshold()).is_equal_approx(_config.reference_threshold, 0.001)
	assert_float(_blaster.get_threshold_marker()).is_equal_approx(
		_config.threshold_marker(), 0.0001
	)


# --- Belt interaction ------------------------------------------------------
#
# SlugBelt and SlugInstance are Codex's. The blaster only ever duck-types them,
# so a minimal double is enough and keeps these tests independent of B0.

class FakeInstance:
	extends RefCounted
	var is_ghouled := false
	var ready := true
	var data: Object

	func is_ready() -> bool:
		return ready


class FakeData:
	extends RefCounted
	var velocity_threshold := 44.7


class FakeBelt:
	extends RefCounted
	var active: Object

	func get_active() -> Object:
		return active


func _bind_belt(instance: Object) -> void:
	var belt := FakeBelt.new()
	belt.active = instance
	_blaster.bind(belt, null, null)


func test_charging_is_refused_when_the_slug_is_not_ready() -> void:
	var instance := FakeInstance.new()
	instance.ready = false
	_bind_belt(instance)

	var reasons: Array[StringName] = []
	_blaster.fire_rejected.connect(func(r: StringName) -> void: reasons.append(r))

	_blaster.begin_charge()
	assert_bool(_blaster.is_charging()).is_false()
	assert_array(reasons).contains([&"unavailable"])


func test_charging_is_refused_when_the_slug_is_ghouled() -> void:
	var instance := FakeInstance.new()
	instance.is_ghouled = true
	_bind_belt(instance)

	_blaster.begin_charge()
	assert_bool(_blaster.is_charging()).is_false()


func test_empty_belt_is_refused_when_dry_fire_is_disabled() -> void:
	_blaster.allow_dry_fire = false
	_bind_belt(null)

	_blaster.begin_charge()
	assert_bool(_blaster.is_charging()).is_false()


func test_threshold_comes_from_the_equipped_slug_not_a_constant() -> void:
	var data := FakeData.new()
	data.velocity_threshold = 30.0
	var instance := FakeInstance.new()
	instance.data = data
	_bind_belt(instance)

	assert_float(_blaster.get_threshold()).is_equal_approx(30.0, 0.001)
	# A lower threshold has to move the notch left, not just the number.
	assert_float(_blaster.get_threshold_marker()).is_less(_config.threshold_marker())
