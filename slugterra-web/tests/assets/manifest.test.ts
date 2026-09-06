import { describe, expect, it } from 'vitest';
import {
  embedUrl,
  fetchedModels,
  getModel,
  isGreyboxComplete,
  models,
  references,
} from '../../src/assets/manifest';

describe('asset manifest', () => {
  it('resolves every declared model', () => {
    for (const key of Object.keys(models) as (keyof typeof models)[]) {
      expect(getModel(key)).toBeDefined();
      expect(getModel(key).ref.kind).toBeTruthy();
    }
  });

  /**
   * The quarantine rule: the greybox build must run with no art present. If
   * this fails, someone pointed an entry at a licensed or downloaded asset and
   * the build can no longer start from a clean checkout.
   */
  it('is fully playable with no downloaded art', () => {
    expect(isGreyboxComplete()).toBe(true);
    expect(fetchedModels()).toHaveLength(0);
  });

  it('never references the licensed folder from a shipped entry', () => {
    for (const entry of Object.values(models)) {
      if (entry.ref.kind === 'gltf') {
        expect(entry.ref.url).not.toContain('licensed/');
      }
    }
  });

  it('builds a Sketchfab embed URL', () => {
    const url = embedUrl(references.infurnus);
    expect(url).toContain(`/models/${references.infurnus.embedId}/embed`);
    expect(url).toContain('ui_theme=dark');
    expect(url).toContain('autostart=1');
  });

  it('can disable autostart', () => {
    expect(embedUrl(references.infurnus, { autostart: false })).toContain('autostart=0');
  });

  /** CC-BY requires attribution, and it is correct regardless of licence. */
  it('carries credit on every embed reference', () => {
    for (const ref of Object.values(references)) {
      expect(ref.credit.length).toBeGreaterThan(0);
      expect(ref.author.length).toBeGreaterThan(0);
    }
  });
});
