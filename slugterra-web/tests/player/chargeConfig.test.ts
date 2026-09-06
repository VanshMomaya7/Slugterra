import { describe, expect, it } from 'vitest';
import {
  DEFAULT_CHARGE,
  chargeAfter,
  chargeForSpeed,
  clearsThreshold,
  isPerfect,
  linearCharge,
  mphToMps,
  mpsToMph,
  speedForCharge,
  thresholdMarker,
  VELOCITY_THRESHOLD,
  type ChargeConfig,
} from '../../src/game/player/chargeConfig';

/**
 * Ported from the Godot build's `tests/player/test_charge_config.gd`. The two
 * builds must agree on the charge maths exactly, or Tony's playtest notes stop
 * transferring between them.
 */
describe('charge curve', () => {
  const config = DEFAULT_CHARGE;

  it('hits min and max speed at the endpoints', () => {
    expect(speedForCharge(config, 0)).toBeCloseTo(config.minSpeed, 6);
    expect(speedForCharge(config, 1)).toBeCloseTo(config.maxSpeed, 6);
  });

  it('clamps charge outside 0..1', () => {
    expect(speedForCharge(config, -5)).toBeCloseTo(config.minSpeed, 6);
    expect(speedForCharge(config, 9)).toBeCloseTo(config.maxSpeed, 6);
  });

  it('is monotonic across the whole range', () => {
    let previous = -Infinity;
    for (let i = 0; i <= 200; i += 1) {
      const speed = speedForCharge(config, i / 200);
      expect(speed).toBeGreaterThanOrEqual(previous - 1e-9);
      previous = speed;
    }
  });

  it('round-trips through chargeForSpeed', () => {
    for (let i = 0; i <= 20; i += 1) {
      const target =
        config.minSpeed + ((config.maxSpeed - config.minSpeed) * i) / 20;
      const charge = chargeForSpeed(config, target);
      expect(speedForCharge(config, charge)).toBeCloseTo(target, 4);
    }
  });

  it('saturates chargeForSpeed outside the range', () => {
    expect(chargeForSpeed(config, config.minSpeed - 10)).toBe(0);
    expect(chargeForSpeed(config, config.maxSpeed + 10)).toBe(1);
  });

  it('places the notch where the Godot build places it', () => {
    // The shipped curve puts 44.7 m/s at t = 0.676 — about 0.41 s of the
    // 0.6 s charge. If this moves, the two builds no longer feel the same.
    expect(thresholdMarker(config)).toBeCloseTo(0.676, 3);
    expect(speedForCharge(config, thresholdMarker(config))).toBeCloseTo(
      VELOCITY_THRESHOLD,
      4,
    );
  });

  it('has a real dud band and a real success band', () => {
    expect(clearsThreshold(config, 0)).toBe(false);
    expect(clearsThreshold(config, 1)).toBe(true);

    const marker = thresholdMarker(config);
    expect(clearsThreshold(config, marker - 0.02)).toBe(false);
    expect(clearsThreshold(config, Math.min(marker + 0.02, 1))).toBe(true);
  });

  it('keeps the dud band as the larger part of the meter', () => {
    // Design intent: a panic shot has to fizzle.
    expect(thresholdMarker(config)).toBeGreaterThan(0.5);
  });

  it('moves the notch with a per-slug threshold', () => {
    expect(thresholdMarker(config, 30)).toBeLessThan(thresholdMarker(config, 58));
  });

  it('converts 100 mph to the canon 44.7 m/s', () => {
    expect(mpsToMph(44.7)).toBeCloseTo(100, 1);
    expect(mphToMps(100)).toBeCloseTo(44.7, 2);
  });

  it('ramps charge over chargeTime and clamps', () => {
    expect(chargeAfter(config, 0)).toBe(0);
    expect(chargeAfter(config, 0.3)).toBeCloseTo(0.5, 6);
    expect(chargeAfter(config, 0.6)).toBe(1);
    expect(chargeAfter(config, 5)).toBe(1);
  });

  it('supports a linear curve for upgrades', () => {
    const flat: ChargeConfig = { ...config, curve: linearCharge };
    expect(speedForCharge(flat, 0.5)).toBeCloseTo(
      (config.minSpeed + config.maxSpeed) / 2,
      6,
    );
  });

  it('has the perfect window off by default and working when widened', () => {
    expect(isPerfect(config, 1)).toBe(false);

    const upgraded: ChargeConfig = { ...config, perfectWindow: 0.1 };
    expect(isPerfect(upgraded, 1)).toBe(true);
    expect(isPerfect(upgraded, 0.95)).toBe(true);
    expect(isPerfect(upgraded, 0.8)).toBe(false);
  });
});
