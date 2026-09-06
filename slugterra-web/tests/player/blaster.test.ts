import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  Blaster,
  __resetShotIds,
  type Availability,
  type BeltLike,
  type LaunchRequest,
  type LaunchResult,
  type ShotReport,
  type SlugInstanceLike,
} from '../../src/game/player/blaster';
import { DEFAULT_CHARGE, thresholdMarker } from '../../src/game/player/chargeConfig';

function makeInstance(overrides: Partial<SlugInstanceLike> = {}): SlugInstanceLike {
  return {
    instanceId: 'burpy',
    data: { id: 'infurnus', displayName: 'Infurnus', velocityThreshold: 44.7 },
    isGhouled: false,
    availability: 'READY' as Availability,
    ...overrides,
  };
}

function makeBelt(instance: SlugInstanceLike | null): BeltLike {
  return { getActive: () => instance };
}

/** Holds the trigger for `seconds` in fixed steps — never wall time. */
function chargeFor(blaster: Blaster, seconds: number, step = 1 / 60): void {
  blaster.beginCharge();
  let elapsed = 0;
  while (elapsed < seconds - 1e-9) {
    const dt = Math.min(step, seconds - elapsed);
    blaster.tick(dt);
    elapsed += dt;
  }
}

describe('Blaster', () => {
  beforeEach(() => {
    __resetShotIds();
  });

  it('starts idle', () => {
    const blaster = new Blaster();
    expect(blaster.isCharging()).toBe(false);
    expect(blaster.getCharge()).toBe(0);
  });

  it('accumulates charge and clamps at full', () => {
    const blaster = new Blaster();
    chargeFor(blaster, 0.3);
    expect(blaster.isCharging()).toBe(true);
    expect(blaster.getCharge()).toBeCloseTo(0.5, 2);

    blaster.tick(2);
    expect(blaster.getCharge()).toBe(1);
  });

  it('cancels back to zero', () => {
    const blaster = new Blaster();
    chargeFor(blaster, 0.3);
    blaster.cancelCharge();
    expect(blaster.isCharging()).toBe(false);
    expect(blaster.getCharge()).toBe(0);
  });

  it('rejects a release that never charged', () => {
    const blaster = new Blaster();
    const report = blaster.release();
    expect(report.accepted).toBe(false);
    expect(report.reason).toBe('not_charging');
  });

  // The premise of the whole mechanic: a panic shot fizzles.
  it('duds on a tap release', () => {
    const blaster = new Blaster();
    chargeFor(blaster, 0.02);
    const report = blaster.release();
    expect(report.speedMps).toBeLessThan(44.7);
    expect(report.willTransform).toBe(false);
  });

  it('transforms on a full charge', () => {
    const blaster = new Blaster();
    chargeFor(blaster, 0.7);
    const report = blaster.release();
    expect(report.speedMps).toBeCloseTo(DEFAULT_CHARGE.maxSpeed, 4);
    expect(report.willTransform).toBe(true);
  });

  // The contract is inclusive (>=), and the notch is drawn at this same point.
  it('transforms when released exactly at the notch', () => {
    const blaster = new Blaster();
    const marker = thresholdMarker(DEFAULT_CHARGE);
    chargeFor(blaster, marker * DEFAULT_CHARGE.chargeTime, 1 / 1000);
    const report = blaster.release();
    expect(report.speedMps).toBeGreaterThanOrEqual(report.thresholdMps - 0.01);
    expect(report.willTransform).toBe(true);
  });

  it('stops charging after a release', () => {
    const blaster = new Blaster();
    chargeFor(blaster, 0.3);
    blaster.release();
    expect(blaster.isCharging()).toBe(false);
  });

  it('emits charge and fire events', () => {
    const onChargeStart = vi.fn();
    const onChargeChange = vi.fn();
    const onFire = vi.fn();
    const blaster = new Blaster({ events: { onChargeStart, onChargeChange, onFire } });

    chargeFor(blaster, 0.7);
    blaster.release();

    expect(onChargeStart).toHaveBeenCalledOnce();
    expect(onChargeChange).toHaveBeenCalled();
    expect(onFire).toHaveBeenCalledOnce();
    const report = onFire.mock.calls[0]![0] as ShotReport;
    expect(report.willTransform).toBe(true);
  });

  it('does not advance charge on a zero or negative dt', () => {
    const blaster = new Blaster();
    blaster.beginCharge();
    blaster.tick(0);
    blaster.tick(-1);
    expect(blaster.getCharge()).toBe(0);
  });

  describe('belt interaction', () => {
    it('reads the threshold from the equipped slug, not a constant', () => {
      const belt = makeBelt(
        makeInstance({
          data: { id: 'slow', displayName: 'Slow', velocityThreshold: 30 },
        }),
      );
      const blaster = new Blaster({ belt });
      expect(blaster.getThreshold()).toBeCloseTo(30, 6);
      // A lower threshold must move the notch left, not just the number.
      expect(blaster.getThresholdMarker()).toBeLessThan(
        thresholdMarker(DEFAULT_CHARGE),
      );
    });

    it('refuses to charge a slug that is not ready', () => {
      const onRejected = vi.fn();
      const blaster = new Blaster({
        belt: makeBelt(makeInstance({ availability: 'IN_FLIGHT' })),
        events: { onRejected },
      });
      blaster.beginCharge();
      expect(blaster.isCharging()).toBe(false);
      expect(onRejected).toHaveBeenCalledWith('unavailable');
    });

    it('reports cooldown distinctly from unavailable', () => {
      const onRejected = vi.fn();
      const blaster = new Blaster({
        belt: makeBelt(makeInstance({ availability: 'COOLDOWN' })),
        events: { onRejected },
      });
      blaster.beginCharge();
      expect(onRejected).toHaveBeenCalledWith('cooldown');
    });

    it('refuses to charge a ghouled slug', () => {
      const blaster = new Blaster({
        belt: makeBelt(makeInstance({ isGhouled: true })),
      });
      blaster.beginCharge();
      expect(blaster.isCharging()).toBe(false);
    });

    it('refuses an empty belt when dry fire is disabled', () => {
      const blaster = new Blaster({ belt: makeBelt(null), allowDryFire: false });
      blaster.beginCharge();
      expect(blaster.isCharging()).toBe(false);
    });

    it('allows an empty belt as a dry fire in M0', () => {
      const blaster = new Blaster({ belt: makeBelt(null), allowDryFire: true });
      chargeFor(blaster, 0.7);
      const report = blaster.release();
      expect(report.accepted).toBe(true);
      expect(report.dryFire).toBe(true);
    });
  });

  describe('launcher seam', () => {
    it('hands a fully formed request to the launcher', () => {
      const requests: LaunchRequest[] = [];
      const launcher = (request: LaunchRequest): LaunchResult => {
        requests.push(request);
        return { accepted: true, reason: 'ok', shotId: 42 };
      };

      const instance = makeInstance();
      const blaster = new Blaster({
        belt: makeBelt(instance),
        getMuzzle: () => ({ x: 1, y: 2, z: 3 }),
        getDirection: () => ({ x: 0, y: 0, z: -1 }),
      });
      blaster.setLauncher(launcher);

      chargeFor(blaster, 0.7);
      const report = blaster.release();

      expect(requests).toHaveLength(1);
      const request = requests[0]!;
      expect(request.instance).toBe(instance);
      expect(request.sourceId).toBe('player');
      expect(request.muzzle).toEqual({ x: 1, y: 2, z: 3 });
      expect(request.speedMps).toBeCloseTo(DEFAULT_CHARGE.maxSpeed, 4);
      expect(report.shotId).toBe(42);
      expect(report.dryFire).toBe(false);
    });

    // A refused launch must not be reported to the player as a transform.
    it('does not claim a transform when the launcher refuses', () => {
      const blaster = new Blaster({ belt: makeBelt(makeInstance()) });
      blaster.setLauncher(() => ({
        accepted: false,
        reason: 'launch_failed',
        shotId: 0,
      }));

      chargeFor(blaster, 0.7);
      const report = blaster.release();
      expect(report.accepted).toBe(false);
      expect(report.willTransform).toBe(false);
    });
  });
});
