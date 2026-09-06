# Web pivot — M0 contract and task split (Claude → Codex)

Author: Claude (Fable 5.1). Written 2026-09-06, session 3. Status: **proposal v0.1 + claimed paths.**
Supersedes nothing in the Godot project — `slugterra/` is untouched and stays on `main`.

Source of truth for scope: [`.claude/Web_slugterra.md`](../.claude/Web_slugterra.md) (TDD v2.0).
This file is the web equivalent of `docs/m0_interface_proposal.md`: what I claim, what I propose you own, and the interfaces between us.

---

## 0. What the pivot does and does not change

**Unchanged:** every design decision in Godot TDD §1–§8 — pillars, the 100 mph rule, the 12-slug roster, elements and statuses, the projectile lifecycle, dud-without-penalty, experience only on transform, trust/energy/fatigue. TDD v2.0 §1 says this explicitly. We are re-implementing the same game in a different runtime, **not redesigning it.**

**Unchanged between us:** the ownership split we already ran successfully. I keep player/camera/blaster/HUD/scene-assembly; you keep shared systems, slug/projectile/combat, streaming/save, tooling/CI. Same boundary, new language.

**Changed:** engine layer, world scale (400 × 400 m, 100 m chunks), asset budget (< 15 MB first load, < 400 draw calls), and that we now hand-write what Godot gave us for free (streaming, navmesh, BT runtime, save).

**Explicitly kept alive:** the Godot project. Tony asked that none of it be deleted. `slugterra/` is frozen, not removed; both projects live in this repo side by side.

---

## 1. Repository layout

```
D:\Slugterra\
├── slugterra/          ← Godot project. FROZEN. Do not edit during the web pivot.
├── slugterra-web/      ← new. React + Three.js. All new work lives here.
├── docs/
│   ├── contracts.md            (yours, Godot)
│   ├── m0_interface_proposal.md (mine, Godot)
│   └── web_m0_contract.md      (this file)
├── claude_handoff.md · codex_handoff.md · collaboration_plan.md
```

One repo, two projects. Rationale: the Godot work is a real artifact worth keeping in history, the benchmark baseline may want both, and a second repo doubles the coordination overhead for no gain.

## 2. Path claims

**I have claimed and am implementing now** (session 3):

| Path | Contents |
|---|---|
| `slugterra-web/` scaffold | `package.json`, `vite.config.ts`, `tsconfig*.json`, `index.html`, `src/main.tsx`, `src/App.tsx` |
| `src/game/player/**` | controller, camera rig, `Blaster`, `AmmoWheel` logic |
| `src/ui/**` | React DOM HUD — charge meter, crosshair, belt strip, shot feedback, debug overlay |
| `src/game/world/**` | M0 arena assembly, greybox scene content |
| `src/assets/**` | asset manifest + `useModel` loader indirection |
| `src/data/caverns/**` | cavern/chunk content |
| `tests/player/**`, `tests/ui/**` | Vitest suites for the above |

**Proposed for you** — mirrors your Godot lane exactly:

| Path | Contents |
|---|---|
| `src/engine/**` | `ChunkManager`, `chunkRegistry`, `OriginShifter`, LOD, nav, BT runtime, save/IndexedDB |
| `src/game/slug/**` | `SlugProjectile` (manual integration), `Velocimorph`, `effects/` |
| `src/game/combat/**` | damage resolver, statuses, ghouling, duels |
| `src/game/npc/**` | NPC tiers, perception, schedules |
| `src/state/**` | zustand stores — the `GameState`/`EventBus`/`TimeController` equivalents |
| `src/data/slugs/**`, `src/data/elements/**` | `SlugData` objects, matchup matrix |
| `tools/**`, `.github/**`, Playwright config | asset pipeline, validators, CI |

**CORRECTION (same session).** The scaffold claim above was wrong and I have withdrawn it. Codex had already built `slugterra-web/` — it was untracked, so `git status` showed only `?? slugterra-web/` and I wrote over five of his config files before looking inside. Details, what I restored, and what I could not, are in `claude_handoff.md` CL-013.

**Revised:** the scaffold, `src/main.tsx` and `src/styles.css` are **Codex's**. My lane is `src/game/player/**`, `src/ui/**`, `src/assets/**`, `src/data/caverns/**`, `tests/**`. `package.json` remains shared with me as writer only because I had to reconstruct it from his lockfile; he may take it back at any time.

**Lesson recorded:** an untracked directory is not an empty one. Check the filesystem, not just `git status`, before claiming a path.

**Shared-file rule, unchanged:** one writer per file. `package.json` is the one genuinely shared file — I own it; request dependency additions in your handoff and I will add them, exactly as `project.godot` worked in reverse.

## 3. Stack, pinned

Per TDD v2.0 §2, and the whole list — every dependency is first-load bytes and 2 a.m. debugging.

React 19 · TypeScript strict · Three.js · `@react-three/fiber` v9 · `@react-three/drei` · `@react-three/rapier` · `zustand` · `three-mesh-bvh` · Vite · Vitest · Playwright.

Deliberately **not** installed yet: `ecctrl` (TDD says "start with it, fork when the blaster/mount states outgrow it" — the mount/blaster states are exactly what M0 is about, so I am writing the controller directly against Rapier), `howler` (no audio in M0), `idb` (save is M1, yours).

## 4. Interfaces between us

The Godot contract translated. Names are the TypeScript equivalents of what we already ratified, so the concepts carry over unchanged.

### 4.1 Units and the charge rule — unchanged from Godot

Metres, seconds, m/s. `mph = mps * 2.236936`. `VELOCITY_THRESHOLD = 44.7` (100 mph, canon).
Charge: hold 0 → 1 over 0.6 s through a curve; `speed = lerp(20, 62, curve(charge))`. Eligibility is decided **at launch** from launch speed, inclusive (`>=`) — the CL-004 decision you already accepted; the HUD notch must stay a promise.

I am porting the exact charge curve we shipped in Godot (`f(t) = 0.4t² + 0.6t`, notch at t = 0.676 ≈ 0.41 s of hold), so the web build feels identical to the Godot build and Tony's playtest notes transfer between them.

### 4.2 Launch boundary — the seam you own

```ts
export interface LaunchRequest {
  instance: SlugInstance;
  sourceId: string;              // 'player' | npc id
  muzzle: Vector3;               // world space
  direction: Vector3;            // normalised
  speedMps: number;
}

export interface LaunchResult {
  accepted: boolean;
  reason: 'ok' | 'unavailable' | 'cooldown' | 'ghouled' | 'no_slug' | 'launcher_missing';
  shotId: number;
}

export function launch(request: LaunchRequest): LaunchResult;   // src/game/slug/launcher.ts
```

My `Blaster` builds the request and calls `launch()`. Same shape as Godot's, same field names in camelCase.

**Until `src/game/slug/` exists**, my blaster resolves the launcher through a small injectable seam (`setLauncher()`), defaulting to a dry-fire stub that reports the shot without spawning anything — exactly the pattern that let A1 land before B0 in Godot. Drop your real `launch` in and it takes over with no change to my code.

### 4.3 Slug runtime state — what the HUD reads

```ts
type Availability = 'READY' | 'IN_FLIGHT' | 'DUD_WAIT' | 'RETURNING' | 'COOLDOWN' | 'GHOULED';

interface SlugInstance {
  instanceId: string;
  data: SlugData;                // breed definition, includes velocityThreshold
  experience: number;
  energy: number; trust: number; fatigue: number;
  isGhouled: boolean;
  availability: Availability;
  cooldownRemaining: number;
}
```

`SlugData.velocityThreshold` is per breed. The HUD notch always comes from the equipped slug, never a constant.

### 4.4 Events

zustand store + a tiny typed emitter, replacing `EventBus`. One authoritative producer per event, exactly as before:
`slugLaunched · slugTransformed · slugDud · slugHit · slugReturned · slugAvailabilityChanged · damageDealt · statusApplied · statusCleared · entityDied · originShifted · chunkLoaded · chunkUnloading`

**Critical web-specific rule (TDD §2):** game state must live in zustand **outside React's render cycle**. Nothing that changes at 60 Hz may be React state, or the reconciler runs every frame. The HUD subscribes with selectors and re-renders only when a displayed value actually changes; the charge meter updates through a ref, not `setState`.

### 4.5 Time control

`TimeController`'s keyed `min()` stack ports directly — the ammo wheel pushes 0.25×, hitstop pushes 0.05×, and closing the wheel can never cancel a hitstop. In the browser this multiplies our own `dt` rather than `Engine.time_scale`; **every system must take `dt` from the shared clock**, never from `useFrame`'s raw delta, or slow motion will apply inconsistently.

### 4.6 Asset indirection — new, and it matters for the Sketchfab question

Every model reference goes through a manifest, never a hardcoded path:

```ts
// src/assets/manifest.ts
export const models = {
  'slug.infurnus.dormant': { url: null, placeholder: 'sphere', tint: '#e2542a' },
  // url: null  → greybox primitive
  // url: '/assets/placeholder/...'  → CC0 stand-in
  // url: '/assets/licensed/...'     → licensor glTF, gitignored
};
```

`public/assets/licensed/` is gitignored from the first commit. The greybox build must stay fully playable with that folder absent — same quarantine rule as the Godot plan, and the reason a licence outcome cannot strand the project.

**On the Sketchfab models specifically:** TDD v2.0 §0.2 and the §12 risk table both say not to ship them — a fan uploader's CC-BY covers their own labour, not WildBrain's IP, so two rights layers are unresolved. I have built the manifest so they can be dropped in for local prototyping and removed by editing one file. That is Tony's call, not ours; our job is to make sure the decision stays cheap and reversible either way.

## 5. M0 definition of done (TDD v2.0 §10)

Vite + R3F + Rapier scaffold · controller · follow camera · charge-and-fire blaster with the 100 mph band · Burpy as a sphere that scales on transform · 1 dummy target · 100 m plane · Vitest + Playwright CI · **deployed to a URL**.

Verification I will run before each commit, mirroring the Godot three-check habit:
1. `tsc --noEmit` — strict, zero errors.
2. `vitest run` — charge maths, blaster state, controller, wheel.
3. Playwright headless boot — no console errors, and `renderer.info` asserted against the §7 budget (< 400 draw calls).

## 6. Open questions for you

1. **Do you want the scaffold?** It is yours for the asking; I took it only to unblock.
2. **CI is yours by symmetry** (you did `.github/` in Godot). I will leave `.github/` and `playwright.config.ts` alone unless you say otherwise. The TDD calls CI step 3 of 7 and worth 55 benchmark points — it should land early.
3. **`src/state/` naming**: I have assumed `useGameStore`, `useSlugStore`, `useTimeStore`. Rename freely before I have consumers; after that, say so here first.
4. **Godot project freeze**: I am treating `slugterra/` as read-only from now. If you disagree — e.g. you want to finish B0's dummy prefab — say so, but I would rather we both point at the web build.
