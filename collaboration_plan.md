# Slugterra collaboration plan

Written by Codex on 2026-09-06. Status: planning complete; division of work proposed to Claude; implementation has not started in this session.

## Authority and purpose

Build one shared Godot game with Claude Code and Codex collaborating. The user's current instruction takes precedence over the competitive benchmark framing in [the technical design](.claude/Slugterra.md), especially section 13 and the benchmark-specific steps in section 16. Keep shared tests, CI, profiling, and reproducible builds because they improve the game. Sealed tests, separate competing implementations, blind scoring, model comparisons, and publication work are outside the current scope.

This turn delivers a plan and handoff documents only. Implementation begins in a subsequent work session. The user will supply the remote repository link; Git setup, commits, and pushes follow then. The schedules in the design are estimates, not delivery promises.

The primary product target is a polished M1 Quiet Lawn vertical slice. Build and playtest the small M0 shooting loop first. M2-M4 remain a roadmap until M1 passes its acceptance gate.

## Workspace baseline

| Item | Observed state |
|---|---|
| Workspace | `D:\Slugterra` |
| Source design | `.claude/Slugterra.md`, version 1.0; read in full, sections 0-16 |
| Existing game root | `slugterra/`; `res://` paths refer to this directory |
| Existing files | `project.godot`, `icon.svg`, `icon.svg.import`, `.gitignore`, `.gitattributes`, `.editorconfig`; generated `.godot/` cache also exists |
| Engine configuration | Project advertises `4.7`, Forward Plus, Jolt Physics, and Windows D3D12; source document requests `4.6.3-stable` |
| Gameplay | No main scene configured; no gameplay scripts, content resources, tests, or addons found |
| Git | Neither workspace nor game root is currently a Git repository; no remote is configured |
| Git LFS | Installed: `git-lfs/3.5.1`; existing attributes only normalize text line endings |
| Godot executable | `godot` and `godot4` were not found on PATH; this does not establish whether Godot is installed elsewhere |
| Local instructions | No `AGENTS.md` or `CLAUDE.md` found in the inspected workspace; no `D:\AGENTS.md` present |

Proposed repository root: `D:\Slugterra`, keeping the source design, collaboration documents, and existing `slugterra/` project together. Do not move or recreate the current project. Inspect the supplied remote before choosing whether to attach this workspace or reconcile with an existing checkout.

## Product requirements to preserve

1. **Blaster-centered play.** Third-person exploration, physical slug shots, a charge skill gate, and later Mecha Beast traversal. Use the design's `CharacterBody3D`, swappable movement provider, and SpringArm camera direction. Create only the movement states needed by the active milestone.
2. **Charge and transformation.** The design specifies a nonlinear 0.6-second charge, 20-62 m/s launch speed, and an inclusive 44.7 m/s transformation threshold. Show a clear 100 mph notch on the charge meter. Derive its position from the actual charge curve; it is not necessarily halfway across the meter.
3. **Individual slugs.** A breed definition is a shared resource; an owned slug has its own identity, experience, energy, trust, fatigue, and corruption state. No interchangeable infinite ammunition. A slug already flying, returning, cooling down, or corrupted is unavailable for firing.
4. **Full shot lifecycle.** Dormant flight -> transform -> effect -> revert -> return -> cooldown. Under-speed impact produces a dud with a 1.5-second wait and automatic recall, no cooldown penalty, and no experience reward. The design calls for a 0.25-second transformation, 60 ms hitstop, and approximately 1.2-second successful return. Make timings tunable and define which clock controls them.
5. **Continuous projectile collision.** Follow the design's manually integrated movement and swept collision between old and new positions. Visual transformation, high speed, a moving target, and later ricochets must not duplicate hits or strand the owned slug.
6. **Data-driven content.** Systems in `src/`, definitions in `data/*.tres`, assembly in `scenes/`. One combat resolver for every attacker/target combination. The ten-element matrix and seven status interactions belong in explicit data tables. New behavior may need a new effect script; adding a breed that reuses existing effects should require only content.
7. **Asset indirection.** M0/M1 must load with primitives and no licensed art present. Keep default resource references pointed at available placeholders. Configure `assets/licensed/` exclusion before the first content commit; approved asset bindings can be supplied separately. Preserve the design's asset-intake audit, retargeting, and validation workflow for later deliveries.
8. **Authored world.** Hand-authored cavern graph, editor-generated and baked terrain, hand-placed landmarks, deterministic scatter. No runtime terrain generation or navigation baking. Preserve stacked cavern/deck support in identity and coordinate contracts from M1 onward.
9. **Bounded simulation.** Stream scene content separately from terrain LOD. Distinguish Ambient, Interactive, and Director NPC tiers; schedule distant NPCs without running their full AI. Perception must be staggered. Quests react to events rather than polling.
10. **Persistence from its first implementation.** Version saves; store stable IDs and sparse chunk changes, not entire static scenes or terrain. Origin shifts must leave chunk identity, progression, and save/load positions consistent.

## Milestones and acceptance gates

| Milestone | Deliverable and gate | Design estimate |
|---|---|---|
| M0: greybox loop | 200 m flat arena, capsule player, exploration/aim camera, charge HUD, one Burpy sphere, one damageable dummy. Early release reliably duds; charged release visibly transforms; damage, return, availability, cooldown, and experience are coherent. Repeat firing without state leaks. User plays the loop for the design's proposed one hour and feedback is recorded before world expansion. | 2 weeks |
| M1: vertical slice | Quiet Lawn around 1 km² and Shane Hideout; four playable breeds, six-slot belt UI, wild capture, three NPC archetypes, Shock Wire duel, one follower slot, minimal dialogue/tutorial flow, save/load, scene streaming, and floating origin. A player can explore -> capture/equip -> duel -> return/rest -> save/reload with progress intact. Profile on the user's laptop at 1080p. | 6-8 weeks |
| M2: systems complete | All 12 base breeds and 12 specified ghoul counterparts, Goon Doc corruption and Boon Doc purification, all ten elements and seven status interactions, full bonding/energy/fatigue tuning, upgrades, quests, faction reputation, and supporting menus. | +8 weeks |
| M3: world | Chillbore, Scrapheap, Slagrock, Bandoleer, inter-cavern travel, Mecha Beast movement provider, two follower slots, roughly 25 POIs, 40 NPCs, and tournament wrapper. Final cavern count needs reconciliation with section 4. | +12 weeks |
| M4: completion | Eastern Caverns and Junjie/Slug Fu, Cavern of Time, Deep Caverns, main story and Blakk/Brimstone encounters, remaining audiovisual work, performance and release validation. | +12 weeks |

Proposed M1 breeds: Infurnus, Tazerling, Aquabeek, Frostcrawler. They expose direct offense, Soaked/Energy chaining, and Ice control/traversal with only four breeds. Boon Doc and ghouling remain M2. Proposed M1 NPC archetypes: ambient resident, noncombat interactive ally/follower, rival slinger; Shock Wire uses the rival behavior plus persistent named-character state. These are scope choices for Claude to review, not details specified by the source.

## Proposed ownership

Ownership identifies the primary writer, not exclusive design authority. Both agents review each other's work. Claude has not yet acknowledged this allocation.

Paths below are relative to `slugterra/` unless prefixed with `workspace:`. Tests follow the feature owner. Each owner maintains their own handoff document.

| Area | Primary writer | Boundaries / collaborating agent |
|---|---|---|
| Repository setup, LFS, dependency pins, CI, validators | Codex | Workspace Git metadata, `addons/` intake, `tools/`, CI workflows; Claude validates editor startup |
| Project configuration | Codex | `project.godot`, autoload registration, input-map and addon settings; Claude requests additions through the handoff |
| Shared runtime services and contracts | Codex | `src/autoload/`, schema scripts, `EventBus`, `GameState`, `CombatResolver`, `SaveManager`; document public changes before consumers depend on them |
| Player, movement, camera, blaster, belt HUD | Claude | `src/player/`, player/HUD prefabs, `src/ui/`, camera/blaster configuration resources; consume Codex's projectile and slug interfaces |
| Slug definitions, instances, projectiles, effects | Codex | `src/slug/`, `data/slugs/`, slug/effect prefabs; Claude integrates and tunes presentation through resources |
| Combat rules and progression | Codex | `src/combat/`, `data/elements/`, damage/status/ghouling, upgrade and bonding rules; Claude authors associated UI and encounter usage |
| World streaming, origin, persistent chunk state | Codex | Runtime world services and world/biome schema scripts; Claude supplies chunk content and authored coordinates |
| Cavern authoring and scene assembly | Claude | `scenes/caverns/`, `scenes/main.tscn`, `data/caverns/`, biome resource instances, terrain authoring tools, placeholder environments and navigation bakes |
| NPCs, perception, schedules, followers | Claude | `src/npc/`, `data/characters/`, NPC prefabs and LimboAI trees; consume shared combat, movement, and persistence contracts |
| Duels and quests | Split by named file | Codex owns `src/combat/duel_controller.gd`, quest runtime and quest schemas. Claude owns encounter scenes, quest resource instances in `data/quests/`, and dialogue runtime/content/UI. Split paths explicitly before starting |
| Audio and visuals | Split by named file | Codex registers a minimal AudioDirector when needed; Claude owns playback/presentation content and game feel. Audio is not a new M0 content project |
| Integration and review | Claude: playable scene; Codex: repo/CI | One writer per scene/config file. The other reviews diffs and reproduces validation |
| Collaboration documents | Codex: this plan and `codex_handoff.md`; Claude: `claude_handoff.md` | All three at workspace root; propose ownership or plan changes in your own handoff |

Avoid broad overlapping claims such as both agents owning all of `scenes/prefabs/` or `tools/`. Name the exact feature subdirectory/files in the claim. Codex's tooling ownership excludes Claude's cavern-generation authoring scripts. A scene owner instances another owner's prefab instead of editing its internals.

## First implementation queue

All tasks below are **planned**, not active claims. The present request does not start implementation.

| ID | Owner | Depends on | Concrete output and completion evidence |
|---|---|---|---|
| P0 | Claude | Read plan/handoff | Author `claude_handoff.md`; accept or amend ownership, M1 scope, and the interface proposals. Record existing work before claiming new paths. Stay at planning scope until implementation is requested. |
| S0 | Codex | Repo link; next implementation session | Inspect remote and reconcile repository root; locate Godot executable; verify engine/addon compatibility against official releases; record exact engine and addon pins. Reconcile current 4.7 settings without an unannounced downgrade. |
| S1 | Codex | S0 | Extend the existing project to the section 10 directory layout, configure ignore/LFS rules, vendor only Terrain3D/LimboAI/gdUnit4 with licenses and immutable version/checksum evidence, and add documented import/test commands. Prove the chosen engine imports the project and addons. Do not require terrain or AI nodes in the M0 scene. |
| C0 | Codex, Claude review | P0; S0 for API details | Write `docs/contracts.md` with concrete typed fields/signatures, input action names, collision layers, units, timing, and event ownership. Publish stub-free minimal runtime types/services as needed; consumers can start once their subset is ready. |
| A0 | Claude | C0 movement/input subset | Player movement provider, capsule controller, exploration/aim camera resources, and player prefab. Validate jump/landing, camera collision, aim transition, and release/capture of the pointer. Include a duel camera profile for later use without implementing the duel here. |
| B0 | Codex | C0 slug/combat subset | `SlugData`, `SlugInstance`, Infurnus resource, kinematic projectile lifecycle, placeholder dormant/velocimorph prefabs, damage packet/resolver, and dummy prefab. Validate threshold boundaries, one-time damage/XP, dud recovery, successful return/cooldown, and ownership release on interruption. |
| A1 | Claude | A0; B0 firing contract | Charged blaster and HUD connected to the same charge configuration, clear threshold notch, launch from muzzle toward camera aim, and unavailable-slug feedback. Input intent routes through the launch interface rather than directly changing slug state. |
| I0 | Claude assembly; Codex review/tests | A1; B0 | `scenes/main.tscn` and 200 m M0 arena integrate player, projectile and dummy prefabs. Codex registers the agreed main scene in project configuration. Verify repeated successful and dud shots in the actual running scene. |
| Q0 | Codex automated; Claude interactive | I0 | Headless import, focused gdUnit4 suites, a 600-physics-frame smoke run, and interactive 1080p check. Record commands, engine version, exit codes and failures. User playtest feedback determines tuning and readiness for M1. |

Parallel work begins after the relevant C0 interfaces exist: Claude builds A0 while Codex builds B0. A1 can proceed against the published launch contract without waiting for every B0 effect/polish detail. Neither agent reimplements the other side to bridge a dependency; request the smallest missing interface instead.

## M1 implementation queue

Start after M0 is functional and the playtest gate has been addressed. Split each row into reviewable commits with exact file claims before coding.

| ID | Owner | Dependencies | Acceptance |
|---|---|---|---|
| W1 | Codex | M0; coordinate contract | Implement cavern/chunk/deck identity, origin shifting at the design's 2 km threshold, scene loading and cancellation, tier transitions, 4 Hz sampling and approximately 5-second unload hysteresis. Test boundary churn, stale completions, reload, and stable persistence keys after repeated shifts. |
| W2 | Claude | W1 schemas; Terrain3D pin | Author Quiet Lawn, Hideout, tutorial route, capture nests and arena with vertical landmarks. Bake terrain/navigation offline, scatter deterministically, add occluders and chunk/deck metadata. Validate traversal and unload/reload using the runtime streamer. |
| S2 | Codex | B0; chosen M1 breeds | Add Tazerling, Aquabeek and Frostcrawler effects/resources plus the status rules those breeds exercise. Keep the shared status schema ready for the complete seven-rule M2 table. Validate single-target, chained, frozen and returning-shot behavior. |
| N1 | Claude | W1/W2; combat contract | Three NPC archetypes, staggered hearing/vision, schedules and WorldClock integration, one companion slot, minimal dialogue, and Shock Wire behavior with counter-picking. Check active AI counts and promotion/demotion lifecycle. |
| G1 | Codex runtime; Claude capture presentation | S2; N1 perception reuse | Implement capture rules, collection/belt/rest state, six-slot equipment constraints, and duel rounds/results. Claude supplies non-damaging capture scene/input feedback, wheel at 0.25 time scale, collection menu and duel arena presentation. A captured slug has one stable instance ID. |
| P1 | Codex | Stable IDs; W1; G1 | Versioned save/load of player/cavern position, owned slug state, belt, progression, world flags and sparse chunk deltas. Test round trip, malformed/unsupported data, interrupted writes, missing content IDs, and duplicate IDs without losing the last valid save. |
| Q1 | Claude content; Codex runtime/verification | N1; G1; P1 | Minimal event-driven tutorial objectives, no full M2 campaign. Verify explore/capture/equip/duel/rest/save/reload as one flow, including chunk reload and forced origin shift. Profile representative Quiet Lawn traversal/combat on the target machine and tune before extending the world. |

M2 extends the same interfaces to the complete roster, status matrix, corruption/purification, faction conditions, schedules, bonding, upgrades and quests. M3 adds cavern content and the mounted movement provider. M4 adds Slug Fu steering, endgame encounters/story, audio and final optimization. Keep new systems attached to an actual milestone need.

## Interface proposals to settle before consumers are implemented

These are intended behaviors, not claims that classes or APIs already exist. C0 records exact GDScript signatures and pinned-addon APIs.

| Contract | Proposal |
|---|---|
| Units and charge | Godot world units represent meters; durations are seconds; gameplay speed uses m/s. One charge resource owns curve, duration, min/max speed and threshold. The HUD reads it. Default all M0/M1 breeds to the source's 44.7 threshold. |
| Breed vs instance | Immutable breed ID and shared `SlugData`; stable unique owned-instance ID with separate mutable state. Save references by IDs. `GameState` owns the collection; projectile/runtime components reference that instance, not a duplicate progression record. |
| Launch boundary | Player/NPC blaster passes instance ID, muzzle transform, launch velocity and source ID to one projectile launch operation. It validates availability and returns accepted/rejected plus shot ID. The projectile service owns shot state, lifecycle transitions and release of the reservation. |
| Movement/camera | Movement providers supply desired movement to the character controller. The controller owns body motion; camera profiles own presentation. Mounted behavior later swaps the provider. Agree input actions before Codex changes `project.godot`. |
| Damage/effects | The effect creates a packet carrying the design's source, element, base power, experience tier, requested status and impact point, plus stable shot/target IDs where needed. The resolver owns health/status consequences and emits the result once. Specify healing and non-damaging capture separately. |
| Events | Explicit payloads for launch, transform, hit, return, capture, duel result, chunk lifecycle and origin shift. One producer owns each authoritative event; UI/quests observe. Avoid duplicate reward paths through both projectile and effect callbacks. |
| World coordinates | Persist cavern ID, chunk/deck identity and stable position. Use a documented origin offset with `absolute = local + origin_offset`; a shift delta subtracts from local positions and adds to the offset. Shift the world root once; adjust cached positions without moving child nodes twice. Define negative-coordinate chunk mapping and payload sign explicitly. |
| Save boundary | Versioned dictionary containing data/IDs rather than live Nodes/Resources. Sparse keys include cavern, column and deck, with stable placed-object IDs. Save at a safe gameplay boundary initially, or document how in-flight/cooldown state is restored before enabling unrestricted saving. |
| Time | Specify game vs unscaled time for charge, hitstop, flight, return, cooldown, wheel slow motion and world schedules. Centralize time-scale ownership so closing the wheel cannot accidentally cancel another pause/hitstop state. |
| Integration | Prefabs expose documented properties/signals. Claude assembles the playable scene; Codex owns service registration. Public API changes list affected consumers, a migration step, and focused validation in the writer's handoff. |

## Decisions and inconsistencies identified in the source

Resolve these at the milestone shown; they do not block the current planning deliverable. Proposals are visible so neither agent silently treats an assumption as canon or an accepted requirement.

| Issue | Proposed handling | Owner / deadline |
|---|---|---|
| Competitive benchmark vs current request | Use one collaborative implementation and shared quality checks; no benchmark deliverables. | Resolved by user instruction |
| Godot 4.6.3 in source vs 4.7 in existing project | Preserve current config during planning. Check actual executable and official supported addon binaries before selecting/pinning the build environment. Source version labels have not been independently verified in this session. | Codex S0; Claude reviews |
| Universal 100 mph rule vs per-breed threshold variance | Use 44.7 m/s inclusive consistently in M0/M1. Treat alternate thresholds as an explicit future balance change. The document's rounded conversion is the gameplay constant for now. | Both, C0 |
| Transform animation vs collision | Define whether collision during the 0.25-second transition resolves as a transformed hit; proposed: eligibility locks at threshold and damage resolves once even before the visual completes. | Both, C0 |
| Dud energy penalty unspecified | Preserve no cooldown/no XP and propose no net energy cost for a dud, consistent with lost-tempo punishment. Lock the energy accounting before adding energy costs; high-trust Burpy avoids random transform failures in M0. | Codex, C0/S2 |
| Charged shot cutoffs and interrupted return | Define timeout/out-of-bounds, target deletion and owner/chunk unload recovery so the owned slug never disappears or remains permanently reserved. | Codex B0 |
| Four M1 slugs / three NPC archetypes unspecified | Use the proposed M1 selections above; Claude may amend before implementation. Full purification is M2, matching section 14. | Both, P0 |
| Ten-by-ten matrix has no full values | Mark unspecified interactions neutral/provisional in development data; preserve explicitly specified rules. Complete the balance table before M2 acceptance rather than inventing canon claims. | Codex S2/M2; Claude playtests |
| Speedstinger and Negashade list two elements; sample schema has one | Specify primary/secondary representation and combination policy before adding these breeds. Avoid multiplying two matchup values accidentally. | Both, before M2 roster |
| Status precedence and persistence | Define simultaneous-rule ordering, whether multipliers stack, Petrified heal-block duration, and the meaning of Metal homing through cover. Store these decisions in combat rules/tests. | Codex, before affected effects |
| Source calls center + eight neighbors `r=0` | Proposed spatial meaning: Chebyshev column distance <=1 is full simulation, distance 2 visual only, >=3 impostor/absent; deck relevance is independent. Keep the nine-chunk intent and name simulation tiers separately from distances. | Codex W1; Claude W2 review |
| Worker pool plus threaded loader | Verify the selected Godot APIs; choose one clear load-request lifecycle rather than nesting work queues by habit. Scene attachment/removal belongs to the main-thread integration boundary. | Codex W1 |
| Cavern counts disagree | Section 4 says eight by M3, but its table and section 14 place several of those locations in M4. Plan Quiet Lawn plus the four named M3 additions; reconcile count before M3 scope is committed. The title does not require authoring 99 full maps immediately. | Both, M3 planning |
| `data/biomes/` appears in example, absent from tree | Add this content directory when biome resources are introduced; preserve the source's systems/content split. | Claude W2; Codex schema |
| Data-only expansion vs novel effect scripts | Reusing an effect is data-only. A new mechanical effect legitimately adds an effect script, without editing the central resolver for each breed. | Both, content contract |
| Headless smoke vs laptop rendering target | CI validates correctness, errors and simulation budgets; measure actual 1080p rendering performance on the target laptop. Do not report a headless run as proof of GPU frame time. | Both, Q0/Q1 |

## Communication and change coordination

1. Read the other agent's handoff and current Git status/diffs before each task, after a context restart, before integration, and before writing a shared file. Handoffs are asynchronous communication; do not claim the other agent agreed until their own document says so.
2. Codex writes only `codex_handoff.md`; Claude writes only `claude_handoff.md`. Codex maintains this plan from both agents' recorded decisions. An empty Claude handoff means no Claude-authored response has arrived.
3. Every active claim records task ID, exact files/directories, dependencies, current branch/worktree, base commit, expected output, status and next action. Use `planned`, `active`, `blocked`, `ready-for-review`, `integrated`. Only report `integrated` after the combined project passes relevant checks.
4. Before implementation, Claude acknowledges or revises the proposed split in their handoff. Each owner can then take the next unblocked task within the user's active scope without asking for approval for routine local edits.
5. If a needed file is owned by the other agent, post a concrete request with the intended interface or diff. Transfer ownership explicitly or let its owner apply the change. Do not race to fix both copies of a shared scene or project settings file.
6. Include messages under stable IDs, for example `CX-001` and `CL-001`, with recipient, requested action, response and status. Read acknowledgement is different from completed work. The user need not shuttle routine technical decisions between agents.
7. Review the implementation's behavior and tests, then report defects with file paths and reproduction steps. Feature authors fix their area unless they hand it over. Do not rewrite unrelated work while reviewing.
8. Record uncertainty, failed checks and unavailable tools honestly. A handoff must let the other agent reproduce the current state without relying on conversation history.

### Git workflow once the repository link arrives

- Codex handles initial remote inspection/setup and the baseline integration unless Claude has already claimed that work. If the remote contains work, inspect it before reconciling; never replace its history or push with force.
- Configure LFS for intended binary assets before adding them, and exclude licensed assets and generated caches/builds. Review both workspace-level and game-level ignore/attribute rules. Keep `.tres`, `.tscn` and source as reviewable text.
- With a usable common baseline, prefer separate branches/worktrees such as `codex/m0-slug-core` and `claude/m0-player`. Record base SHA and worktree path in the handoff. Keep handoffs visible through shared workspace-root copies; publish the owner's latest content with their task commits and re-read shared copies before decisions.
- If both agents are using this same working directory, use disjoint file claims and designate **one Git index/commit operator at a time**. Never switch branches, stash, reset, clean or restore over the other agent's work. Codex is the proposed shared-checkout commit operator. An explicit-path commit may include Claude's files only after Claude marks those exact changes ready for integration.
- Inspect unstaged and staged diffs separately. Use explicit paths when staging; never indiscriminately stage the whole shared workspace. Serialize commit/push operations. Commit a completed, tested unit and update the corresponding handoff; once the remote is configured, push at each meaningful integrated checkpoint rather than saving all progress for the end.
- Review branch changes relative to their merge base. After a merge/conflict resolution, rerun the relevant checks on the combined tree, then record feature SHA, integration SHA, tests and push status. If a change is not tested, call it out and do not label the milestone complete.

Read-only commands to use from the repository root after Git exists:

```text
git status --short --branch
git log -5 --oneline
git diff --name-status
git diff --stat
git diff -- <owned-paths>
git diff --cached --stat
git diff --cached -- <owned-paths>
git diff --check
git diff <last-reviewed-sha>..HEAD -- <relevant-paths>
git diff <integration-branch>...<feature-branch> -- <relevant-paths>
```

`<...>` values are placeholders, not literal commands. Untracked files do not appear in a normal `git diff`; inspect them from `git status` and review their full contents before staging. No Git diff, commit or push exists for this planning session because the directory is not a repository yet.

## Verification and definition of done

For each implementation task, record the exact environment and commands, relevant automated outcomes, interactive observations, changed files, remaining limitations and next dependency. Add meaningful behavior tests for core state transitions and persistence, not tests that merely repeat configuration values.

- M0 automation: charge-curve/threshold boundaries, no under-speed damage/XP, one transformation reward per shot, continuous collision, valid availability transitions, recovery after interruption, and one-hit resolution. Headless import and a scripted 600-physics-frame smoke scene are integration gates.
- M1 automation: status interactions in scope, capture uniqueness, duel rounds/results, belt constraints, save round trips/version handling/sparse deltas, chunk border churn, stale async loads, NPC teardown, and origin shifting with active cached positions/projectiles. Exercise negative chunk coordinates and reload after a shift.
- Interactive checks: mouse and aim/camera behavior, soft occlusion fade, readable notch/dud/transform feedback, timings under wheel slow motion/hitstop, traversal/navigation seams, capture feedback and the complete M1 progress loop. Report these as pending when there is no actual interactive run.
- Performance target from section 12: 60 fps at 1080p, approximately 16.6 ms frame budget with <=6 ms CPU game logic and <=8 ms rendering; <1,200 draw calls, <1.5 million visible triangles, <400 actively processing nodes, <25 ticking behavior trees, <=6 terrain LOD levels, and <8 visible dynamic lights. Record hardware/build/scene conditions alongside measurements.
- Fix over-simulation first, then repeated-geometry instancing and lighting, then profiled script hotspots. GDScript is the starting language; use another language only after measured need and an agreed integration plan.
- Every delivered milestone imports and boots without missing licensed files, passes applicable tests, has a reviewable diff and current owner handoffs, and is reproducible from its recorded commit/dependency pins. User playtest feedback remains a separate, visible gate.

## Immediate pickup

Claude: read [codex_handoff.md](codex_handoff.md), write your own [claude_handoff.md](claude_handoff.md), and respond to the three initial messages there. Keep this turn at planning scope. Codex's next implementation work is S0/S1/C0/B0 after the user provides the repository and starts implementation; Claude's first implementation work is A0/A1 after the relevant contracts are available.
