@tool
class_name MovementConfig
extends Resource
## Tuning numbers for a [MovementProvider]. Content, not code - every value here
## is meant to be changed in the inspector during playtesting without touching a
## script. The Mecha Beast (M3) gets its own .tres rather than new constants.

@export_group("Speeds", "")
## Default ground speed with no modifier held.
@export_range(0.5, 20.0, 0.1) var walk_speed := 4.5
## Speed while `sprint` is held.
@export_range(0.5, 30.0, 0.1) var run_speed := 7.5
## Speed cap while aiming. Slower than walking so aiming is a commitment.
@export_range(0.5, 20.0, 0.1) var aim_speed := 3.0

@export_group("Acceleration", "")
## Approach rate toward the target velocity, m/s^2.
@export_range(1.0, 200.0, 0.5) var acceleration := 30.0
## Approach rate toward zero when there is no input, m/s^2.
@export_range(1.0, 200.0, 0.5) var deceleration := 40.0
## Multiplier applied to both rates while airborne.
@export_range(0.0, 1.0, 0.01) var air_control := 0.4
## Yaw turn rate of the visual mesh, degrees per second.
@export_range(90.0, 3600.0, 10.0) var turn_speed_deg := 720.0

@export_group("Jump", "")
## Upward velocity applied on jump, m/s.
@export_range(0.5, 20.0, 0.1) var jump_velocity := 5.5
## Multiplies [member ProjectSettings] physics/3d/default_gravity.
@export_range(0.0, 5.0, 0.05) var gravity_scale := 1.0
## Grace period after walking off a ledge during which jump still works.
@export_range(0.0, 0.5, 0.01) var coyote_time := 0.12
## How early a jump press is remembered before landing.
@export_range(0.0, 0.5, 0.01) var jump_buffer := 0.12
## Rising velocity is multiplied by this when jump is released early, giving
## variable jump height. 1.0 disables the cut.
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier := 0.45
## Downward speed cap, m/s. Keeps a long fall from outrunning the swept
## collision on the projectile and the streaming budget in M1.
@export_range(5.0, 200.0, 1.0) var terminal_velocity := 55.0

@export_group("Ground", "")
## Slopes steeper than this are not walkable.
@export_range(10.0, 80.0, 1.0) var max_slope_deg := 46.0
## Downward velocity held while grounded so the body stays snapped to the floor.
@export_range(0.0, 5.0, 0.05) var ground_stick_speed := 0.1
## Planar speed under which the player counts as IDLE.
@export_range(0.0, 2.0, 0.01) var idle_speed_epsilon := 0.15


## Resolved gravity in m/s^2, honouring [member gravity_scale].
func gravity() -> float:
	var base: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	return base * gravity_scale
