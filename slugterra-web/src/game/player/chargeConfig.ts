/**
 * The 100 mph rule, as data.
 *
 * Hold to charge, release to fire. Muzzle speed is
 * `lerp(minSpeed, maxSpeed, curve(charge))`. A slug becomes a Velocimorph at or
 * above its threshold (canon: 100 mph = 44.7 m/s) and duds below it, so the
 * region of the meter under the threshold is the game's core skill gate — a
 * panic shot genuinely fizzles.
 *
 * Ported verbatim from the Godot build's `data/player/charge_default.tres` so
 * the two builds feel identical and playtest notes transfer between them.
 *
 * Blaster upgrades (Red Hook, Kord) are new instances of this object: a faster
 * `chargeTime`, a higher `maxSpeed`, a wider `perfectWindow`. No system code
 * changes to add a blaster tier.
 */

/** Canon: 100 mph. */
export const VELOCITY_THRESHOLD = 44.7;

export const MPS_TO_MPH = 2.236936;

export const mpsToMph = (mps: number): number => mps * MPS_TO_MPH;
export const mphToMps = (mph: number): number => mph / MPS_TO_MPH;

export const clamp01 = (value: number): number =>
  value < 0 ? 0 : value > 1 ? 1 : value;

/**
 * Maps charge 0..1 to a 0..1 blend between the speeds. Must be monotonic and
 * pass through (0,0) and (1,1).
 */
export type ChargeCurve = (t: number) => number;

/**
 * The shipped response curve.
 *
 * In Hermite form this is tangents 0.6 and 1.4 on the unit interval, which
 * reduces exactly to `0.4t² + 0.6t`. Monotonic on [0,1] (derivative
 * `0.8t + 0.6` is always positive) and passes through both endpoints.
 *
 * With 20 → 62 m/s it places the 44.7 m/s notch at t ≈ 0.676, i.e. ~0.41 s of
 * the 0.6 s charge. The dud band is deliberately the larger part of the meter.
 */
export const easeInCharge: ChargeCurve = (t) => {
  const c = clamp01(t);
  return 0.4 * c * c + 0.6 * c;
};

/** Straight line, for tests and for upgrades that want a flat response. */
export const linearCharge: ChargeCurve = clamp01;

export interface ChargeConfig {
  /** Seconds of holding to reach full charge. */
  readonly chargeTime: number;
  readonly curve: ChargeCurve;
  /** Muzzle speed at zero charge. 20 m/s is 45 mph — always a dud. */
  readonly minSpeed: number;
  /** Muzzle speed at full charge. 62 m/s is 139 mph — comfortably over. */
  readonly maxSpeed: number;
  /**
   * Fraction of the top of the charge range that counts as a perfect release
   * and earns a damage bonus. 0 disables it; upgrades widen it.
   */
  readonly perfectWindow: number;
  readonly perfectBonus: number;
  /**
   * Display-only fallback threshold, m/s, used by the HUD to place the notch
   * when no slug is equipped. The real threshold always comes from
   * `SlugData.velocityThreshold`; this never decides whether a shot transforms.
   */
  readonly referenceThreshold: number;
}

export const DEFAULT_CHARGE: ChargeConfig = {
  chargeTime: 0.6,
  curve: easeInCharge,
  minSpeed: 20,
  maxSpeed: 62,
  perfectWindow: 0,
  perfectBonus: 1.25,
  referenceThreshold: VELOCITY_THRESHOLD,
};

/** Muzzle speed in m/s for a normalised charge. */
export function speedForCharge(config: ChargeConfig, charge01: number): number {
  const blend = clamp01(config.curve(clamp01(charge01)));
  return config.minSpeed + (config.maxSpeed - config.minSpeed) * blend;
}

/**
 * Inverse of {@link speedForCharge}: the charge needed to reach `speed`.
 *
 * Drives the threshold notch, so it has to be exact rather than eyeballed — a
 * notch drawn in the wrong place teaches the player the wrong timing.
 * Bisection, because the curve is arbitrary but monotonic. Returns 0 when the
 * speed is already reachable at rest and 1 when it is out of range entirely.
 */
export function chargeForSpeed(config: ChargeConfig, speed: number): number {
  if (speed <= config.minSpeed) return 0;
  if (speed >= config.maxSpeed) return 1;

  let lo = 0;
  let hi = 1;
  // 32 halvings resolves well past float precision on a 0..1 range.
  for (let i = 0; i < 32; i += 1) {
    const mid = (lo + hi) * 0.5;
    if (speedForCharge(config, mid) < speed) lo = mid;
    else hi = mid;
  }
  return (lo + hi) * 0.5;
}

/**
 * Where the threshold notch belongs on the meter, 0..1. Pass the equipped
 * slug's own threshold; omit it to use the config's display fallback.
 */
export function thresholdMarker(config: ChargeConfig, thresholdMps?: number): number {
  return chargeForSpeed(config, thresholdMps ?? config.referenceThreshold);
}

/** True when this charge would clear the threshold. Inclusive, per contract. */
export function clearsThreshold(
  config: ChargeConfig,
  charge01: number,
  thresholdMps?: number,
): boolean {
  return speedForCharge(config, charge01) >= (thresholdMps ?? config.referenceThreshold);
}

/** True when the release landed in the perfect window at the top of the charge. */
export function isPerfect(config: ChargeConfig, charge01: number): boolean {
  if (config.perfectWindow <= 0) return false;
  return charge01 >= 1 - config.perfectWindow;
}

/** Charge reached after holding for `seconds`, clamped to full. */
export function chargeAfter(config: ChargeConfig, seconds: number): number {
  if (config.chargeTime <= 0) return 1;
  return clamp01(seconds / config.chargeTime);
}
