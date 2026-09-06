# SLUGTERRA: THE 99 CAVERNS — Web Technical Design Document

**A 3D open-world slug-slinging game in React + Three.js**
Version 2.0 · September 2026 · Author: Tony (Vansh Momaya)
Supersedes the Godot TDD (v1.0). Secondary purpose: benchmark harness for Claude Fable 5.1 vs GPT-6.

---

## 0. About this pivot

### 0.1 The stated reason doesn't hold — but the pivot might still be right

The premise for pivoting was that the available 3D models work on a website but not in Godot. **That isn't the case.** Sketchfab exports glTF/GLB, and glTF is Godot's *preferred* import format — natively supported, no plugin, no conversion. Anything that loads in Three.js loads in Godot. The same is true of FBX, OBJ, DAE and Blender files. There is no asset-format reason to leave Godot.

So decide the pivot on its actual merits, which are real:

**Genuine advantages of web:**
- **Distribution is a URL.** No download, no install, no platform build. For a portfolio piece someone opens from your résumé in one click, this is a large win.
- **Tightest possible iteration loop.** Save file → HMR → see it. Faster than any engine.
- **Best-case LLM benchmark substrate.** Pure TypeScript, zero editor, everything an agent writes is verifiable by running the dev server and a headless browser. No GUI work an agent can't reach — this removes the one real weakness of the Godot plan for §12.
- **Your existing stack.** React and TypeScript are things you already know; GDScript was a new language.

**Genuine costs:**
- **Roughly a quarter of the perf headroom.** Browser tab memory ceiling (~2–4 GB), no real threading beyond Web Workers, WASM physics, GC pauses. World scale must come down accordingly.
- **You build what the engine gave you.** Streaming, LOD, navmesh, behavior trees, save system, terrain tooling — all hand-written. Terrain3D and LimboAI were saving you ~2 months.
- **No editor.** Every prop placement is a coordinate in a data file. This is fine for a procedural world, painful for handcrafted set pieces.
- **First-load budget.** Nobody waits 90 seconds for a web game. Hard ceiling around 15 MB before first interaction.

Net: web is the better choice for a benchmark and a portfolio piece, worse for shipping a large open world. Given your actual goals — testing models, and something to show — **web is defensible.** This document assumes you've made that call, and scopes the world down to match what a browser can carry.

### 0.2 On the Sketchfab models

Two separate rights problems, and neither one solves the other.

**Sketchfab grants nothing about the IP depicted.** Their license agreement states it directly: the licensor "does not grant any right or make any warranty with regard to the use of names, people, trademarks, trade dress, logos or registered, unregistered or copyrighted audio, designs or works of art" depicted in a model, and the licensee is "solely responsible for determining whether release(s), consent(s) or authorization(s)" are needed. A CC-BY tag from a fan uploader covers that uploader's own labour. It cannot convey Slugterra rights the uploader never had.

**A WildBrain license doesn't cover them either.** Your license — when it closes — is with WildBrain for Slugterra. It says nothing about a third-party model made by a fan artist you have no agreement with. You'd need rights from both, and the fan artist can't give you the half they don't own.

Also practically: most Sketchfab models tagged to a franchise are view-only, not downloadable, and the downloadable ones are show-topology or game-rip topology — wrong tri counts, wrong rigs, and far too heavy for a 15 MB web budget. You would be rebuilding them anyway.

**What actually works, and costs you nothing right now:** greybox with primitives (§8), keep every asset reference behind a manifest indirection, and drop in licensor-approved glTF when it arrives. M0 and M1 need zero character art. If you want to prototype against *something* creature-shaped in the meantime, Quaternius and Kenney are CC0 and safe to ship if a placeholder survives.

---

## 1. Design carried over unchanged

Everything in §1–§8 of the Godot TDD is engine-agnostic and stands as written:

- **Design pillars** — the blaster is the verb; slugs are characters not ammo; 100 mph or nothing; verticality; readable performance
- **Canon mechanics** — velocity transformation at 100 mph, Velocimorphs, slug energy and permanent experience, ghouls and Boon Doc purification, the Five Elementals, Slug Fu, Mecha Beasts, blastersmithing
- **Element system** — 10 elements (Fire, Water, Earth, Air, Energy, Ice, Metal, Psychic, Shadow, Toxic), 10×10 matchup matrix, 9 status effects, the 7-rule cross-interaction table
- **Slug roster** — the same 12 (Infurnus, Tazerling, Hop Rock, Frostcrawler, Arachnet, Tormato, Rammstone, Boon Doc, Armashelt, Aquabeek, Speedstinger, Negashade) plus their 12 ghoul counterparts, Goon Doc still the centrepiece
- **Characters and factions** — Shane Gang, allies, Blakk Industries, Dark Bane, Shadow Clan, Molenoid Kingdom
- **Slug systems** — projectile lifecycle, dud-without-penalty, experience only on successful transform, trust/fatigue/energy, capture

Refer to the Godot TDD for those tables. This document covers only what changes: **the engine layer, the world scale, and the asset budget.**

---

## 2. Stack

| Layer | Choice | Why |
|---|---|---|
| Runtime | **React 19 + TypeScript (strict)** | Type safety matters more here than in Godot — no engine to catch you |
| Renderer | **Three.js** via **@react-three/fiber v9** | Declarative scene graph, and R3F's reconciler cost is negligible next to draw calls |
| Helpers | **@react-three/drei** | `<Instances>`, `<Detailed>` (LOD), `<Environment>`, `<useGLTF>`, `<Html>`, `<KeyboardControls>` |
| Physics | **@react-three/rapier** | Rapier compiled to WASM; deterministic, fast, actively maintained |
| Controller | **ecctrl** or custom | pmndrs floating-capsule controller on Rapier. Start with it; fork when the blaster/mount states outgrow it |
| State | **zustand** | Outside React's render cycle — critical, since game state must not trigger reconciliation at 60 Hz |
| Raycast | **three-mesh-bvh** | Native `Raycaster` is O(n) per mesh and will not survive slug projectile queries |
| Build | **Vite** | Instant HMR, code-splitting via dynamic `import()` — which is also your chunk-streaming mechanism |
| Assets | **gltf-transform** + **gltfjsx** | Draco/Meshopt geometry, KTX2 textures, typed component generation |
| Audio | **Howler.js** or Web Audio directly | Positional audio; Howler for pooling and mobile unlock quirks |
| Testing | **Vitest** + **Playwright** | Unit for systems, headless browser for smoke and perf assertions |
| Deploy | **Vercel / Netlify / Cloudflare Pages** | Static + CDN; assets on the same CDN with long cache headers |

**Renderer target:** WebGL2 baseline, WebGPU opt-in behind a feature check. WebGPU is meaningfully faster for the instanced foliage in §4.3, but WebGL2 remains the compatibility floor. Don't write two renderers — write WebGL2, and let Three's WebGPURenderer take it when available.

**Dependency discipline:** the list above is the whole list. Everything else you write. Every dependency is 2 a.m. debugging and first-load bytes.

---

## 3. Project structure

```
slugterra-web/
├── index.html
├── vite.config.ts
├── src/
│   ├── main.tsx
│   ├── App.tsx                    # Canvas, Suspense boundaries, HUD overlay
│   ├── engine/
│   │   ├── streaming/
│   │   │   ├── ChunkManager.ts    # load/unload, LRU cache, hysteresis
│   │   │   ├── chunkRegistry.ts   # coord → dynamic import()
│   │   │   └── OriginShifter.ts   # float32 rebase — still required in JS
│   │   ├── lod/
│   │   ├── nav/
│   │   │   ├── NavMesh.ts         # baked offline, loaded per chunk
│   │   │   └── pathfind.ts        # A* over navmesh polys
│   │   ├── bt/                    # behavior tree runtime (~200 lines, you write it)
│   │   └── save/
│   ├── game/
│   │   ├── player/                # controller, camera rig, Blaster, SlugFu, AmmoWheel
│   │   ├── slug/
│   │   │   ├── SlugProjectile.ts  # manual integration, NOT a rigidbody
│   │   │   ├── Velocimorph.tsx
│   │   │   └── effects/           # one module per slug effect
│   │   ├── npc/                   # NPC tiers, perception, schedules
│   │   ├── combat/                # damage resolver, statuses, ghouling, duels
│   │   ├── quest/
│   │   └── world/
│   ├── data/                      # ← content, mirrors Godot's data/ exactly
│   │   ├── slugs/*.ts             # SlugData objects, typed
│   │   ├── elements/matchup.ts
│   │   ├── characters/
│   │   ├── caverns/
│   │   └── quests/
│   ├── state/                     # zustand stores
│   ├── ui/                        # React DOM HUD — not in the Canvas
│   └── types/
├── public/
│   └── assets/
│       ├── licensed/              # ← licensor glTF, gitignored
│       └── placeholder/           # ← CC0 + primitives
├── tools/                         # asset pipeline, navmesh baker, validators
└── tests/
```

**`src/data/` stays the load-bearing decision**, exactly as in the Godot plan. Content is typed TS objects; systems are code. Adding slug #13 is a data file. An agent can add content without touching systems. `tools/validateData.ts` walks it and catches broken references at build time — and with TypeScript you get most of that for free.

**HUD is React DOM, not in-Canvas.** Rendering the ammo wheel, charge meter and slug mood icons as regular DOM over the canvas is dramatically cheaper than drawing them in WebGL, and far easier to iterate. Only in-world markers use drei's `<Html>`.

---

## 4. World architecture

### 4.1 Scale, revised down

The browser budget forces this, and it's the honest number:

| | Godot plan | Web plan |
|---|---|---|
| M1 cavern | 1 km² | **400 × 400 m** |
| Chunk size | 256 m | **100 m** |
| Active chunks | 3×3 | **3×3 (9)** |
| Total M1 chunks | — | 16 |
| Full-scope caverns | ~30 | **6–8** |
| Peak loaded tris | 1.5 M | **600 k** |
| First-load payload | n/a | **< 15 MB** |

A 400 m cavern with real verticality, dense detail and 30 NPCs plays better than a sparse 1 km² one. Quiet Lawn Cavern at this size is still a substantial space when you're on foot and firing slugs. **Scale down without apologising for it** — web games that try to be Skyrim die on first load.

### 4.2 Streaming via code-splitting

The nice trick the web gives you: **Vite's dynamic `import()` is your chunk streamer.** Each chunk is a module that default-exports its content; the bundler splits it automatically, the browser caches it, and the CDN serves it.

```ts
// src/engine/streaming/chunkRegistry.ts
export const chunkRegistry: Record<string, () => Promise<ChunkModule>> = {
  'quiet_lawn:0,0': () => import('../../data/caverns/quiet_lawn/chunk_0_0'),
  'quiet_lawn:0,1': () => import('../../data/caverns/quiet_lawn/chunk_0_1'),
  // generated by tools/generateChunkRegistry.ts — never hand-maintained
};
```

```ts
// ChunkManager — the shape, not the whole implementation
class ChunkManager {
  private loaded = new Map<string, LoadedChunk>();
  private pending = new Map<string, Promise<ChunkModule>>();
  private unloadTimers = new Map<string, number>();

  update(playerPos: Vector3) {           // called at 4 Hz, never per-frame
    const want = this.chunksInRadius(playerPos, 1);   // 3×3
    for (const key of want) {
      this.unloadTimers.delete(key);      // cancel a pending unload — hysteresis
      if (!this.loaded.has(key) && !this.pending.has(key)) this.load(key);
    }
    for (const key of this.loaded.keys()) {
      if (!want.has(key) && !this.unloadTimers.has(key)) {
        this.unloadTimers.set(key, window.setTimeout(() => this.unload(key), 5000));
      }
    }
  }
}
```

**Disposal is mandatory and it is the #1 web-3D memory bug.** Godot freed GPU resources for you; Three.js does not. Every unload must explicitly `.dispose()` geometries, materials and textures, and remove the objects from the scene graph. Miss this and you leak until the tab dies — typically 20 minutes into playtesting, which is exactly when you've stopped looking for it. Write `disposeChunk()` once, test it with a loop that loads and unloads 200 chunks while watching `renderer.info.memory`, and add that as a CI assertion.

**Asset cache:** an LRU over loaded GLTFs keyed by URL, capped by estimated bytes (~200 MB). Shared assets — slug models, common props — pin outside the LRU. drei's `useGLTF` caches by URL already; you're adding eviction, which it doesn't do.

### 4.3 Terrain

No Terrain3D. Options, in order of preference:

1. **Baked heightmap → chunked meshes, generated offline.** A Node script generates per-chunk `.glb` terrain from a heightmap using the same noise approach as the Godot plan, Draco-compressed. Runtime just loads meshes. **Recommended** — cheapest at runtime, and you keep the offline-generation workflow.
2. Runtime `PlaneGeometry` displacement from a heightmap texture — simpler, but you pay CPU on every chunk load and can't hand-edit the result.
3. Full runtime procedural — don't.

Since caverns are enclosed, you need **ceilings and walls**, not just ground. Model cavern shells as separate meshes per chunk, and lean on them: enclosed geometry means frustum and occlusion culling actually work, and you almost never render the whole cavern at once.

**Foliage and props: `InstancedMesh`, always.** drei's `<Instances>`/`<Instance>` wraps this ergonomically. Crystals, mushrooms, rocks, debris — one draw call per prop type per chunk. This is the difference between 300 and 3,000 draw calls.

**LOD** via drei's `<Detailed distances={[0, 25, 60]}>`. Three tiers is enough: full, reduced, impostor billboard.

### 4.4 Floating origin — still required

JavaScript numbers are float64, but **Three.js stores positions in Float32Array**, and the GPU is float32 regardless. Same jitter, same threshold, same fix: rebase the world root past 2 km and emit an `originShifted` event. Even at 400 m per cavern, cross-cavern world coordinates accumulate. Build it in M1; retrofitting is the same pain as before.

### 4.5 Navigation

No `NavigationServer`. Bake navmeshes offline with **recast-navigation-js** (Recast/Detour compiled to WASM — the same library Godot and Unity use underneath), store one navmesh per chunk as a binary blob, load it with the chunk, and run A* over the polys. Query it on a Web Worker so pathfinding never blocks the frame.

Three layers as before: ground, flight, mecha.

---

## 5. Physics and the projectile

**Rapier via react-three-rapier** for character, world collision and NPCs.

**Slug projectiles do not use Rapier.** Manual integration, same as the Godot plan and for the same reasons: frame-exact velocity checks at the 100 mph threshold, ricochet counts for Speedstinger, Slug Fu steering authority, and homing return. Integrate by hand and raycast between last and current position each tick with **three-mesh-bvh** — which also prevents tunnelling at 62 m/s.

```ts
// SlugProjectile — the core of the whole game
const VELOCITY_THRESHOLD = 44.7;  // 100 mph, canon

step(dt: number) {
  this.prevPos.copy(this.pos);
  this.vel.addScaledVector(GRAVITY, dt * this.data.massFactor);
  if (this.slugFuActive) this.applySteering(dt);      // budget-limited
  this.pos.addScaledVector(this.vel, dt);

  if (this.state === 'DORMANT' && this.vel.length() >= this.data.velocityThreshold) {
    this.transform();                                  // → Velocimorph
  }
  const hit = this.bvhRaycast(this.prevPos, this.pos);
  if (hit) this.onImpact(hit);                         // dud if still DORMANT
}
```

Pool projectiles. Allocating a mesh per shot causes GC pauses, and GC pauses in a browser game read as the game stuttering when you fire — the worst possible place for a hitch.

---

## 6. NPC AI

No LimboAI. Write a behavior tree runtime — it's genuinely ~200 lines and you avoid a dependency:

```ts
type Status = 'success' | 'failure' | 'running';
interface Node { tick(bb: Blackboard, dt: number): Status }
// Sequence, Selector, Parallel, Inverter, Condition, Action, Cooldown, Wait
```

Trees are **data**, defined in `src/data/npc/trees/` as typed object literals — which keeps them agent-authorable and diffable, and gets you most of what LimboAI's editor offered without the editor.

Tree structure, tiers, perception and schedules are all unchanged from the Godot TDD §5. The three-tier system (200 ambient / 40 interactive / 15 director) matters **more** here, not less — a browser has less headroom, so aggressive tiering is the difference between shipping and not.

**Perception on a Web Worker.** Vision cone tests and BVH raycasts for 40 NPCs at 5 Hz round-robin move off the main thread entirely. This is one of the few places where the web's threading story is actually workable, and it buys real frame time.

---

## 7. Performance budget

Tighter than Godot's, non-negotiable, and the whole design bends to it:

| Budget | Target |
|---|---|
| Frame time | 16.6 ms: ≤5 ms JS, ≤9 ms GPU, 2.6 ms headroom |
| Draw calls | **< 400** (vs 1,200 in Godot — instancing is mandatory, not optional) |
| Visible tris | **< 600 k** |
| First-load payload | **< 15 MB** gzipped, to first interaction |
| Total asset budget | < 250 MB across all chunks |
| JS heap | < 500 MB steady state |
| GPU memory | < 800 MB |
| Per-frame allocations | **~0** — pool everything, no `new Vector3()` in `useFrame` |
| Dynamic lights | **< 4** (bake everything else to vertex colours / lightmaps) |

**Optimisation order:**
1. **Instance everything repeated.** Single biggest lever on the web by a wide margin.
2. **Don't simulate what isn't near the player** — NPC tiers, chunk radii.
3. **Bake lighting.** Four real-time lights is the ceiling; bake the rest into vertex colours or lightmap textures. Bioluminescent caverns bake beautifully — emissive materials need no light at all.
4. **Zero per-frame allocation.** Preallocate scratch vectors at module scope. GC pauses are the characteristic web-game stutter.
5. Only then micro-optimise, profiler open.

**Measure on a mid-range laptop with integrated graphics, in Chrome, with a 4× CPU throttle on.** Your dev machine lies to you, and web games get opened on whatever the visitor happens to have.

---

## 8. Asset pipeline

### 8.1 Sourcing

| Category | Source | Status |
|---|---|---|
| Slugs, characters | **Licensor (WildBrain), on approval** | Blocked until license closes — and blocking nothing, see below |
| Greybox stand-ins | Primitives + **Kenney**, **Quaternius** (CC0) | Available now, shippable if one survives |
| Environment, props, terrain | **Your own** — original geometry in the show's world, not protected character design | Available now |
| HDRIs | **Poly Haven** (CC0) | Available now |

M0 and M1 need **zero character art**. Slugs greybox as coloured spheres that scale up on transform, and that is genuinely enough to test whether the 100 mph mechanic is fun — which is the only question that matters before month three.

AI 3D generation (Meshy, Tripo, Hyper3D) earns its place on environment props at volume: crystals, rocks, mushrooms, crates, machinery, ruins. It's weakest on appealing characters with clean topology, which is fine — characters aren't yours to make on this project.

### 8.2 Processing — the web-specific part

Every asset goes through this. It is not optional at a 15 MB budget:

```bash
# 1. Geometry compression — Meshopt preferred (faster decode than Draco)
gltf-transform optimize in.glb out.glb \
    --compress meshopt --texture-compress ktx2

# 2. Texture compression — KTX2/Basis stays compressed in GPU memory,
#    unlike PNG/JPG which decompress to full size on upload
gltf-transform uastc out.glb out.glb --level 4 --rdo 4

# 3. Typed React component
npx gltfjsx out.glb --types --instance --transform
```

**KTX2 is the single biggest win available to you.** A 2048² PNG occupies ~16 MB of GPU memory once uploaded; the KTX2 equivalent stays compressed on the GPU at ~1–4 MB. With a 800 MB GPU budget, this decides whether the project fits.

**Budgets per asset:**

| Asset | Tris | Textures |
|---|---|---|
| Slug (dormant) | < 1,500 | 1× 512² atlas |
| Velocimorph | < 6,000 | 1× 1024² |
| NPC (humanoid) | < 8,000 | 1× 1024² atlas |
| Prop | < 500 | shared atlas per chunk |
| Terrain chunk | < 8,000 | shared cavern atlas |

Note these are roughly half the Godot budgets. **Share texture atlases per chunk** — it's what keeps draw calls under 400.

**Licensor intake** adds a step: show assets arrive at production topology with animation rigs, and need decimation plus retargeting to a game skeleton in Blender before entering this pipeline. Audit the first delivery immediately; don't assume it's usable.

---

## 9. Save system

`localStorage` is too small (~5–10 MB) and synchronous. Use **IndexedDB** via `idb`.

Same shape as the Godot plan: **version the format from save #1.** Persist player transform and cavern, owned slugs with full per-instance state (experience, energy, trust, fatigue, ghouled), belt loadout, blaster upgrades, quest states, faction reps, world flags, and chunk deltas as a sparse map keyed by chunk coord. Never persist terrain or static content.

Web-specific: autosave on `visibilitychange` (tab hide) as well as on interval — browser tabs die without warning. And offer JSON export/import so a player's save survives a cleared cache, which on the web is a matter of when, not if.

---

## 10. Milestones

| Milestone | Content | Target |
|---|---|---|
| **M0 — Greybox loop** | Vite+R3F+Rapier scaffold, controller, camera, charge-and-fire blaster with the 100 mph band, Burpy as a sphere, 1 dummy target, 100 m flat plane, Vitest + Playwright CI | 1–2 weeks |
| **M1 — Vertical slice** | Quiet Lawn Cavern 400×400 m, 16 chunks with streaming + disposal, Shane Hideout, 4 slugs, 3 NPC archetypes, BT runtime, 1 duel (Shock Wire), capture, IndexedDB save, floating origin, **deployed to a public URL** | 6–8 weeks |
| **M2 — Systems complete** | All 12 slugs + 12 ghouls, ghouling/purification, quests, faction rep, bonding, blaster upgrades, full matchup matrix | +8 weeks |
| **M3 — World** | Chillbore, Scrapheap, Slagrock, Bandoleer; cross-cavern streaming; Mecha Beast traversal; ~20 POIs; 30 NPCs; tournament | +10 weeks |
| **M4 — Ship** | Eastern Caverns + Slug Fu, Deep Caverns, main quest, Blakk and Brimstone, audio, WebGPU path, optimisation pass | +10 weeks |

M1 shipping to a **public URL** is the change worth noticing. On the web, M1 is something you can put in a message and someone opens in one click — a licensor demo, a portfolio link, a benchmark baseline. That's a materially better position than a Godot build nobody will download, and it's the strongest argument for this pivot.

---

## 11. Benchmark protocol — Fable 5.1 vs GPT-6

**The pivot improves this.** The Godot plan's one weakness was that scene editing, terrain sculpting and the LimboAI tree editor were GUI work no model could reach, which capped how much of the project the benchmark could cover. Here, **100% of the project is TypeScript**, and every result is verifiable by running the dev server and driving a headless browser.

Method unchanged from the Godot TDD §13: shared baseline commit, sealed task specs written in advance, sealed test suites never shown to the models, identical harness and turn budget, blind grading, **N ≥ 3 runs per task per model.**

### 11.1 Revised task ladder

| # | Task | Difficulty | Tests |
|---|---|---|---|
| 1 | Add Flaringo as slug #13 given the `SlugData` pattern | Trivial | Pattern following |
| 2 | Implement the 7-rule status cross-interaction table | Easy | Spec adherence |
| 3 | Write `OriginShifter` + retrofit 6 systems to handle `originShifted` | Medium | Cross-file reasoning |
| 4 | `ChunkManager`: async load, hysteresis unload, LRU cache, **full GPU disposal** | Medium-hard | Async lifecycle, resource management |
| 5 | Write the behavior tree runtime from scratch + the duel tree with counter-picking | Hard | API design + game feel |
| 6 | IndexedDB save/load: versioned format + sparse chunk deltas | Hard | Serialisation, edge cases |
| 7 | Ghouling system — Goon Doc corrupts a belt slug, Boon Doc purifies | Hard | Multi-system state |
| 8 | Given a build leaking GPU memory on chunk unload, find and fix it | Hard | Diagnosis under ambiguity |
| 9 | Optimise a scene from 2,000 draw calls to under 400 | Hard | Perf reasoning, instancing |
| 10 | Given only §4 of this doc, design and implement the cavern graph | Very hard | Open-ended architecture |

Tasks 8 and 9 are new and web-specific, and they're the most interesting ones in the set — GPU resource leaks and draw-call optimisation are exactly the kind of problem where models tend to produce plausible-looking code that doesn't actually fix anything.

### 11.2 Rubric (100 pts/task)

| Dimension | Pts | Measured by |
|---|---|---|
| Tests pass | 30 | Vitest, automated |
| Runs without error | 15 | Playwright headless boot, no console errors |
| Meets written spec | 15 | Manual checklist, blind |
| Architectural fit | 15 | Blind review |
| No regressions | 10 | Full suite |
| Perf budget respected | 10 | Playwright asserts draw calls, `renderer.info.memory`, frame time |
| Turns / tokens | 5 | Logged, normalised |

**The web stack automates more of this than Godot did.** Playwright can read `renderer.info` directly out of the page, so draw calls, tri counts, texture memory and frame time all become hard assertions rather than manual review. That pushes the automated share to ~55/100 with much better signal.

### 11.3 CI

GitHub Actions per push: `tsc --noEmit` → `vitest run` → `vite build` → Playwright boots the built app, runs a 600-frame scripted session, asserts no console errors, draw calls < 400, no GPU memory growth across a load/unload cycle. Deploy previews per PR so every model run has a URL you can open.

**On tooling:** build in Cursor if you like — for a pure TypeScript project it's a much better fit than it was for Godot, since there's no editor to context-switch to. But run the **benchmark** through a CLI harness (Claude Code, Codex CLI) with fixed tools and logged turns. Cursor's retrieval is non-deterministic and its per-model scaffolding may differ, which is fine for building and fatal for measuring.

---

## 12. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| **Rewriting engine features eats the schedule** | **High** | Streaming, navmesh, BT, LOD and save were free in Godot. Budget ~6 extra weeks and resist scope growth to compensate. |
| GPU memory leaks on chunk unload | **High** | `disposeChunk()` written and tested in M1, with a CI assertion on `renderer.info.memory` across a 200-cycle load/unload loop. |
| Perf ceiling lower than expected | Medium | 400 m caverns, 400 draw calls, aggressive instancing. Measure on throttled integrated graphics from M0, not at the end. |
| First-load budget blown | Medium | KTX2 + Meshopt from the first asset. CI fails the build over 15 MB. |
| Scope death | **High** | M1 shipped to a URL is the goal. Everything after is optional. |
| License doesn't close | Medium | `public/assets/licensed/` gitignored, manifest indirection, greybox build fully playable. Systems, benchmark and paper survive regardless. |
| Sketchfab assets used and later pulled | Medium | Don't. Two unresolved rights layers (§0.2), plus wrong topology for the budget — you'd rebuild them anyway. |
| Time — internship + final year + this | **High** | 8 focused hours/week beats 30 sporadic. Burn down against M1. |

---

## 13. Immediate next steps

1. `npm create vite@latest slugterra-web -- --template react-ts`; add `@react-three/fiber`, `@react-three/drei`, `@react-three/rapier`, `zustand`, `three-mesh-bvh`
2. Create the §3 skeleton; `public/assets/licensed/` gitignored from the first commit
3. Wire Vitest + Playwright + GitHub Actions **before** writing game code — the feedback loop is what makes everything after it fast, and it's 55 benchmark points
4. Build M0: controller, SpringArm-equivalent follow camera, charge-and-fire blaster with the 100 mph threshold, Burpy as a red sphere that scales on transform, one dummy target, 100 m plane
5. **Play M0 for an hour.** If charge-and-dud isn't fun with a capsule firing a sphere, nothing downstream fixes it.
6. Deploy M0 to a URL. It costs ten minutes and it makes the project real.
7. Freeze M0 as the benchmark baseline; write the sealed task specs and test suites.

---

## Sources

**Technical**
- [React Three Fiber](https://github.com/pmndrs/react-three-fiber) · [R3F docs](https://r3f.docs.pmnd.rs/getting-started/introduction) · [ecctrl controller](https://github.com/pmndrs/ecctrl)
- [GLTFLoader — three.js docs](https://threejs.org/docs/pages/GLTFLoader.html) · [Three.js performance checklist](https://marceloretana.com/checklist/threejs-performance-checklist) · [100 Three.js performance tips](https://www.utsubo.com/blog/threejs-best-practices-100-tips) · [Three.js in production 2026: WebGPU and fallback](https://appscale.blog/en/blog/threejs-production-3d-web-2026-webgpu-realtime-standards)

Use 3D models from this - https://sketchfab.com/tags/slugterra

- [R3F vs Three.js vs Babylon.js 2026](https://www.pkgpulse.com/guides/threejs-vs-react-three-fiber-vs-babylonjs-3d-webgl-2026)

**Canon reference** — see the Godot TDD for the full list
- [Slugs — SlugTerra Wiki](https://slugterra.fandom.com/wiki/Slugs) · [List of Slugterra slugs](https://en.everybodywiki.com/List_of_Slugterra_slugs) · [List of Slugterra characters](https://wikimili.com/en/List_of_Slugterra_characters) · [The 99 Caverns](https://slugterra.fandom.com/wiki/The_99_Caverns)