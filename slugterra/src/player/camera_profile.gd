@tool
class_name CameraProfile
extends Resource
## One camera framing, as content. The design doc calls for `explore`, `aim` and
## `duel` as .tres files that the rig tween-blends between.

@export_group("Framing", "")
## Distance from the pivot to the camera before occlusion pulls it in.
@export_range(0.5, 12.0, 0.1) var arm_length := 3.5
## Over-shoulder offset in metres: x is right of centre, y is above the pivot.
@export var shoulder_offset := Vector2.ZERO
## Height of the look pivot above the player's feet.
@export_range(0.0, 3.0, 0.05) var pivot_height := 1.6
@export_range(30.0, 110.0, 0.5) var fov := 75.0

@export_group("Look", "")
## Degrees of rotation per pixel of mouse motion.
@export_range(0.01, 1.0, 0.01) var sensitivity := 0.12
@export_range(-89.0, 0.0, 1.0) var pitch_min_deg := -60.0
@export_range(0.0, 89.0, 1.0) var pitch_max_deg := 70.0

@export_group("Feel", "")
## Seconds for the rig to blend into this profile from another one.
@export_range(0.0, 1.5, 0.01) var blend_time := 0.25
## Positional lag on the pivot. 0 is rigid; small values soften hard stops.
@export_range(0.0, 0.5, 0.01) var follow_lag := 0.0

@export_group("Occlusion", "")
## When the spring arm is pulled in closer than this, the player mesh fades out
## instead of the camera clipping through it. Caverns are all tight tunnels, so
## a hard SpringArm collapse alone reads as nauseating.
@export_range(0.0, 5.0, 0.1) var occlusion_fade_distance := 1.2
## Arm length at which the player mesh is fully invisible.
@export_range(0.0, 3.0, 0.05) var occlusion_hide_distance := 0.45


## Linear blend between two profiles. Returns a new, unsaved resource; the rig
## uses it as a scratch value and never writes it to disk.
static func blend(a: CameraProfile, b: CameraProfile, t: float) -> CameraProfile:
	var out := CameraProfile.new()
	if a == null and b == null:
		return out
	if a == null:
		return b.duplicate() as CameraProfile
	if b == null:
		return a.duplicate() as CameraProfile

	t = clampf(t, 0.0, 1.0)
	out.arm_length = lerpf(a.arm_length, b.arm_length, t)
	out.shoulder_offset = a.shoulder_offset.lerp(b.shoulder_offset, t)
	out.pivot_height = lerpf(a.pivot_height, b.pivot_height, t)
	out.fov = lerpf(a.fov, b.fov, t)
	out.sensitivity = lerpf(a.sensitivity, b.sensitivity, t)
	out.pitch_min_deg = lerpf(a.pitch_min_deg, b.pitch_min_deg, t)
	out.pitch_max_deg = lerpf(a.pitch_max_deg, b.pitch_max_deg, t)
	out.blend_time = lerpf(a.blend_time, b.blend_time, t)
	out.follow_lag = lerpf(a.follow_lag, b.follow_lag, t)
	out.occlusion_fade_distance = lerpf(
		a.occlusion_fade_distance, b.occlusion_fade_distance, t
	)
	out.occlusion_hide_distance = lerpf(
		a.occlusion_hide_distance, b.occlusion_hide_distance, t
	)
	return out
