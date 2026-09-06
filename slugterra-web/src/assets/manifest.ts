/**
 * Asset indirection.
 *
 * Every model reference in the game goes through this table — never a hardcoded
 * path. That is what lets the greybox build run with no art present, and lets
 * approved art land as a config change rather than a refactor (TDD v2.0 §8.1,
 * carried over from the Godot plan's `assets/licensed/` quarantine).
 *
 * There are three ways to reference a model, and the distinction is a rights
 * distinction as much as a technical one:
 *
 * - `primitive` — a sphere/capsule/box drawn from code. Ships with the build,
 *   needs no licence, and is genuinely enough to test the 100 mph mechanic.
 * - `gltf` — a real mesh loaded from `/assets/...`. Anything under
 *   `placeholder/` is CC0 and safe to ship. Anything under `licensed/` is
 *   gitignored and absent until WildBrain approves it; the build must stay
 *   playable without it.
 * - `embed` — a Sketchfab iframe. The model is streamed from Sketchfab under
 *   their embed terms and never enters our bundle, so it costs nothing against
 *   the 15 MB budget and carries no redistribution question. Useful as a visual
 *   reference next to the greybox, not as an in-game asset.
 *
 * On the Sketchfab tag Tony pointed at: several models there are downloadable
 * under CC-BY, but TDD v2.0 §0.2 is right that a fan uploader's CC-BY covers
 * their own labour and cannot convey Slugterra rights they never held. Embeds
 * sidestep that — they are the uploader's own hosted view, displayed as
 * Sketchfab intends. Downloading and shipping the meshes is the part that would
 * need both WildBrain's licence and the uploader's, so those entries stay
 * `primitive` until Tony decides otherwise. Flipping one is a one-line edit.
 */

export type ModelRef =
  | { kind: 'primitive'; shape: 'sphere' | 'capsule' | 'box'; tint: string; scale?: number }
  | { kind: 'gltf'; url: string; scale?: number; credit?: string }
  | { kind: 'embed'; embedId: string; label: string; credit: string; author: string };

export interface ModelEntry {
  /** What actually renders today. */
  readonly ref: ModelRef;
  /** Optional reference viewer shown in the model drawer, never in-world. */
  readonly reference?: Extract<ModelRef, { kind: 'embed' }>;
  readonly note?: string;
}

/**
 * Sketchfab embeds used as visual reference only. Each is credited to its
 * uploader, which CC-BY requires and which is simply correct regardless.
 */
export const references = {
  infurnus: {
    kind: 'embed',
    embedId: 'ded8e71aaaf94bc4a5be48a81911ac3c',
    label: 'Infurnus reference',
    credit: 'Sketchfab (CC-BY, fan model)',
    author: 'unverified — confirm attribution before any public use',
  },
  eliShane: {
    kind: 'embed',
    embedId: 'f273b2800f644db4832093eb6336429f',
    label: 'Eli Shane reference',
    credit: 'Sketchfab (CC-BY, fan model)',
    author: 'unverified — confirm attribution before any public use',
  },
} as const satisfies Record<string, Extract<ModelRef, { kind: 'embed' }>>;

export const models = {
  'slug.infurnus.dormant': {
    ref: { kind: 'primitive', shape: 'sphere', tint: '#e2542a', scale: 0.22 },
    reference: references.infurnus,
    note: 'Burpy. Scales up on transform — the greybox Velocimorph.',
  },
  'slug.infurnus.velocimorph': {
    ref: { kind: 'primitive', shape: 'sphere', tint: '#ff8c1a', scale: 0.35 },
    reference: references.infurnus,
  },
  'character.eli': {
    ref: { kind: 'primitive', shape: 'capsule', tint: '#d88a42' },
    reference: references.eliShane,
    note: 'Player capsule. Licensor asset drops in here when approved.',
  },
  'target.dummy': {
    ref: { kind: 'primitive', shape: 'capsule', tint: '#d9504f', scale: 1 },
  },
} as const satisfies Record<string, ModelEntry>;

export type ModelKey = keyof typeof models;

export function getModel(key: ModelKey): ModelEntry {
  return models[key];
}

/** Builds the Sketchfab embed URL for a reference entry. */
export function embedUrl(
  ref: Extract<ModelRef, { kind: 'embed' }>,
  options: { autostart?: boolean; uiTheme?: 'dark' | 'default' } = {},
): string {
  const params = new URLSearchParams({
    autostart: options.autostart === false ? '0' : '1',
    ui_theme: options.uiTheme ?? 'dark',
  });
  return `https://sketchfab.com/models/${ref.embedId}/embed?${params.toString()}`;
}

/**
 * True when every entry renders without a network fetch — i.e. the build is
 * fully playable with `public/assets/licensed/` absent. CI asserts this so a
 * licensed-only reference can never sneak into the greybox build.
 */
export function isGreyboxComplete(): boolean {
  const entries = Object.values(models) as ModelEntry[];
  return entries.every((entry) => entry.ref.kind === 'primitive');
}

type GltfRef = Extract<ModelRef, { kind: 'gltf' }>;

/**
 * Every model that would be fetched at runtime, for budget accounting.
 *
 * The table is `as const`, so TypeScript narrows it to exactly today's entries
 * and would reject a `'gltf'` comparison as impossible. Widening to
 * `ModelEntry` keeps this correct as soon as a real mesh is added.
 */
export function fetchedModels(): { key: string; url: string }[] {
  const entries = Object.entries(models) as [string, ModelEntry][];
  return entries
    .filter(([, entry]) => entry.ref.kind === 'gltf')
    .map(([key, entry]) => ({ key, url: (entry.ref as GltfRef).url }));
}
