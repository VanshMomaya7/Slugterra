/**
 * Charge-and-release slug slinging. The verb the whole game is built on.
 *
 * Ported from the Godot build's `src/player/blaster.gd`, same contract:
 * whether the slug transforms is decided from the launch speed (inclusive
 * `>=`), so the threshold notch on the HUD is a promise rather than a guess.
 *
 * Deliberately framework-free — no React, no Three.js. It is a plain state
 * machine driven by `tick(dt)`, which makes it trivially unit-testable and
 * keeps it out of React's render cycle, per TDD v2.0 §2.
 *
 * The projectile itself is Codex's (`src/game/slug/`). This module never
 * imports it: the launcher arrives through {@link setLauncher} and defaults to
 * a dry-fire stub that reports the shot without spawning anything. That is the
 * same seam that let the blaster land before the projectile existed in the
 * Godot build.
 */

import {
  DEFAULT_CHARGE,
  chargeAfter,
  isPerfect,
  speedForCharge,
  thresholdMarker,
  type ChargeConfig,
} from './chargeConfig';

export type Vec3 = { x: number; y: number; z: number };

export type Availability =
  | 'READY'
  | 'IN_FLIGHT'
  | 'DUD_WAIT'
  | 'RETURNING'
  | 'COOLDOWN'
  | 'GHOULED';

/** The subset of Codex's `SlugData` the blaster reads. */
export interface SlugDataLike {
  readonly id: string;
  readonly displayName: string;
  /** Per breed. The HUD notch comes from here, never from a constant. */
  readonly velocityThreshold: number;
}

/** The subset of Codex's `SlugInstance` the blaster reads. */
export interface SlugInstanceLike {
  readonly instanceId: string;
  readonly data: SlugDataLike;
  readonly isGhouled: boolean;
  readonly availability: Availability;
}

/** Anything exposing the equipped slug. Codex's `SlugBelt` satisfies this. */
export interface BeltLike {
  getActive(): SlugInstanceLike | null;
}

export interface LaunchRequest {
  instance: SlugInstanceLike | null;
  sourceId: string;
  muzzle: Vec3;
  direction: Vec3;
  speedMps: number;
}

export type LaunchReason =
  | 'ok'
  | 'dry_fire'
  | 'not_charging'
  | 'no_slug'
  | 'unavailable'
  | 'cooldown'
  | 'ghouled'
  | 'launch_failed';

export interface LaunchResult {
  accepted: boolean;
  reason: LaunchReason;
  shotId: number;
}

export type Launcher = (request: LaunchRequest) => LaunchResult;

/** Report emitted on every release. The HUD renders straight from this. */
export interface ShotReport extends LaunchResult {
  charge: number;
  speedMps: number;
  thresholdMps: number;
  willTransform: boolean;
  perfect: boolean;
  dryFire: boolean;
  muzzle: Vec3;
  direction: Vec3;
}

export interface BlasterEvents {
  onChargeStart?: () => void;
  /** Fires every tick while charging. Drive the meter through a ref, not state. */
  onChargeChange?: (charge01: number, projectedSpeedMps: number) => void;
  onChargeCancel?: () => void;
  onFire?: (report: ShotReport) => void;
  onRejected?: (reason: LaunchReason) => void;
}

export interface BlasterOptions {
  config?: ChargeConfig;
  belt?: BeltLike | null;
  /** Resolves the muzzle in world space at the moment of release. */
  getMuzzle?: () => Vec3;
  /** Resolves the aim direction (normalised) at the moment of release. */
  getDirection?: () => Vec3;
  /**
   * M0 only: allow charging with no belt or launcher wired, so the charge
   * timing is playtestable before the projectile exists.
   */
  allowDryFire?: boolean;
  events?: BlasterEvents;
}

const ORIGIN: Vec3 = { x: 0, y: 0, z: 0 };
const FORWARD: Vec3 = { x: 0, y: 0, z: -1 };

let nextShotId = 1;

/** Test hook so shot ids are deterministic across suites. */
export function __resetShotIds(): void {
  nextShotId = 1;
}

/**
 * A dry-fire launcher. Reports the shot honestly and spawns nothing, so the
 * charge loop is playable before the projectile lands. It deliberately does
 * *not* implement a parallel projectile.
 */
export const dryFireLauncher: Launcher = () => ({
  accepted: true,
  reason: 'dry_fire',
  shotId: nextShotId++,
});

export class Blaster {
  readonly config: ChargeConfig;

  private belt: BeltLike | null;
  private launcher: Launcher = dryFireLauncher;
  private readonly getMuzzle: () => Vec3;
  private readonly getDirection: () => Vec3;
  private readonly allowDryFire: boolean;
  private readonly events: BlasterEvents;

  private charging = false;
  private chargeSeconds = 0;
  private charge01 = 0;

  constructor(options: BlasterOptions = {}) {
    this.config = options.config ?? DEFAULT_CHARGE;
    this.belt = options.belt ?? null;
    this.getMuzzle = options.getMuzzle ?? (() => ORIGIN);
    this.getDirection = options.getDirection ?? (() => FORWARD);
    this.allowDryFire = options.allowDryFire ?? true;
    this.events = options.events ?? {};
  }

  /** Swaps in the real projectile launcher once `src/game/slug/` exists. */
  setLauncher(launcher: Launcher): void {
    this.launcher = launcher;
  }

  setBelt(belt: BeltLike | null): void {
    this.belt = belt;
  }

  isCharging(): boolean {
    return this.charging;
  }

  getCharge(): number {
    return this.charge01;
  }

  getProjectedSpeed(): number {
    return speedForCharge(this.config, this.charge01);
  }

  /** The equipped slug's own threshold, or the display fallback. */
  getThreshold(): number {
    const instance = this.belt?.getActive() ?? null;
    const threshold = instance?.data?.velocityThreshold;
    return threshold !== undefined && threshold > 0
      ? threshold
      : this.config.referenceThreshold;
  }

  /** Where the notch belongs on the meter, 0..1. */
  getThresholdMarker(): number {
    return thresholdMarker(this.config, this.getThreshold());
  }

  beginCharge(): void {
    if (this.charging) return;

    const reason = this.rejectionReason();
    if (reason !== 'ok') {
      this.events.onRejected?.(reason);
      return;
    }

    this.charging = true;
    this.chargeSeconds = 0;
    this.charge01 = 0;
    this.events.onChargeStart?.();
    this.events.onChargeChange?.(0, speedForCharge(this.config, 0));
  }

  cancelCharge(): void {
    if (!this.charging) return;
    this.charging = false;
    this.chargeSeconds = 0;
    this.charge01 = 0;
    this.events.onChargeCancel?.();
  }

  /**
   * Advances the charge. `dt` must come from the shared game clock, not from
   * raw wall time, so the ammo wheel's slow motion cannot be used to buy extra
   * charge in real seconds.
   */
  tick(dt: number): void {
    if (!this.charging || dt <= 0) return;
    this.chargeSeconds += dt;
    const previous = this.charge01;
    this.charge01 = chargeAfter(this.config, this.chargeSeconds);
    if (this.charge01 !== previous) {
      this.events.onChargeChange?.(this.charge01, this.getProjectedSpeed());
    }
  }

  /** Fires the charged shot and returns the report. */
  release(): ShotReport {
    if (!this.charging) {
      const report = this.buildReport(0, 'not_charging', false, 0);
      this.events.onRejected?.('not_charging');
      return report;
    }

    const charge = this.charge01;
    const speed = speedForCharge(this.config, charge);

    this.charging = false;
    this.chargeSeconds = 0;
    this.charge01 = 0;

    const reason = this.rejectionReason();
    if (reason !== 'ok') {
      const rejected = this.buildReport(charge, reason, false, speed);
      this.events.onRejected?.(reason);
      this.events.onFire?.(rejected);
      return rejected;
    }

    const instance = this.belt?.getActive() ?? null;
    const result = this.launcher({
      instance,
      sourceId: 'player',
      muzzle: this.getMuzzle(),
      direction: this.getDirection(),
      speedMps: speed,
    });

    const report = this.buildReport(charge, result.reason, result.accepted, speed);
    report.shotId = result.shotId;
    report.dryFire = result.reason === 'dry_fire';

    this.events.onFire?.(report);
    if (!result.accepted) this.events.onRejected?.(result.reason);
    return report;
  }

  private buildReport(
    charge: number,
    reason: LaunchReason,
    accepted: boolean,
    speedMps: number,
  ): ShotReport {
    const thresholdMps = this.getThreshold();
    return {
      accepted,
      reason,
      shotId: 0,
      charge,
      speedMps,
      thresholdMps,
      // Inclusive, and decided from launch speed — the ratified contract.
      willTransform: accepted && speedMps >= thresholdMps,
      perfect: isPerfect(this.config, charge),
      dryFire: false,
      muzzle: this.getMuzzle(),
      direction: this.getDirection(),
    };
  }

  private rejectionReason(): LaunchReason {
    const instance = this.belt?.getActive() ?? null;
    if (instance === null) return this.allowDryFire ? 'ok' : 'no_slug';
    if (instance.isGhouled) return 'ghouled';
    if (instance.availability === 'COOLDOWN') return 'cooldown';
    if (instance.availability !== 'READY') return 'unavailable';
    return 'ok';
  }
}
