@tool
class_name ChargeConfig
extends Resource
## The 100 mph rule, as data.
##
## Hold to charge, release to fire. Muzzle speed is
## `lerp(min_speed, max_speed, curve.sample(charge))`. A slug transforms into a
## Velocimorph at or above its threshold (canon: 100 mph = 44.7 m/s) and duds
## below it, so the region of the charge meter under the threshold is the
## game's core skill gate - a panic shot genuinely fizzles.
##
## Blaster upgrades from Red Hook and Kord are new instances of this resource:
## a faster [member charge_time], a higher [member max_speed], or a wider
## [member perfect_window]. No system code changes to add a blaster tier.

## Seconds of holding to reach full charge.
@export_range(0.05, 3.0, 0.01) var charge_time := 0.6

## Maps charge 0..1 to a 0..1 blend between the speeds. Must be monotonic and
## should pass through (0,0) and (1,1). Null falls back to linear.
@export var curve: Curve

## Muzzle speed at zero charge. 20 m/s is 45 mph - well under the threshold, so
## a tap fire is always a dud.
@export_range(1.0, 100.0, 0.1) var min_speed := 20.0

## Muzzle speed at full charge. 62 m/s is 139 mph - comfortably over.
@export_range(1.0, 200.0, 0.1) var max_speed := 62.0

## Fraction of the charge range at the top that counts as a perfect release and
## earns a damage bonus. 0 disables it; upgrades widen it.
@export_range(0.0, 0.5, 0.01) var perfect_window := 0.0

## Damage multiplier granted inside [member perfect_window].
@export_range(1.0, 3.0, 0.05) var perfect_bonus := 1.25

## Display-only fallback threshold, m/s. Used by the HUD to place the notch when
## no slug is equipped yet. The real threshold always comes from
## `SlugData.velocity_threshold` per breed; this is never used to decide whether
## a shot actually transforms.
@export_range(1.0, 200.0, 0.1) var reference_threshold := 44.7

const MPS_TO_MPH := 2.236936


static func mps_to_mph(mps: float) -> float:
	return mps * MPS_TO_MPH


static func mph_to_mps(mph: float) -> float:
	return mph / MPS_TO_MPH


## Curve value at `charge01`, falling back to linear when no curve is assigned.
func curve_value(charge01: float) -> float:
	charge01 = clampf(charge01, 0.0, 1.0)
	if curve == null:
		return charge01
	return clampf(curve.sample_baked(charge01), 0.0, 1.0)


## Muzzle speed in m/s for a normalised charge.
func speed_for_charge(charge01: float) -> float:
	return lerpf(min_speed, max_speed, curve_value(charge01))


## Inverse of [method speed_for_charge]: the charge needed to reach `speed`.
##
## Drives the threshold notch on the charge meter, so it has to be exact rather
## than eyeballed - a notch drawn at the wrong place teaches the player the
## wrong timing. Bisection, because the curve is arbitrary but monotonic.
## Returns 0.0 when the speed is already reachable at rest and 1.0 when it is
## out of range entirely.
func charge_for_speed(speed: float) -> float:
	if speed <= min_speed:
		return 0.0
	if speed >= max_speed:
		return 1.0

	var lo := 0.0
	var hi := 1.0
	# 32 halvings resolves well past float precision on a 0..1 range.
	for _i in 32:
		var mid := (lo + hi) * 0.5
		if speed_for_charge(mid) < speed:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## Where the threshold notch sits on the meter, 0..1. Pass the equipped slug's
## own threshold; omit it to use [member reference_threshold].
func threshold_marker(threshold_mps := -1.0) -> float:
	if threshold_mps < 0.0:
		threshold_mps = reference_threshold
	return charge_for_speed(threshold_mps)


## True when this charge would clear the threshold.
func clears_threshold(charge01: float, threshold_mps := -1.0) -> bool:
	if threshold_mps < 0.0:
		threshold_mps = reference_threshold
	return speed_for_charge(charge01) >= threshold_mps


## True when the release landed in the perfect window at the top of the charge.
func is_perfect(charge01: float) -> bool:
	if perfect_window <= 0.0:
		return false
	return charge01 >= 1.0 - perfect_window


## Charge reached after holding for `seconds`, clamped to full.
func charge_after(seconds: float) -> float:
	if charge_time <= 0.0:
		return 1.0
	return clampf(seconds / charge_time, 0.0, 1.0)
