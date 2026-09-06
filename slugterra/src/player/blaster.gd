class_name Blaster
extends Node3D
## Charge-and-release slug slinging. The verb the whole game is built on.
##
## Hold `fire` to charge, release to sling. Muzzle speed comes from
## [ChargeConfig]; whether the slug transforms into a Velocimorph is decided
## from that speed at launch (contract: proposal 3.5, accepted by Codex as
## CL-004), so the threshold notch on the HUD is a promise rather than a guess.
##
## [b]Boundary note.[/b] The projectile itself, [code]SlugBelt[/code] and
## [code]SlugLauncher[/code] are Codex's (B0). This script never hard-references
## those classes: the belt arrives through [method bind] and is duck-typed, and
## the launcher is resolved lazily by path at runtime. That keeps the player
## scene loadable and the charge loop playtestable before B0 exists, and it
## deliberately does [i]not[/i] implement a parallel projectile - when no
## launcher is present the shot resolves as a dry fire and says so.

signal charge_started()
## Emitted every physics frame while charging.
signal charge_changed(charge01: float, projected_speed_mps: float)
signal charge_cancelled()
## Emitted after a release. See [method release] for the report's shape.
signal fired(report: Dictionary)
signal fire_rejected(reason: StringName)

const LAUNCHER_SCRIPT_PATH := "res://src/slug/slug_launcher.gd"
const LAUNCH_REQUEST_SCRIPT_PATH := "res://src/slug/launch_request.gd"

@export var charge_config: ChargeConfig
## Where shots leave from. Falls back to this node's own transform.
@export var muzzle: Marker3D
## Node the projectile is parented to. Resolved from the `projectile_container`
## group when left empty, so origin shifting can move every live shot together.
@export var projectile_parent_path: NodePath
## M0 only: allow charging with no belt or launcher wired, so the charge timing
## can be playtested before B0 lands. Turn off once the projectile is real.
@export var allow_dry_fire := true

var _belt: Object
var _camera_rig: CameraRig
var _source: Node3D

var _charging := false
var _charge_seconds := 0.0
var _charge01 := 0.0

var _launcher_script: Script
var _request_script: Script
var _launcher_checked := false


func _ready() -> void:
	set_physics_process(false)
	if charge_config == null:
		push_warning("Blaster has no ChargeConfig; using defaults.")
		charge_config = ChargeConfig.new()


## Called by [PlayerController]. `belt` is duck-typed - anything exposing
## `get_active()` works, including a test double.
func bind(belt: Object, camera_rig: CameraRig, source: Node3D) -> void:
	_belt = belt
	_camera_rig = camera_rig
	_source = source


# --- Charge ----------------------------------------------------------------

func begin_charge() -> void:
	if _charging:
		return

	var reason := _rejection_reason()
	if reason != &"ok":
		fire_rejected.emit(reason)
		return

	_charging = true
	_charge_seconds = 0.0
	_charge01 = 0.0
	set_physics_process(true)
	charge_started.emit()
	charge_changed.emit(0.0, charge_config.speed_for_charge(0.0))


func cancel_charge() -> void:
	if not _charging:
		return
	_charging = false
	_charge_seconds = 0.0
	_charge01 = 0.0
	set_physics_process(false)
	charge_cancelled.emit()


func is_charging() -> bool:
	return _charging


func get_charge() -> float:
	return _charge01


func get_projected_speed() -> float:
	return charge_config.speed_for_charge(_charge01)


## Charge runs on scaled physics time, so a hitstop or the ammo wheel's slow
## motion cannot be used to buy extra charge in real seconds.
func _physics_process(delta: float) -> void:
	if not _charging:
		set_physics_process(false)
		return

	_charge_seconds += delta
	var previous := _charge01
	_charge01 = charge_config.charge_after(_charge_seconds)
	if not is_equal_approx(previous, _charge01) or _charge01 < 1.0:
		charge_changed.emit(_charge01, charge_config.speed_for_charge(_charge01))


# --- Release ---------------------------------------------------------------

## Fires the charged shot and returns a report:
## [codeblock]
## {
##   accepted: bool, reason: StringName, shot_id: int,
##   charge: float, speed_mps: float, threshold_mps: float,
##   will_transform: bool, perfect: bool, dry_fire: bool,
##   direction: Vector3, origin: Vector3,
## }
## [/codeblock]
func release() -> Dictionary:
	if not _charging:
		return _report(false, &"not_charging")

	var charge := _charge01
	var speed := charge_config.speed_for_charge(charge)
	var threshold := get_threshold()

	_charging = false
	set_physics_process(false)

	var reason := _rejection_reason()
	if reason != &"ok":
		var rejected := _report(false, reason, charge, speed, threshold)
		fire_rejected.emit(reason)
		fired.emit(rejected)
		return rejected

	var report := _report(true, &"ok", charge, speed, threshold)
	report["origin"] = get_muzzle_transform().origin
	report["direction"] = get_fire_direction()

	var launch := _try_launch(report)
	report.merge(launch, true)

	fired.emit(report)
	if not report["accepted"]:
		fire_rejected.emit(report["reason"])
	return report


func _report(
	accepted: bool,
	reason: StringName,
	charge := 0.0,
	speed := 0.0,
	threshold := -1.0,
) -> Dictionary:
	if threshold < 0.0:
		threshold = get_threshold()
	return {
		"accepted": accepted,
		"reason": reason,
		"shot_id": 0,
		"charge": charge,
		"speed_mps": speed,
		"threshold_mps": threshold,
		"will_transform": speed >= threshold,
		"perfect": charge_config.is_perfect(charge),
		"dry_fire": false,
		"origin": get_muzzle_transform().origin,
		"direction": get_fire_direction(),
	}


## Hands the shot to Codex's launcher when it exists. Resolved by path rather
## than by class so this script parses without B0 present.
func _try_launch(report: Dictionary) -> Dictionary:
	_resolve_launcher()

	if _launcher_script == null or _request_script == null:
		if allow_dry_fire:
			return {"accepted": true, "reason": &"dry_fire", "dry_fire": true}
		return {"accepted": false, "reason": &"launcher_missing"}

	var instance: Object = _active_instance()
	if instance == null and not allow_dry_fire:
		return {"accepted": false, "reason": &"no_slug"}

	var request: Object = _request_script.new()
	request.set(&"instance", instance)
	request.set(&"source", _source)
	request.set(&"source_id", &"player")
	request.set(&"muzzle_transform", get_muzzle_transform())
	request.set(&"direction", report["direction"])
	request.set(&"speed_mps", report["speed_mps"])
	request.set(&"parent", _resolve_projectile_parent())

	var result: Object = _launcher_script.call(&"launch", request)
	if result == null:
		return {"accepted": false, "reason": &"launch_failed"}

	return {
		"accepted": bool(result.get(&"accepted")),
		"reason": result.get(&"reason"),
		"shot_id": int(result.get(&"shot_id")),
	}


func _resolve_launcher() -> void:
	if _launcher_checked:
		return
	_launcher_checked = true
	if ResourceLoader.exists(LAUNCHER_SCRIPT_PATH):
		_launcher_script = load(LAUNCHER_SCRIPT_PATH) as Script
	if ResourceLoader.exists(LAUNCH_REQUEST_SCRIPT_PATH):
		_request_script = load(LAUNCH_REQUEST_SCRIPT_PATH) as Script


## Lets a test or a later integration point drop in the real scripts without
## restarting, and lets tests inject doubles.
func set_launch_scripts(launcher: Script, request: Script) -> void:
	_launcher_script = launcher
	_request_script = request
	_launcher_checked = true


func _resolve_projectile_parent() -> Node:
	if not projectile_parent_path.is_empty():
		var explicit := get_node_or_null(projectile_parent_path)
		if explicit != null:
			return explicit
	var group := get_tree().get_first_node_in_group(&"projectile_container")
	if group != null:
		return group
	return get_tree().current_scene


# --- Queries ---------------------------------------------------------------

func get_muzzle_transform() -> Transform3D:
	return muzzle.global_transform if muzzle != null else global_transform


## Aim from the muzzle at whatever the crosshair is over, so an over-shoulder
## camera still shoots where the reticle sits.
func get_fire_direction() -> Vector3:
	if _camera_rig == null:
		return -get_muzzle_transform().basis.z
	var target := _camera_rig.get_aim_point()
	var origin := get_muzzle_transform().origin
	var direction := target - origin
	if direction.length_squared() < 0.000001:
		return _camera_rig.get_aim_direction()
	return direction.normalized()


## The equipped slug's own transformation threshold, or the config's display
## fallback when nothing is equipped yet.
func get_threshold() -> float:
	var instance := _active_instance()
	if instance != null:
		var data: Object = instance.get(&"data")
		if data != null:
			var threshold: Variant = data.get(&"velocity_threshold")
			if threshold != null and threshold is float and threshold > 0.0:
				return threshold
	return charge_config.reference_threshold


## Where the threshold notch belongs on the charge meter, 0..1.
func get_threshold_marker() -> float:
	return charge_config.charge_for_speed(get_threshold())


func _active_instance() -> Object:
	if _belt == null or not _belt.has_method("get_active"):
		return null
	return _belt.call("get_active")


func _rejection_reason() -> StringName:
	var instance := _active_instance()
	if instance == null:
		return &"ok" if allow_dry_fire else &"no_slug"
	if instance.get(&"is_ghouled"):
		return &"ghouled"
	if instance.has_method("is_ready") and not instance.call("is_ready"):
		return &"unavailable"
	return &"ok"
