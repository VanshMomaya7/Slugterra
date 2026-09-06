/**
 * Asset indirection: what actually renders for each thing in the game.
 *
 * Tony's decision is to use the Sketchfab models, so every entry below now
 * points at a real downloaded mesh. Each one still carries a `fallback`
 * primitive, and that is not hedging — it is what keeps the build runnable:
 *
 * - The `.glb` files are **not committed** (see `.gitignore`). They are fetched
 *   with `npm run assets` from a Sketchfab API token, so a fresh clone has no
 *   meshes until someone runs it.
 * - A model that 404s, fails to parse, or has not been fetched yet falls back
 *   to its primitive instead of crashing the scene.
 *
 * So `npm run dev` works on a clean checkout, and the same build shows real
 * models once the assets are present. `Model.tsx` implements the swap.
 */

import {
  SKETCHFAB_MODELS,
  TRI_BUDGET,
  creditLine,
  localPath,
  type SketchfabKey,
  type SketchfabModel,
} from './sketchfabCatalog';

export type PrimitiveShape = 'sphere' | 'capsule' | 'box';

export interface PrimitiveRef {
  readonly shape: PrimitiveShape;
  readonly tint: string;
  /** Radius for a sphere/capsule, half-extent for a box. */
  readonly size: number;
}

/** Correction applied to a fan model, which arrives at arbitrary scale/axis. */
export interface ModelTransform {
  /** Uniform scale. Tuned per model once the real mesh is on disk. */
  readonly scale: number;
  /** Euler XYZ in radians, for Z-up exports and mis-facing meshes. */
  readonly rotation?: readonly [number, number, number];
  /** Offset in metres, to sit the mesh on its origin. */
  readonly position?: readonly [number, number, number];
}

export interface ModelEntry {
  /** Sketchfab source. Drives loading, attribution and the budget check. */
  readonly source: SketchfabKey;
  /** Where the fetched `.glb` lives under `public/`. */
  readonly url: string;
  readonly transform: ModelTransform;
  /** Rendered until the mesh loads, and permanently if it never does. */
  readonly fallback: PrimitiveRef;
  /** Triangle ceiling this model is simplified to by the optimize step. */
  readonly triBudget: number;
  readonly note?: string;
}

/**
 * Transforms are first-pass estimates. Sketchfab exports vary wildly in scale
 * and up-axis, so these are expected to need one tuning pass against the real
 * meshes; `Model.tsx` logs the loaded bounding box in dev to make that quick.
 */
export const models = {
  'character.eli': {
    source: 'eliShane',
    url: localPath('eliShane'),
    transform: { scale: 1, position: [0, 0, 0] },
    fallback: { shape: 'capsule', tint: '#d88a42', size: 0.38 },
    triBudget: TRI_BUDGET.humanoid,
    note: 'Player character. Replaces the greybox capsule.',
  },
  'slug.infurnus.dormant': {
    source: 'burpy',
    url: localPath('burpy'),
    transform: { scale: 0.35 },
    fallback: { shape: 'sphere', tint: '#e2542a', size: 0.22 },
    triBudget: TRI_BUDGET.slugDormant,
    note: 'Burpy in the belt and in dormant flight.',
  },
  'slug.infurnus.velocimorph': {
    source: 'burpy',
    url: localPath('burpy'),
    // The transformed slug reads as "bigger and angrier" at the same mesh.
    transform: { scale: 0.62 },
    fallback: { shape: 'sphere', tint: '#ff8c1a', size: 0.35 },
    triBudget: TRI_BUDGET.velocimorph,
    note: 'Scaled-up Burpy until a dedicated Velocimorph mesh exists.',
  },
  'slug.frostcrawler.dormant': {
    source: 'frostslug',
    url: localPath('frostslug'),
    transform: { scale: 0.35 },
    fallback: { shape: 'sphere', tint: '#7ad7ee', size: 0.22 },
    triBudget: TRI_BUDGET.slugDormant,
  },
  'slug.frostcrawler.velocimorph': {
    source: 'frostcrawlerVelocimorph',
    url: localPath('frostcrawlerVelocimorph'),
    transform: { scale: 0.6 },
    fallback: { shape: 'sphere', tint: '#a8e9ff', size: 0.35 },
    triBudget: TRI_BUDGET.velocimorph,
  },
  'slug.hoprock.dormant': {
    source: 'hopRock',
    url: localPath('hopRock'),
    transform: { scale: 0.35 },
    fallback: { shape: 'sphere', tint: '#9a7b52', size: 0.22 },
    triBudget: TRI_BUDGET.slugDormant,
    note: '500k faces as uploaded — the heaviest decimation in the set.',
  },
  'blaster.default': {
    source: 'blasterRenegade',
    url: localPath('blasterRenegade'),
    transform: { scale: 0.25, position: [0, 0, 0] },
    fallback: { shape: 'box', tint: '#f2b344', size: 0.12 },
    triBudget: TRI_BUDGET.prop,
    note: "Eli's blaster, held at the muzzle marker.",
  },
  'target.dummy': {
    source: 'slugShell',
    url: localPath('slugShell'),
    transform: { scale: 1.2 },
    fallback: { shape: 'capsule', tint: '#d9504f', size: 0.6 },
    triBudget: TRI_BUDGET.prop,
    note: 'Only 3.1k faces as uploaded — the one model close to budget already.',
  },
} as const satisfies Record<string, ModelEntry>;

export type ModelKey = keyof typeof models;

export function getModel(key: ModelKey): ModelEntry {
  return models[key];
}

export function sourceOf(key: ModelKey): SketchfabModel {
  return SKETCHFAB_MODELS[models[key].source];
}

/** Every distinct Sketchfab model the build needs fetched. */
export function requiredSources(): SketchfabKey[] {
  const seen = new Set<SketchfabKey>();
  for (const entry of Object.values(models) as ModelEntry[]) seen.add(entry.source);
  return [...seen];
}

/** Distinct `.glb` URLs, for preloading and first-load budget accounting. */
export function requiredUrls(): string[] {
  const seen = new Set<string>();
  for (const entry of Object.values(models) as ModelEntry[]) seen.add(entry.url);
  return [...seen];
}

/**
 * Attribution lines for every model in the build. CC-BY requires these to be
 * shown, so `src/ui/Attribution.tsx` renders the list and a test asserts it is
 * never empty while models are in use.
 */
export function credits(): { name: string; author: string; authorUrl: string; line: string }[] {
  return requiredSources().map((key) => {
    const model = SKETCHFAB_MODELS[key];
    return {
      name: model.name,
      author: model.author,
      authorUrl: model.authorUrl,
      line: creditLine(model),
    };
  });
}

/** Total triangles once every model is simplified to its budget. */
export function budgetedTriangleTotal(): number {
  const perSource = new Map<SketchfabKey, number>();
  for (const entry of Object.values(models) as ModelEntry[]) {
    perSource.set(entry.source, Math.max(perSource.get(entry.source) ?? 0, entry.triBudget));
  }
  return [...perSource.values()].reduce((sum, tris) => sum + tris, 0);
}

/** Raw triangle total as uploaded — what we would ship without decimation. */
export function rawTriangleTotal(): number {
  return requiredSources().reduce((sum, key) => sum + SKETCHFAB_MODELS[key].faces, 0);
}
