class_name PlayerStates
extends RefCounted
## Shared player state enum.
##
## Lives in its own script so [MovementProvider] and [PlayerController] can both
## name states without a cyclic `class_name` dependency (Godot rejects those).
##
## M0 implements IDLE, WALK, RUN, JUMP, FALL, AIM and FIRE. CLIMB, SLIDE,
## MOUNTED, STAGGERED and GHOULED exist as values only, so later milestones can
## add behaviour without renumbering anything already persisted or logged.

enum State {
	IDLE,
	WALK,
	RUN,
	JUMP,
	FALL,
	CLIMB,
	SLIDE,
	AIM,
	FIRE,
	MOUNTED,
	STAGGERED,
	GHOULED,
}

const STATE_NAMES: Array[StringName] = [
	&"IDLE", &"WALK", &"RUN", &"JUMP", &"FALL", &"CLIMB",
	&"SLIDE", &"AIM", &"FIRE", &"MOUNTED", &"STAGGERED", &"GHOULED",
]


static func to_name(state: int) -> StringName:
	if state < 0 or state >= STATE_NAMES.size():
		return &"UNKNOWN"
	return STATE_NAMES[state]


## True while the player is off the ground.
static func is_airborne(state: int) -> bool:
	return state == State.JUMP or state == State.FALL


## True while the player cannot act on their own input.
static func is_locked_out(state: int) -> bool:
	return state == State.STAGGERED or state == State.GHOULED
