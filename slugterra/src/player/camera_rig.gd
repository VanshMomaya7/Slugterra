class_name CameraRig
extends Node3D
## Third-person spring-arm camera with tween-blended profiles.
##
## Node layout (see camera_rig.tscn):
## [codeblock]
## CameraRig   <- yaw lives here
## └── Pivot       <- pitch lives here, raised to profile.pivot_height
##     └── SpringArm3D
##         └── Camera3D   <- shoulder offset lives here
## [/codeblock]
##
## The rig is a child of the player body, and the body deliberately never
## rotates (only its Visual child does), so the rig's local yaw is world yaw.
##
## Beyond SpringArm3D's hard collapse this adds the soft occlusion fade the
## design doc asks for: in a tight tunnel the player mesh dissolves rather than
## the camera punching through it.

signal profile_changed(id: StringName)

const PROFILE_EXPLORE: StringName = &"explore"
const PROFILE_AIM: StringName = &"aim"
const PROFILE_DUEL: StringName = &"duel"

## Layers the aim raycast is allowed to hit: world(1) | npc(3) | hurtbox(5).
const AIM_RAY_MASK := 1 | 4 | 16
## Layers that collapse the spring arm: world(1) | camera_occluder(9).
const SPRING_MASK := 1 | 256
## Aim points nearer than this are pushed out, so a wall right in front of the
## camera cannot swing the muzzle direction wildly off the crosshair.
const MIN_CONVERGENCE := 1.5

@export var explore_profile: CameraProfile
@export var aim_profile: CameraProfile
@export var duel_profile: CameraProfile

## The player mesh root, faded by the soft occlusion pass. Optional.
@export var visual_root: Node3D

## Invert vertical mouse look.
@export var invert_y := false

@onready var pivot: Node3D = $Pivot
@onready var spring_arm: SpringArm3D = $Pivot/SpringArm3D
@onready var camera: Camera3D = $Pivot/SpringArm3D/Camera3D

var _profiles: Dictionary = {}
var _current_id: StringName = PROFILE_EXPLORE
var _from: CameraProfile
var _to: CameraProfile
var _live: CameraProfile
var _blend_t := 1.0
var _blend_speed := 0.0

var _yaw := 0.0
var _pitch := 0.0
var _faded: Array[GeometryInstance3D] = []


func _ready() -> void:
	_profiles = {
		PROFILE_EXPLORE: explore_profile,
		PROFILE_AIM: aim_profile,
		PROFILE_DUEL: duel_profile,
	}

	_to = _resolve(PROFILE_EXPLORE)
	_from = _to
	_live = (_to.duplicate() as CameraProfile) if _to != null else CameraProfile.new()
	_blend_t = 1.0

	spring_arm.collision_mask = SPRING_MASK
	spring_arm.spring_length = _live.arm_length

	if visual_root != null:
		_collect_fadeable(visual_root)

	# Never let the arm collide with the body it is attached to.
	var body := get_parent() as PhysicsBody3D
	if body != null:
		spring_arm.add_excluded_object(body.get_rid())

	_apply_live()


func _resolve(id: StringName) -> CameraProfile:
	var profile: CameraProfile = _profiles.get(id)
	if profile == null:
		profile = _profiles.get(PROFILE_EXPLORE)
	if profile == null:
		# No profiles assigned at all: fall back to defaults so the rig still
		# renders instead of erroring out every frame.
		profile = CameraProfile.new()
	return profile


## Blends to a named profile. A zero blend time snaps.
func set_profile(id: StringName, blend_seconds := -1.0) -> void:
	if id == _current_id and _blend_t >= 1.0:
		return

	var target := _resolve(id)
	_from = (_live.duplicate() if _live != null else target.duplicate()) as CameraProfile
	_to = target
	_current_id = id

	var duration := blend_seconds if blend_seconds >= 0.0 else target.blend_time
	if duration <= 0.0:
		_blend_t = 1.0
		_blend_speed = 0.0
	else:
		_blend_t = 0.0
		_blend_speed = 1.0 / duration

	profile_changed.emit(id)


func get_profile_id() -> StringName:
	return _current_id


func get_camera() -> Camera3D:
	return camera


## Feeds MoveIntent.look_basis: yaw only, so looking down does not shrink the
## player's forward direction.
func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, global_rotation.y)


func get_aim_origin() -> Vector3:
	return camera.global_position


func get_aim_direction() -> Vector3:
	return -camera.global_basis.z


## Where the crosshair is pointing in world space. Shots are aimed from the
## muzzle at this point, which is what makes an over-shoulder camera shoot where
## the reticle sits rather than parallel to it.
func get_aim_point(max_distance := 500.0) -> Vector3:
	var origin := get_aim_origin()
	var direction := get_aim_direction()
	var far := origin + direction * max_distance

	var world := get_world_3d()
	if world == null:
		return far

	var query := PhysicsRayQueryParameters3D.create(origin, far, AIM_RAY_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var body := get_parent() as PhysicsBody3D
	if body != null:
		query.exclude = [body.get_rid()]

	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return far

	var point: Vector3 = hit.position
	if origin.distance_to(point) < MIN_CONVERGENCE:
		return origin + direction * MIN_CONVERGENCE
	return point


## Adds yaw/pitch in degrees. Called by the controller from mouse or stick input.
func add_look(yaw_delta_deg: float, pitch_delta_deg: float) -> void:
	_yaw -= deg_to_rad(yaw_delta_deg)
	var pitch_sign := 1.0 if invert_y else -1.0
	_pitch += pitch_sign * deg_to_rad(pitch_delta_deg)
	_clamp_pitch()


## Mouse motion in pixels, scaled by the live profile's sensitivity.
func add_look_from_mouse(relative: Vector2) -> void:
	var sensitivity := _live.sensitivity if _live != null else 0.12
	add_look(relative.x * sensitivity, relative.y * sensitivity)


func _clamp_pitch() -> void:
	var lo := deg_to_rad(_live.pitch_min_deg) if _live != null else -1.05
	var hi := deg_to_rad(_live.pitch_max_deg) if _live != null else 1.22
	_pitch = clampf(_pitch, lo, hi)


func _process(delta: float) -> void:
	if _blend_t < 1.0:
		_blend_t = minf(_blend_t + _blend_speed * delta, 1.0)
		_live = CameraProfile.blend(_from, _to, _ease(_blend_t))
	elif _live == null:
		_live = _to.duplicate() as CameraProfile

	_clamp_pitch()
	_apply_live()
	_update_occlusion_fade()


## Smoothstep, so profile changes ease in and out instead of starting abruptly.
func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _apply_live() -> void:
	if _live == null:
		return
	rotation.y = _yaw
	pivot.rotation.x = _pitch
	pivot.position.y = _live.pivot_height
	spring_arm.spring_length = _live.arm_length
	camera.position = Vector3(_live.shoulder_offset.x, _live.shoulder_offset.y, 0.0)
	camera.fov = _live.fov


func _collect_fadeable(root: Node) -> void:
	var geometry := root as GeometryInstance3D
	if geometry != null:
		_faded.append(geometry)
	for child in root.get_children():
		_collect_fadeable(child)


## Fades the player mesh as the arm is squeezed shorter, so tunnels do not
## slam the camera into the inside of the capsule.
func _update_occlusion_fade() -> void:
	if _faded.is_empty() or _live == null:
		return

	var hit_length := spring_arm.get_hit_length()
	var fade_at := _live.occlusion_fade_distance
	var hide_at := _live.occlusion_hide_distance

	var transparency := 0.0
	if fade_at > hide_at and hit_length < fade_at:
		transparency = clampf(
			inverse_lerp(fade_at, hide_at, hit_length), 0.0, 1.0
		)

	for geometry in _faded:
		if is_instance_valid(geometry):
			geometry.transparency = transparency
