import { describe, expect, it } from 'vitest';
import {
  budgetedTriangleTotal,
  credits,
  getModel,
  models,
  rawTriangleTotal,
  requiredSources,
  requiredUrls,
  sourceOf,
  type ModelEntry,
  type ModelKey,
} from '../../src/assets/manifest';
import {
  SKETCHFAB_MODELS,
  creditLine,
  embedUrl,
  viewerUrl,
} from '../../src/assets/sketchfabCatalog';

const keys = Object.keys(models) as ModelKey[];
const entries = Object.values(models) as ModelEntry[];

describe('asset manifest', () => {
  it('resolves every declared model', () => {
    for (const key of keys) {
      expect(getModel(key)).toBeDefined();
      expect(sourceOf(key)).toBeDefined();
    }
  });

  it('points every source at a real catalog entry', () => {
    for (const entry of entries) {
      expect(SKETCHFAB_MODELS[entry.source]).toBeDefined();
    }
  });

  /**
   * The `.glb` files are gitignored and fetched with `npm run assets`, so a
   * clean checkout has none of them. Without a fallback on every entry the
   * scene would render nothing at all.
   */
  it('gives every model a primitive fallback so a clean checkout still runs', () => {
    for (const entry of entries) {
      expect(entry.fallback).toBeDefined();
      expect(entry.fallback.size).toBeGreaterThan(0);
      expect(entry.fallback.tint).toMatch(/^#[0-9a-f]{6}$/i);
    }
  });

  it('loads every mesh from the fetched-assets folder', () => {
    for (const url of requiredUrls()) {
      expect(url.startsWith('/assets/sketchfab/')).toBe(true);
      expect(url.endsWith('.glb')).toBe(true);
    }
  });

  it('deduplicates shared sources', () => {
    // Burpy is both the dormant slug and the Velocimorph, so it must be
    // fetched and loaded once, not twice.
    expect(requiredSources().length).toBeLessThan(keys.length);
    expect(new Set(requiredSources()).size).toBe(requiredSources().length);
  });

  it('applies a positive scale correction to every model', () => {
    for (const entry of entries) {
      expect(entry.transform.scale).toBeGreaterThan(0);
    }
  });
});

describe('triangle budget', () => {
  /** TDD v2.0 §7: fewer than 600k visible triangles. */
  it('fits the whole model set inside the scene budget once decimated', () => {
    expect(budgetedTriangleTotal()).toBeLessThan(600_000);
  });

  /**
   * Documents why the optimize step is mandatory rather than nice to have: as
   * uploaded, this set is over a million triangles.
   */
  it('is far over budget before decimation', () => {
    expect(rawTriangleTotal()).toBeGreaterThan(600_000);
    expect(rawTriangleTotal()).toBeGreaterThan(budgetedTriangleTotal() * 10);
  });

  it('gives every model a positive triangle budget', () => {
    for (const entry of entries) {
      expect(entry.triBudget).toBeGreaterThan(0);
    }
  });
});

describe('attribution', () => {
  /** CC-BY's one hard requirement. A model must not ship uncredited. */
  it('credits every model in the build', () => {
    const lines = credits();
    expect(lines.length).toBe(requiredSources().length);
    for (const line of lines) {
      expect(line.author.length).toBeGreaterThan(0);
      expect(line.authorUrl).toMatch(/^https:\/\/sketchfab\.com\//);
      expect(line.line).toContain(line.author);
    }
  });

  it('marks every catalog model as CC Attribution', () => {
    for (const model of Object.values(SKETCHFAB_MODELS)) {
      expect(model.license).toBe('CC Attribution');
      expect(model.uid).toMatch(/^[0-9a-f]{32}$/);
    }
  });

  it('formats a credit line naming both work and author', () => {
    const burpy = SKETCHFAB_MODELS.burpy;
    expect(creditLine(burpy)).toBe('Burpy by Zhi Ying (CC Attribution)');
  });

  it('builds viewer and embed URLs from the uid', () => {
    const burpy = SKETCHFAB_MODELS.burpy;
    expect(viewerUrl(burpy)).toContain(burpy.uid);
    expect(embedUrl(burpy)).toContain(`/models/${burpy.uid}/embed`);
    expect(embedUrl(burpy, { autostart: false })).toContain('autostart=0');
  });
});
