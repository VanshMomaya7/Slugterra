class_name MovementProvider
extends Node
## Base class for anything that decides how the player body moves.
##
## The design doc calls for this interface on day one so mounted traversal
## (Mecha Beast, M3) swaps the provider instead of adding branches to a growing
## `_physics_process`. [PlayerController] owns the body and calls
## [method move_and_slide]; a provider only ever writes [member
## CharacterBody3D.velocity].
##
## Contract for subclasses:
## [br]- [method apply] writes velocity and nothing else. It must not move,
##   rotate or reparent the body, and must not call `move_and_slide`.
## [br]- [method apply] must tolerate being called with a zeroed [MoveIntent]
##   (cutscenes, stagger, menus) and produce sane velocity.
## [br]- [method activate] / [method deactivate] are where per-provider body
##   settings (floor angle, snap length) are pushed and restored.

## Emitted when this provider wants the controller to notice a discrete event -
## a jump leaving the ground, a mount dismounting. M0 only uses `&"jump"`.
signal movement_event(event: StringName)

## Human-readable id, used in the debug overlay and in save data later.
@export var provider_id: StringName = &"base"

var _active := false


func is_active() -> bool:
	return _active


## Called when the controller selects this provider. Push body settings here.
func activate(body: CharacterBody3D) -> void:
	_active = true


## Called when the controller selects a different provider. Restore anything
## [method activate] changed so providers cannot leak state into each other.
func deactivate(body: CharacterBody3D) -> void:
	_active = false


## Writes `body.velocity` for this physics step. Must not call move_and_slide().
func apply(body: CharacterBody3D, intent: MoveIntent, delta: float) -> void:
	pass


## The [enum PlayerStates.State] this provider believes the body is in.
## The controller may override it (FIRE while charging, STAGGERED on hit).
func suggested_state(body: CharacterBody3D, intent: MoveIntent) -> int:
	return PlayerStates.State.IDLE


## Speed cap this provider is currently honouring, for HUD and debug readouts.
func current_speed_limit(intent: MoveIntent) -> float:
	return 0.0
