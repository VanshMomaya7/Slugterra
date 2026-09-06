extends SceneTree
## Headless load check for the Claude-owned player/UI assets.
##
## Run: godot --headless --path slugterra --script res://tests/player/scene_load_check.gd
##
## `--import` only proves the files were scanned. This proves each scene and
## resource actually instantiates, that exported references resolved rather than
## silently landing as null, and that the charge curve is monotonic. Exit code
## is non-zero on failure so CI can gate on it.

const RESOURCES := [
	"res://data/player/ground_movement.tres",
	"res://data/player/charge_default.tres",
	"res://data/camera/explore.tres",
	"res://data/camera/aim.tres",
	"res://data/camera/duel.tres",
]

const SCENES := [
	"res://scenes/prefabs/player/camera_rig.tscn",
	"res://scenes/prefabs/player/player.tscn",
	"res://scenes/ui/hud.tscn",
]

var _failures: PackedStringArray = []


func _initialize() -> void:
	print("=== player scene load check ===")
	_check_resources()
	_check_scenes()
	_check_charge_math()
	_check_player_wiring()

	print("")
	if _failures.is_empty():
		print("PASS - all player scenes, resources and charge maths are sound.")
		quit(0)
	else:
		printerr("FAIL - %d problem(s):" % _failures.size())
		for failure in _failures:
			printerr("  - " + failure)
		quit(1)


func _fail(message: String) -> void:
	_failures.append(message)


func _ok(message: String) -> void:
	print("  ok  " + message)


func _check_resources() -> void:
	print("- resources")
	for path in RESOURCES:
		if not ResourceLoader.exists(path):
			_fail("missing resource: " + path)
			continue
		var resource := load(path)
		if resource == null:
			_fail("failed to load: " + path)
			continue
		if resource.get_script() == null:
			_fail("resource lost its script binding: " + path)
			continue
		_ok(path)


func _check_scenes() -> void:
	print("- scenes")
	for path in SCENES:
		if not ResourceLoader.exists(path):
			_fail("missing scene: " + path)
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			_fail("not a PackedScene: " + path)
			continue
		var instance := packed.instantiate()
		if instance == null:
			_fail("failed to instantiate: " + path)
			continue
		_ok("%s -> %s" % [path, instance.name])
		instance.free()


## The notch is only honest if the curve is monotonic and the inverse is exact.
func _check_charge_math() -> void:
	print("- charge maths")
	var config := load("res://data/player/charge_default.tres") as ChargeConfig
	if config == null:
		_fail("charge_default.tres did not load as ChargeConfig")
		return

	if not is_equal_approx(config.speed_for_charge(0.0), config.min_speed):
		_fail("speed_for_charge(0) = %f, expected min_speed %f"
			% [config.speed_for_charge(0.0), config.min_speed])
	if not is_equal_approx(config.speed_for_charge(1.0), config.max_speed):
		_fail("speed_for_charge(1) = %f, expected max_speed %f"
			% [config.speed_for_charge(1.0), config.max_speed])

	var previous := -INF
	for i in 201:
		var speed := config.speed_for_charge(float(i) / 200.0)
		if speed < previous - 0.0001:
			_fail("charge curve is not monotonic at t=%f" % (float(i) / 200.0))
			break
		previous = speed
	_ok("monotonic across 201 samples")

	var marker := config.threshold_marker()
	var round_trip := config.speed_for_charge(marker)
	if absf(round_trip - config.reference_threshold) > 0.01:
		_fail("charge_for_speed round trip off by %f m/s"
			% absf(round_trip - config.reference_threshold))
	else:
		_ok("threshold notch at %.4f -> %.3f m/s (%.1f mph)"
			% [marker, round_trip, ChargeConfig.mps_to_mph(round_trip)])

	# The dud band has to be reachable and real at both ends.
	if config.speed_for_charge(0.0) >= config.reference_threshold:
		_fail("a zero-charge shot already clears the threshold; there is no dud band")
	if config.speed_for_charge(1.0) < config.reference_threshold:
		_fail("a full charge cannot clear the threshold")
	_ok("dud band spans 0.0 .. %.3f of the meter" % marker)


## Catches the classic hand-authored-scene failure: the file parses, but an
## exported reference resolved to null and nothing works at runtime.
func _check_player_wiring() -> void:
	print("- player wiring")
	var packed := load("res://scenes/prefabs/player/player.tscn") as PackedScene
	if packed == null:
		_fail("player.tscn missing")
		return

	var player := packed.instantiate()
	root.add_child(player)

	var controller := player as CharacterBody3D
	if controller == null:
		_fail("player root is not a CharacterBody3D")
	elif controller.collision_layer != 2:
		_fail("player collision_layer is %d, expected 2 (player)" % controller.collision_layer)
	else:
		_ok("body layer 2 / mask %d" % controller.collision_mask)

	var provider := player.get_node_or_null(^"Movement/Ground")
	if provider == null:
		_fail("Movement/Ground provider node missing")
	elif provider.get(&"config") == null:
		_fail("GroundMovementProvider has no MovementConfig assigned")
	else:
		_ok("ground provider has its MovementConfig")

	var blaster := player.get_node_or_null(^"Blaster")
	if blaster == null:
		_fail("Blaster node missing")
	else:
		if blaster.get(&"charge_config") == null:
			_fail("Blaster has no ChargeConfig assigned")
		else:
			_ok("blaster has its ChargeConfig")
		if blaster.get(&"muzzle") == null:
			_fail("Blaster muzzle Marker3D did not resolve")
		else:
			_ok("blaster muzzle resolved")

	var rig := player.get_node_or_null(^"CameraRig")
	if rig == null:
		_fail("CameraRig node missing")
	else:
		for property in ["explore_profile", "aim_profile", "duel_profile"]:
			if rig.get(StringName(property)) == null:
				_fail("CameraRig.%s is null" % property)
		if rig.get(&"visual_root") == null:
			_fail("CameraRig.visual_root did not resolve to the Visual node")
		else:
			_ok("camera rig profiles and visual_root resolved")

	var belt := player.get_node_or_null(^"Belt")
	if belt == null:
		_fail("Belt node missing")
	elif not belt.has_method("get_active"):
		_fail("Belt node has no SlugBelt script attached")
	else:
		_ok("belt has SlugBelt attached")

	# The blaster must survive a full charge/release with no belt or launcher.
	if blaster != null:
		blaster.call("begin_charge")
		if not bool(blaster.call("is_charging")):
			_fail("blaster refused to start charging in dry-fire mode")
		var report: Dictionary = blaster.call("release")
		if not report.get("accepted", false):
			_fail("dry-fire release was rejected: %s" % str(report.get("reason")))
		else:
			_ok("dry-fire release ok (reason=%s, %.1f m/s)"
				% [str(report.get("reason")), float(report.get("speed_mps"))])

	player.queue_free()
