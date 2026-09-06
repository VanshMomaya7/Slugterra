class_name PlayerController
extends CharacterBody3D
## Eli Shane. Owns the body, gathers input, and delegates.
##
## Deliberately thin. Movement maths lives in the active [MovementProvider],
## framing in [CameraRig], and the charge/fire loop in [Blaster]. The controller
## routes input and derives state; it does not implement any of those three.
##
## The body itself never rotates - only `Visual` does. That keeps the camera rig
## (a child) independent of which way the character is facing, which is what
## makes over-shoulder aiming work without fighting the movement code.

signal state_changed(from: int, to: int)
signal mouse_capture_changed(captured: bool)

@export_group("Wiring", "")
@export var movement_root_path: NodePath = ^"Movement"
@export var camera_rig_path: NodePath = ^"CameraRig"
@export var blaster_path: NodePath = ^"Blaster"
@export var belt_path: NodePath = ^"Belt"
@export var visual_path: NodePath = ^"Visual"

@export_group("Behaviour", "")
## Capture the mouse as soon as the scene runs. Off for tests and tooling.
@export var capture_mouse_on_ready := true
## Rotate the visual mesh to face the camera while aiming.
@export var face_camera_while_aiming := true

var state: int = PlayerStates.State.IDLE

var _providers: Array[MovementProvider] = []
var _active_provider: MovementProvider
var _intent := MoveIntent.new()

var _camera_rig: CameraRig
var _blaster: Node
var _belt: Node
var _visual: Node3D

var _visual_yaw := 0.0
var _mouse_captured := false


func _ready() -> void:
	PlayerInput.verify()

	_camera_rig = get_node_or_null(camera_rig_path) as CameraRig
	_blaster = get_node_or_null(blaster_path)
	_belt = get_node_or_null(belt_path)
	_visual = get_node_or_null(visual_path) as Node3D

	_collect_providers()
	if not _providers.is_empty():
		set_movement_provider(_providers[0])
	else:
		push_warning("PlayerController has no MovementProvider; the body will not move.")

	_wire_blaster()

	if capture_mouse_on_ready:
		set_mouse_captured(true)


func _collect_providers() -> void:
	_providers.clear()
	var root := get_node_or_null(movement_root_path)
	if root == null:
		return
	for child in root.get_children():
		var provider := child as MovementProvider
		if provider != null:
			_providers.append(provider)


## Injects the belt and camera the blaster needs. Duck-typed on purpose: the
## blaster's launch path and SlugBelt are Codex's (B0/C0), and this scene must
## still load and run before those scripts exist.
func _wire_blaster() -> void:
	if _blaster == null:
		return
	if _blaster.has_method("bind"):
		_blaster.call("bind", _belt, _camera_rig, self)


## Swaps the movement provider. Mecha Beast riding (M3) calls this rather than
## adding a mounted branch to this script.
func set_movement_provider(provider: MovementProvider) -> void:
	if provider == _active_provider:
		return
	if _active_provider != null:
		_active_provider.deactivate(self)
	_active_provider = provider
	if _active_provider != null:
		_active_provider.activate(self)


func set_movement_provider_by_id(id: StringName) -> bool:
	for provider in _providers:
		if provider.provider_id == id:
			set_movement_provider(provider)
			return true
	return false


func get_movement_provider() -> MovementProvider:
	return _active_provider


func get_camera_rig() -> CameraRig:
	return _camera_rig


func get_blaster() -> Node:
	return _blaster


func get_belt() -> Node:
	return _belt


# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured and _camera_rig != null:
		_camera_rig.add_look_from_mouse((event as InputEventMouseMotion).relative)
		return

	if event.is_action_pressed(PlayerInput.UI_CANCEL):
		set_mouse_captured(false)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if not _mouse_captured:
			set_mouse_captured(true)
			get_viewport().set_input_as_handled()


func set_mouse_captured(captured: bool) -> void:
	if _mouse_captured == captured:
		return
	_mouse_captured = captured
	Input.mouse_mode = (
		Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	)
	mouse_capture_changed.emit(captured)


func is_mouse_captured() -> bool:
	return _mouse_captured


func _gather_intent() -> void:
	_intent.clear()
	if not _mouse_captured:
		# Menus and the pause state should not drive the body, but gravity and
		# deceleration still need to run, so the intent is zeroed rather than
		# skipping the physics step entirely.
		if _camera_rig != null:
			_intent.look_basis = _camera_rig.get_yaw_basis()
		return

	_intent.move_axis = PlayerInput.move_vector()
	_intent.jump_pressed = PlayerInput.just_pressed(PlayerInput.JUMP)
	_intent.jump_held = PlayerInput.pressed(PlayerInput.JUMP)
	_intent.sprint = PlayerInput.pressed(PlayerInput.SPRINT)
	_intent.aim = PlayerInput.pressed(PlayerInput.AIM)
	if _camera_rig != null:
		_intent.look_basis = _camera_rig.get_yaw_basis()


# --- Physics ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_gather_intent()

	if _active_provider != null:
		_active_provider.apply(self, _intent, delta)
	move_and_slide()

	_update_camera_profile()
	_update_facing(delta)
	_update_state()
	_route_fire_input()


func _update_camera_profile() -> void:
	if _camera_rig == null:
		return
	var wanted := CameraRig.PROFILE_AIM if _intent.aim else CameraRig.PROFILE_EXPLORE
	if _camera_rig.get_profile_id() != wanted:
		_camera_rig.set_profile(wanted)


## Turns the mesh, never the body. While aiming the character faces where the
## camera looks so the over-shoulder shot reads correctly.
func _update_facing(delta: float) -> void:
	if _visual == null:
		return

	var config := _movement_config()
	var turn_rate := deg_to_rad(config.turn_speed_deg) if config != null else TAU

	var target_dir := Vector3.ZERO
	if face_camera_while_aiming and _intent.aim and _camera_rig != null:
		target_dir = -_camera_rig.get_yaw_basis().z
	else:
		var planar := Vector3(velocity.x, 0.0, velocity.z)
		if planar.length_squared() > 0.01:
			target_dir = planar.normalized()

	if target_dir.length_squared() > 0.0:
		# Godot's forward is -Z, so yaw is measured off the negated direction.
		_visual_yaw = rotate_toward(
			_visual_yaw, atan2(-target_dir.x, -target_dir.z), turn_rate * delta
		)
	_visual.rotation.y = _visual_yaw


func _movement_config() -> MovementConfig:
	var ground := _active_provider as GroundMovementProvider
	return ground.config if ground != null else null


func _update_state() -> void:
	var next := state
	if _active_provider != null:
		next = _active_provider.suggested_state(self, _intent)

	# Charging outranks the movement state: the HUD and later the animation
	# tree both key off FIRE.
	if _blaster != null and _blaster.has_method("is_charging") and _blaster.call("is_charging"):
		next = PlayerStates.State.FIRE

	if next != state:
		var previous := state
		state = next
		state_changed.emit(previous, next)


## Hold to charge, release to fire. The blaster owns everything past this point.
func _route_fire_input() -> void:
	if _blaster == null or not _mouse_captured:
		return

	if PlayerInput.just_pressed(PlayerInput.FIRE):
		if _blaster.has_method("begin_charge"):
			_blaster.call("begin_charge")
	elif PlayerInput.just_released(PlayerInput.FIRE):
		if _blaster.has_method("release"):
			_blaster.call("release")
