extends SceneTree
## End-to-end check of the M0 loop in the real arena scene.
##
## Run: godot --headless --path slugterra --script res://tests/player/m0_loop_check.gd
##
## Boots scenes/main.tscn, fires one under-charged shot and one full-charge
## shot, and asserts that the first duds and the second transforms - through the
## real blaster, the real launcher and the real EventBus, with nothing stubbed.
## This is the check that proves the design's central mechanic actually works.

const SCENE_PATH := "res://scenes/main.tscn"

## Frames to hold the trigger for the tap shot. At 60 Hz and a 0.6 s charge
## this is ~8% charge, which must land in the dud band.
const TAP_FRAMES := 3
## Comfortably past charge_time, so the shot leaves at max speed.
const FULL_FRAMES := 45

var _failures: PackedStringArray = []
var _frame := 0
var _phase := 0
var _phase_frame := 0

var _player: Node
var _blaster: Object

var _events: Array[String] = []
var _transitions: Array[String] = []
var _last_availability := -1
var _tap_report: Dictionary = {}
var _full_report: Dictionary = {}


func _initialize() -> void:
	print("=== M0 loop check ===")
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("could not load " + SCENE_PATH)
		_finish()
		return
	root.add_child(packed.instantiate())
	_connect_bus()


func _connect_bus() -> void:
	var bus := root.get_node_or_null(^"EventBus")
	if bus == null:
		_fail("EventBus autoload not found; is it registered in project.godot?")
		return
	bus.connect("slug_launched", func(id: int, _i: Object, _p: Node3D) -> void:
		_events.append("launched:%d" % id))
	bus.connect("slug_transformed", func(id: int, _i: Object) -> void:
		_events.append("transformed:%d" % id))
	bus.connect("slug_dud", func(id: int, _i: Object) -> void:
		_events.append("dud:%d" % id))
	bus.connect("slug_returned", func(id: int, _i: Object) -> void:
		_events.append("returned:%d" % id))


func _fail(message: String) -> void:
	_failures.append(message)


func _ok(message: String) -> void:
	print("  ok  " + message)


const AVAILABILITY_NAMES := [
	"READY", "IN_FLIGHT", "DUD_WAIT", "RETURNING", "COOLDOWN", "GHOULED"
]


func _active_instance() -> Object:
	if _player == null or not _player.has_method("get_belt"):
		return null
	var belt: Object = _player.call("get_belt")
	if belt == null or not belt.has_method("get_active"):
		return null
	return belt.call("get_active")


func _track_availability() -> void:
	var instance := _active_instance()
	if instance == null:
		return
	var availability := int(instance.get(&"availability"))
	if availability != _last_availability:
		_last_availability = availability
		var label := "?"
		if availability >= 0 and availability < AVAILABILITY_NAMES.size():
			label = AVAILABILITY_NAMES[availability]
		_transitions.append("f%d:%s" % [_frame, label])


func _slug_is_ready() -> bool:
	var instance := _active_instance()
	if instance == null:
		return true
	return instance.has_method("is_ready") and bool(instance.call("is_ready"))


func _physics_process(_delta: float) -> bool:
	_frame += 1
	_phase_frame += 1
	_track_availability()
	match _phase:
		0:
			if _frame > 4:
				_bind()
				_advance()
		1:
			_start_charge()
			_advance()
		2:
			if _phase_frame > TAP_FRAMES:
				_release_tap()
				_advance()
		3:
			# Wait for the dud to land, rest and recall itself. Driven by the
			# slug's own availability rather than a guessed frame count: the
			# full dud cycle is flight + 1.5 s rest + 1.2 s return.
			if _slug_is_ready():
				_ok("slug returned to READY after the dud at frame %d" % _frame)
				_advance()
			elif _phase_frame > 900:
				_fail("slug never returned to READY after the dud (waited %d frames)"
					% _phase_frame)
				_advance()
		4:
			_start_charge()
			_advance()
		5:
			if _phase_frame > FULL_FRAMES:
				_release_full()
				_advance()
		6:
			if _phase_frame > 240:
				_report()
				_finish()
				return true
	return false


func _advance() -> void:
	_phase += 1
	_phase_frame = 0


func _bind() -> void:
	_player = root.get_tree().get_first_node_in_group(&"player")
	if _player == null:
		_fail("no node in group 'player' inside main.tscn")
		return
	_ok("player found at %s" % str((_player as Node3D).global_position))

	if _player.has_method("get_blaster"):
		_blaster = _player.call("get_blaster")
	if _blaster == null:
		_fail("player exposes no blaster")
		return

	var belt: Object = _player.call("get_belt") if _player.has_method("get_belt") else null
	if belt != null and belt.has_method("get_active"):
		var active: Object = belt.call("get_active")
		if active == null:
			_ok("belt is empty; shots resolve as dry fire")
		else:
			var data: Object = active.get(&"data")
			var name_text := "?"
			if data != null:
				name_text = String(data.get(&"display_name"))
			_ok("belt slot 0 holds %s (threshold %.1f m/s)"
				% [name_text, float(_blaster.call("get_threshold"))])

	_ok("notch sits at %.3f of the charge meter"
		% float(_blaster.call("get_threshold_marker")))


func _start_charge() -> void:
	if _blaster == null:
		return
	_blaster.call("begin_charge")
	if not bool(_blaster.call("is_charging")):
		_fail("blaster refused to begin charging")


func _release_tap() -> void:
	if _blaster == null:
		return
	_tap_report = _blaster.call("release")
	var speed := float(_tap_report.get("speed_mps", 0.0))
	print("  tap release: %.1f m/s (%.0f mph), will_transform=%s"
		% [speed, ChargeConfig.mps_to_mph(speed), str(_tap_report.get("will_transform"))])


func _release_full() -> void:
	if _blaster == null:
		return
	_full_report = _blaster.call("release")
	var speed := float(_full_report.get("speed_mps", 0.0))
	print("  full release: %.1f m/s (%.0f mph), will_transform=%s"
		% [speed, ChargeConfig.mps_to_mph(speed), str(_full_report.get("will_transform"))])


func _report() -> void:
	print("- results")

	# The tap must be a dud. This is the whole premise of the charge mechanic.
	if _tap_report.is_empty():
		_fail("tap shot produced no report")
	else:
		if bool(_tap_report.get("will_transform", true)):
			_fail("a %.0f mph tap shot transformed; the dud band is broken"
				% ChargeConfig.mps_to_mph(float(_tap_report.get("speed_mps", 0.0))))
		else:
			_ok("tap shot correctly under the threshold")

	if _full_report.is_empty():
		_fail("full shot produced no report")
	else:
		if not bool(_full_report.get("will_transform", false)):
			_fail("a full-charge shot failed to clear the threshold")
		else:
			_ok("full-charge shot correctly over the threshold")

	print("  events: %s" % ", ".join(_events))
	print("  availability: %s" % ", ".join(_transitions))

	var launched := _events.filter(func(e: String) -> bool: return e.begins_with("launched"))
	var transformed := _events.filter(func(e: String) -> bool: return e.begins_with("transformed"))
	var dudded := _events.filter(func(e: String) -> bool: return e.begins_with("dud"))

	if launched.size() < 2:
		_fail("expected 2 launch events, saw %d" % launched.size())
	else:
		_ok("both shots launched through the real launcher")

	if dudded.is_empty():
		_fail("no slug_dud event for the tap shot")
	else:
		_ok("slug_dud fired for the under-speed shot")

	if transformed.is_empty():
		_fail("no slug_transformed event for the full-charge shot")
	else:
		_ok("slug_transformed fired for the charged shot")


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("PASS - the M0 charge / dud / transform loop works end to end.")
		quit(0)
	else:
		printerr("FAIL - %d problem(s):" % _failures.size())
		for failure in _failures:
			printerr("  - " + failure)
		quit(1)
