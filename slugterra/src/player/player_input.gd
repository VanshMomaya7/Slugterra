class_name PlayerInput
extends RefCounted
## Action-name constants and fail-soft reads for the player input map.
##
## The input map itself lives in `project.godot`, which Codex owns (S1). Until
## those actions are registered, reading them directly would push an error every
## frame. Every read here goes through a cached availability check instead: the
## game logs one warning naming the missing actions and then behaves as if they
## were unpressed, so the player scene stays runnable and testable ahead of S1.
##
## The requested bindings are specified in `docs/m0_interface_proposal.md` 2.2.
## Once S1 lands, [method missing_actions] returns empty and these helpers cost
## one dictionary lookup each.

const MOVE_FORWARD: StringName = &"move_forward"
const MOVE_BACK: StringName = &"move_back"
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const JUMP: StringName = &"jump"
const SPRINT: StringName = &"sprint"
const AIM: StringName = &"aim"
const FIRE: StringName = &"fire"
const RECALL: StringName = &"recall"
const WHEEL: StringName = &"wheel"
const BELT_NEXT: StringName = &"belt_next"
const BELT_PREV: StringName = &"belt_prev"
const INTERACT: StringName = &"interact"
const DEBUG_OVERLAY: StringName = &"debug_overlay"
const UI_CANCEL: StringName = &"ui_cancel"

## Belt slot actions are `belt_slot_1` .. `belt_slot_6`.
const BELT_SLOT_COUNT := 6

const REQUIRED: Array[StringName] = [
	MOVE_FORWARD, MOVE_BACK, MOVE_LEFT, MOVE_RIGHT,
	JUMP, SPRINT, AIM, FIRE, RECALL, WHEEL,
	BELT_NEXT, BELT_PREV, INTERACT, DEBUG_OVERLAY,
]

static var _available: Dictionary = {}
static var _verified := false


static func belt_slot(index: int) -> StringName:
	return StringName("belt_slot_%d" % (index + 1))


## Builds the availability cache and returns the actions that are not registered.
## Safe to call repeatedly; the scan only runs once per launch.
static func verify() -> PackedStringArray:
	var missing := PackedStringArray()
	if _verified:
		for action: StringName in _available:
			if not _available[action]:
				missing.append(String(action))
		return missing

	var to_check: Array[StringName] = REQUIRED.duplicate()
	for i in BELT_SLOT_COUNT:
		to_check.append(belt_slot(i))

	for action in to_check:
		var present := InputMap.has_action(action)
		_available[action] = present
		if not present:
			missing.append(String(action))

	_verified = true
	if not missing.is_empty():
		push_warning(
			"PlayerInput: %d action(s) missing from the input map; treating them as unpressed. "
			% missing.size()
			+ "Codex registers these in S1 (see docs/m0_interface_proposal.md 2.2). Missing: "
			+ ", ".join(missing)
		)
	return missing


## Forgets the cache. Tests call this after mutating [InputMap].
static func reset_cache() -> void:
	_available.clear()
	_verified = false


static func has(action: StringName) -> bool:
	if not _verified:
		verify()
	if _available.has(action):
		return _available[action]
	# An action outside the M0 set: check once and remember the answer.
	var present := InputMap.has_action(action)
	_available[action] = present
	return present


static func pressed(action: StringName) -> bool:
	return has(action) and Input.is_action_pressed(action)


static func just_pressed(action: StringName) -> bool:
	return has(action) and Input.is_action_just_pressed(action)


static func just_released(action: StringName) -> bool:
	return has(action) and Input.is_action_just_released(action)


static func axis(negative: StringName, positive: StringName) -> float:
	if not (has(negative) and has(positive)):
		return 0.0
	return Input.get_axis(negative, positive)


## Movement input as (strafe, forward), already deadzoned by the input map.
static func move_vector() -> Vector2:
	if not (
		has(MOVE_LEFT) and has(MOVE_RIGHT) and has(MOVE_FORWARD) and has(MOVE_BACK)
	):
		return Vector2.ZERO
	return Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_BACK, MOVE_FORWARD)
