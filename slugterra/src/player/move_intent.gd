class_name MoveIntent
extends RefCounted
## One frame of movement input, decoupled from where that input came from.
##
## [PlayerController] fills this from the input map; an NPC or a cutscene can
## fill the same struct from anywhere. A [MovementProvider] only ever reads it,
## which is what lets Mecha Beast riding (M3) swap the provider instead of
## adding mount branches to the controller.
##
## The controller reuses a single instance and calls [method clear] each frame,
## so this allocates once rather than every physics tick.

## Strafe on x, forward on y. Range -1..1, already deadzoned.
var move_axis := Vector2.ZERO

## Yaw-only camera basis. Providers resolve [member move_axis] against this so
## "forward" means "away from the camera", not "along world -Z".
var look_basis := Basis.IDENTITY

## Jump was pressed this frame (edge).
var jump_pressed := false

## Jump is still held (level) - used for variable jump height.
var jump_held := false

var sprint := false

var aim := false


func clear() -> void:
	move_axis = Vector2.ZERO
	look_basis = Basis.IDENTITY
	jump_pressed = false
	jump_held = false
	sprint = false
	aim = false


## True when the player is asking to move at all.
func has_move_input() -> bool:
	return move_axis.length_squared() > 0.0


## [member move_axis] resolved into a world-space direction on the XZ plane.
## Returns a zero vector when there is no input; never longer than 1.
func world_direction() -> Vector3:
	if not has_move_input():
		return Vector3.ZERO

	var forward := -look_basis.z
	forward.y = 0.0
	var right := look_basis.x
	right.y = 0.0

	if forward.length_squared() < 0.000001 or right.length_squared() < 0.000001:
		# Looking straight up or down: the yaw basis degenerates. Fall back to
		# world axes rather than emitting a NaN direction.
		forward = Vector3.FORWARD
		right = Vector3.RIGHT
	else:
		forward = forward.normalized()
		right = right.normalized()

	var dir := right * move_axis.x + forward * move_axis.y
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	return dir
