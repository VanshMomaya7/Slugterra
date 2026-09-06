class_name HUD
extends CanvasLayer
## Binds the HUD widgets to the player's blaster and belt.
##
## Finds the player by group rather than by a hardcoded path, so the same HUD
## drops into the M0 arena, the Quiet Lawn scene and any test scene without
## edits. Every lookup is defensive: the HUD must never be the reason a scene
## fails to boot.
##
## Blaster signals are consumed directly here (charge level is player-local and
## per-frame). World events - transforms, hits, availability - come from the
## EventBus autoload when it is registered, resolved at runtime so this script
## parses whether or not the autoload exists yet.

@export var player_group: StringName = &"player"
@export var charge_meter_path: NodePath = ^"Root/ChargeMeter"
@export var crosshair_path: NodePath = ^"Root/Crosshair"
@export var shot_feedback_path: NodePath = ^"Root/ShotFeedback"
@export var belt_strip_path: NodePath = ^"Root/BeltStrip"
@export var debug_overlay_path: NodePath = ^"Root/DebugOverlay"
@export var ammo_wheel_path: NodePath = ^"Root/AmmoWheel"

var _player: Node
var _blaster: Object
var _belt: Object
var _camera_rig: CameraRig

var _charge_meter: ChargeMeter
var _crosshair: Crosshair
var _shot_feedback: ShotFeedback
var _belt_strip: BeltStrip
var _debug_overlay: DebugOverlay
var _ammo_wheel: AmmoWheel


func _ready() -> void:
	_charge_meter = get_node_or_null(charge_meter_path) as ChargeMeter
	_crosshair = get_node_or_null(crosshair_path) as Crosshair
	_shot_feedback = get_node_or_null(shot_feedback_path) as ShotFeedback
	_belt_strip = get_node_or_null(belt_strip_path) as BeltStrip
	_debug_overlay = get_node_or_null(debug_overlay_path) as DebugOverlay
	_ammo_wheel = get_node_or_null(ammo_wheel_path) as AmmoWheel

	# The player may be added after the HUD; retry once the tree settles.
	if not _try_bind_player():
		get_tree().process_frame.connect(_retry_bind, CONNECT_ONE_SHOT)

	_connect_event_bus()


func _retry_bind() -> void:
	if not _try_bind_player():
		push_warning("HUD found no node in group '%s'; widgets stay idle." % player_group)


func _try_bind_player() -> bool:
	_player = get_tree().get_first_node_in_group(player_group)
	if _player == null:
		return false

	if _player.has_method("get_blaster"):
		_blaster = _player.call("get_blaster")
	if _player.has_method("get_belt"):
		_belt = _player.call("get_belt")
	if _player.has_method("get_camera_rig"):
		_camera_rig = _player.call("get_camera_rig") as CameraRig

	_connect_blaster()

	if _belt_strip != null:
		_belt_strip.bind_belt(_belt)

	if _ammo_wheel != null:
		_ammo_wheel.bind(_belt, _blaster)
		# Committing a new slot changes the equipped slug, and the notch belongs
		# to that slug's own threshold.
		_ammo_wheel.closed.connect(func(_index: int) -> void: _refresh_threshold())

	if _camera_rig != null and _crosshair != null:
		_camera_rig.profile_changed.connect(_on_camera_profile_changed)

	if _debug_overlay != null:
		_debug_overlay.player = _player
		_debug_overlay.blaster = _blaster

	_refresh_threshold()
	return true


func _connect_blaster() -> void:
	if _blaster == null:
		return
	_blaster.connect("charge_started", _on_charge_started)
	_blaster.connect("charge_changed", _on_charge_changed)
	_blaster.connect("charge_cancelled", _on_charge_cancelled)
	_blaster.connect("fired", _on_fired)
	_blaster.connect("fire_rejected", _on_fire_rejected)


## Resolved by path: autoload globals are only valid identifiers once they are
## registered in project.godot, and registration is Codex's (S1).
func _connect_event_bus() -> void:
	var bus := get_node_or_null(^"/root/EventBus")
	if bus == null:
		return
	if bus.has_signal("slug_availability_changed"):
		bus.connect("slug_availability_changed", _on_availability_changed)


func _on_availability_changed(_instance: Object) -> void:
	if _belt_strip != null:
		_belt_strip.queue_redraw()
	_refresh_threshold()


func _on_camera_profile_changed(id: StringName) -> void:
	if _crosshair != null:
		_crosshair.set_aiming(id == CameraRig.PROFILE_AIM)


## The notch belongs to the equipped slug, so it moves when the belt does.
func _refresh_threshold() -> void:
	if _charge_meter == null or _blaster == null:
		return
	if not _blaster.has_method("get_threshold_marker"):
		return
	_charge_meter.set_threshold(
		float(_blaster.call("get_threshold_marker")),
		float(_blaster.call("get_threshold"))
	)


func _on_charge_started() -> void:
	_refresh_threshold()
	if _charge_meter != null:
		_charge_meter.begin()


func _on_charge_changed(charge01: float, projected_speed_mps: float) -> void:
	if _charge_meter != null:
		_charge_meter.set_charge(charge01, projected_speed_mps)


func _on_charge_cancelled() -> void:
	if _charge_meter != null:
		_charge_meter.finish(0.15)


func _on_fired(report: Dictionary) -> void:
	if _charge_meter != null:
		_charge_meter.finish()
	if _shot_feedback != null:
		_shot_feedback.show_shot(report)


func _on_fire_rejected(reason: StringName) -> void:
	# A release already reports through `fired`; this only covers a refused
	# charge start, which never produces a report.
	if reason == &"not_charging":
		return
	if _shot_feedback != null and not _shot_feedback.is_processing():
		_shot_feedback.show_shot({"accepted": false, "reason": reason})
