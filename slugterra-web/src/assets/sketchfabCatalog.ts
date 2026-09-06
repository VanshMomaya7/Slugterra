/**
 * The Slugterra models on Sketchfab, as data.
 *
 * Every field here came from Sketchfab's public API
 * (`GET /v3/models?tags=slugterra&downloadable=true`) on 2026-09-06 — names,
 * uids, authors and face counts are real, not guessed.
 *
 * All nine are **CC Attribution**. That licence has one hard requirement:
 * credit the author. `src/ui/Attribution.tsx` renders these entries, and a test
 * asserts every shipped model carries an author and a profile URL, so a model
 * cannot enter the build uncredited.
 *
 * Separately from the licence: these are fan models of WildBrain's IP. A CC-BY
 * grant covers the uploader's own labour, not the underlying character rights
 * (TDD v2.0 §0.2). Tony has decided to use them; this file keeps that decision
 * auditable in one place and reversible by editing `manifest.ts`.
 */

export interface SketchfabModel {
  /** Sketchfab model uid — the key for embeds, downloads and the viewer URL. */
  readonly uid: string;
  readonly name: string;
  readonly author: string;
  readonly authorUrl: string;
  readonly license: 'CC Attribution';
  /** Triangle count as reported by Sketchfab, before any decimation. */
  readonly faces: number;
  readonly vertices: number;
}

export const SKETCHFAB_MODELS = {
  burpy: {
    uid: '8c27c713fe51439dbe8c52cce241b245',
    name: 'Burpy',
    author: 'Zhi Ying',
    authorUrl: 'https://sketchfab.com/zhiying-loo',
    license: 'CC Attribution',
    faces: 97338,
    vertices: 48671,
  },
  eliShane: {
    uid: 'f273b2800f644db4832093eb6336429f',
    name: 'eli_shane',
    author: 'nayzen',
    authorUrl: 'https://sketchfab.com/tahasouhail2324',
    license: 'CC Attribution',
    faces: 134626,
    vertices: 67312,
  },
  frostcrawlerVelocimorph: {
    uid: '14835264d2b443bab0533e58d4515e5d',
    name: 'FROSTCRAWLER_ Velocimorph',
    author: 'nayzen',
    authorUrl: 'https://sketchfab.com/tahasouhail2324',
    license: 'CC Attribution',
    faces: 224229,
    vertices: 112208,
  },
  frostslug: {
    uid: '63cddf71f8274228828bff526a9e06b3',
    name: 'frostslug',
    author: 'mullm',
    authorUrl: 'https://sketchfab.com/simonmull7',
    license: 'CC Attribution',
    faces: 32256,
    vertices: 16575,
  },
  hopRock: {
    uid: '50ad1ebbd50948eab9d0f22dfff5312e',
    name: 'slug hop rock',
    author: 'nayzen',
    authorUrl: 'https://sketchfab.com/tahasouhail2324',
    license: 'CC Attribution',
    faces: 499992,
    vertices: 249984,
  },
  slugShell: {
    uid: '4c73eda559c243a894cf419466eb2e3a',
    name: 'Slug Shell',
    author: 'Starkster',
    authorUrl: 'https://sketchfab.com/parmaryash2599',
    license: 'CC Attribution',
    faces: 3104,
    vertices: 1552,
  },
  blasterRenegade: {
    uid: '1573da9e38a14029a41aa838e6155924',
    name: 'RENEGADE ULTRA QLC Blaster Slugterra',
    author: 'Starkster',
    authorUrl: 'https://sketchfab.com/parmaryash2599',
    license: 'CC Attribution',
    faces: 88840,
    vertices: 44947,
  },
  blasterGun: {
    uid: 'bcd7bdd782d84b9cbd7f93d8b6b23cc0',
    name: 'Slugterra Blaster Gun',
    author: 'Starkster',
    authorUrl: 'https://sketchfab.com/parmaryash2599',
    license: 'CC Attribution',
    faces: 93540,
    vertices: 46755,
  },
  blasterIrfan: {
    uid: 'ae0747f0e7054c29ac1e7dbb08a9be16',
    name: 'BLASTER',
    author: 'IRFAN',
    authorUrl: 'https://sketchfab.com/unknowni',
    license: 'CC Attribution',
    faces: 93504,
    vertices: 46755,
  },
} as const satisfies Record<string, SketchfabModel>;

export type SketchfabKey = keyof typeof SKETCHFAB_MODELS;

/**
 * Triangle budgets from TDD v2.0 §8.2. Every one of these models exceeds its
 * budget as uploaded — `slug hop rock` alone is 500k faces against a 600k
 * *whole scene* ceiling — so `tools/optimizeModels.mjs` simplifies each one to
 * its target before it is allowed into the build.
 */
export const TRI_BUDGET = {
  slugDormant: 1500,
  velocimorph: 6000,
  humanoid: 8000,
  prop: 500,
} as const;

/** Where the fetch tool writes a model, and where the manifest looks for it. */
export function localPath(key: SketchfabKey): string {
  return `/assets/sketchfab/${key}.glb`;
}

export function viewerUrl(model: SketchfabModel): string {
  return `https://sketchfab.com/3d-models/${model.uid}`;
}

export function embedUrl(
  model: SketchfabModel,
  options: { autostart?: boolean; uiTheme?: 'dark' | 'default' } = {},
): string {
  const params = new URLSearchParams({
    autostart: options.autostart === false ? '0' : '1',
    ui_theme: options.uiTheme ?? 'dark',
  });
  return `https://sketchfab.com/models/${model.uid}/embed?${params.toString()}`;
}

/** "Burpy by Zhi Ying, CC Attribution" — the string CC-BY actually requires. */
export function creditLine(model: SketchfabModel): string {
  return `${model.name} by ${model.author} (${model.license})`;
}
