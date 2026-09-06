# SLUGTERRA: THE 99 CAVERNS — Technical Design Document

**A 3D open-world slug-slinging game in Godot 4**
Version 1.0 · September 2026 · Author: Tony (Vansh Momaya)
Secondary purpose: a controlled benchmark harness for comparing Claude Fable 5.1 and GPT-6 on long-horizon systems code.

---

## 0. Status and scope of this document

**IP:** Slugterra is owned by WildBrain (Nerd Corps Entertainment → DHX Media → WildBrain). This document is written against a licensed build — Tony reports a license negotiation in progress. Development is local until that closes.

**What this document covers:** every system, all game code, world architecture, canon data tables (slug roster, elements, characters, caverns), and the model-benchmark harness. This is ~95% of the project's engineering.

**What this document deliberately does not cover: character and slug visual design.** No concept sheets, no model specs, no appearance descriptions for Burpy, Eli, Blakk or any canon character or slug. That is intentional and it is also how licensing actually works — the licensor controls character appearance and supplies an approved style guide, model sheets, and usually the assets themselves. Anything designed before that lands gets rejected and redone. The roster tables below therefore specify **name, element, mechanical effect, and gameplay role** — the parts you build systems against — and leave the art column pointing at the style guide.

The practical sequencing that follows from this is a feature, not a constraint: **systems now, art on delivery.** Greybox with primitives, keep every asset reference behind a `.tres` indirection, and dropping in approved models on the day they arrive is a config change rather than a refactor. §10 specifies that pipeline.

---

## 1. Concept

### 1.1 Pitch

You are Eli Shane, newly arrived in the underground world of Slugterra to take up your missing father's role as Protector. You roam the 99 Caverns, capture and bond with slugs, duel rival slingers, and fight Dr. Thaddeus Blakk's campaign to corrupt slugs into ghouls and seize control of the caverns' slug energy.

Open-world, third-person, traversal by Mecha Beast, combat entirely by blaster.

### 1.2 Design pillars

| Pillar | Meaning | Kills feature if it violates |
|---|---|---|
| **The blaster is the verb** | Traversal, combat, puzzles and social interaction all route through firing a slug. | Adding a melee weapon or a conventional gun |
| **Slugs are characters, not ammo** | Every slug is a bonded individual with experience, energy and mood that affect performance. Burpy is not a fire bullet. | Interchangeable infinite ammo |
| **100 mph or nothing** | The canon velocity threshold is the core skill gate. Under-speed shots fail. | Auto-charged shots, hitscan |
| **Verticality over area** | Caverns stack. Traversal is up/down as much as across. | A flat 4 km² field |
| **60 fps on a laptop** | Stylised, high-contrast, readable. Solo build on a student machine. | Photoreal PBR |

### 1.3 Canon mechanics the game is built on

These come straight from the show and are unusually well-suited to being systems — this is a rare licensed property where the fiction already specifies a game.

**The velocity rule.** A slug fired from a blaster transforms — becomes a **Velocimorph** — on reaching **100 mph**. Below that it does not transform and the shot is a dud. This is the game's central skill expression and drives the charge mechanic in §6.3.

**Slug energy and experience.** Slugs accumulate experience through velocity transformations. More experienced slugs produce more powerful shots, blasters are powered by slug energy, and experience is permanent — it does not decay with disuse. This is the progression system; it already exists in canon and needs no invention.

**Ghouls.** Blakk's dark science corrupts slugs into feral, mindless weapons. Ghouls are the enemy ammunition, they behave viciously and unpredictably, and **Boon Doc slugs can purify them back**. This gives you an antagonist arsenal, a moral stake, and a non-combat quest verb in one canon mechanic.

**The Five Elementals.** Air, Earth, Energy, Fire and Water — ancient slugs described as the ancestors of all Slugterra slugs. Endgame content and the top of the element hierarchy.

**Slug Fu.** Junjie's Eastern Caverns discipline: mental control of a slug after it is fired. This is your post-shot steering mechanic, unlocked mid-game, and it meaningfully changes the skill ceiling.

**Mecha Beasts.** Mechanical mounts, maintained by Kord. Open-world traversal.

**Blastersmithing.** Red Hook crafts the Shane family's weapons. Blaster upgrades and modding are a canon-sanctioned progression track.

---

## 2. Element system

Canon runs roughly 48 slug breeds across ~12 elements. Collapse to ten for a workable matchup matrix — five primes plus five secondaries:

**Primes:** Fire · Water · Earth · Air · Energy
**Secondaries:** Ice · Metal · Psychic · Shadow · Toxic

Matchup matrix is 10×10 floats in one `.tres`, values in `{0.5, 0.75, 1.0, 1.5, 2.0}`. Grounded in canon interactions where they exist (water douses fire; Xmitter/Metal disables blasters; Bubbaleone hard-counters Thresher; Shadow is the ghoul-aligned element and Energy — Boon Doc, Ping — counters it).

**Status effects:** `Burning, Soaked, Frozen, Webbed, Shocked, Blinded, Petrified, Magnetised, Hexed`.

**Cross-interactions** — where emergent play lives. Explicit rules table, never scattered `if`s:

| Combination | Result |
|---|---|
| Soaked + Energy | 2× damage, chains to 2 extra targets |
| Soaked + Ice | Instant Frozen, skips the usual build-up |
| Burning + Water | Both clear, spawns a steam cloud that blocks NPC vision cones |
| Webbed + Fire | Web burns away, brief AoE flare |
| Frozen + Earth impact | Shatter bonus, 2× damage |
| Magnetised + Metal | Homing shot, cannot miss |
| Petrified + any impact | Shatter, heavy damage, target cannot be healed |

---

## 3. Slug roster — v1 (12 slugs)

Twelve, not fifty. Enough for a real matchup matrix and a full ammo wheel; small enough that the art delivery is tractable. All canon, all mechanically distinct.

| Slug | Element | Velocimorph effect | Gameplay role |
|---|---|---|---|
| **Infurnus** (Burpy) | Fire | Breathes fire, flaming flight | Signature / primary offence |
| **Tazerling** (Joules) | Energy | Lightning bolt, chains through Soaked | Anti-armour, combo enabler |
| **Hop Rock** (Banger) | Earth | Explodes on impact | Burst AoE |
| **Frostcrawler** (Chiller) | Ice | Freezes targets, creates ice walls and platforms | Control + traversal |
| **Arachnet** | Earth | Web snare; strings usable for swinging/escape | Control + traversal |
| **Tormato** | Air | Air blast; full tornado when transformed | Crowd control, environmental |
| **Rammstone** | Earth | Punches and rams, heavy knockback | Melee-range burst, breaches |
| **Boon Doc** (Doc) | Energy | Heals; **purifies ghouled slugs** | Support, quest-critical |
| **Armashelt** | Earth | Rolls into a ball and bashes | Reliable mid-damage |
| **Aquabeek** | Water | Water blast; applies Soaked, douses Burning | Utility, combo setup |
| **Speedstinger** | Earth/Metal | Ricochets off surfaces to reach the target | Skill shot, around cover |
| **Negashade** | Energy/Psychic | Dark cloud, impairs vision | Stealth, breaks aggro |

**Post-v1 expansion** (data-only, no code): Flaringo, Lavalynx, Forgesmelter, Bubbaleone, Jellyish, MakoBreaker, Grenuke, Diggrix, Dirt Urchin, Geoshard, Sand Angler, Blastipede, Lariat, Vinedrill, Thresher, Slicksilver, Crystalyd, Hoverbug, Gazzer, Flatulorhinkus, Enigmo, Fandango, Phosphoro, Glowbyss, Neotox, Slyren, Ping, Hypnogriff, Frightgeist, Thugglet, Hexlet, Xmitter, Mimkey, Flopper, Polero, Pieper.

### 3.1 Ghoul counterparts (enemy ammunition)

Ghouls are not reskins — they are a parallel roster with their own effects, used by Blakk's forces. Each is mechanically nastier and behaves erratically.

| Ghoul | Base slug | Effect |
|---|---|---|
| **Darkfurnus** | Infurnus | Green fire, burns through Frozen |
| **Amperling** | Tazerling | Dark lightning, no Soaked requirement to chain |
| **Hop Jack** | Hop Rock | Larger blast radius, delayed fuse |
| **Frostfang** | Frostcrawler | Freezes and creates ice walls that block the player |
| **Attacknet** | Arachnet | Web that *reflects* incoming slugs |
| **Tempesto** | Tormato | Dark tornado, pulls the player toward hazards |
| **Grimmstone** | Rammstone | Ram attack, unblockable |
| **Goon Doc** | Boon Doc | **Ghouls the player's slugs on hit** — the game's scariest enemy |
| **Harmashelt** | Armashelt | Rolling bash, tracks the player |
| **Aquafreak** | Aquabeek | Water beam that suppresses the player's blaster |
| **Slashstriker** | Speedstinger | Ricochets, strips the player's luck/crit |
| **Negablade** | Negashade | Dark fog, total vision blackout |

**Goon Doc is the design centrepiece of the ghoul system.** A hit that corrupts one of your bonded slugs — which you then have to purify with Boon Doc or lose — turns every encounter with one into a real threat, and it makes Boon Doc mandatory rather than a nice-to-have.

---

## 4. World

### 4.1 Structure

The 99 Caverns, grouped into regions: **Western, Eastern, Northern, Southern**, plus the **Deep Caverns** below them all.

**v1 (M1) is Quiet Lawn Cavern only.** One cavern, ~1 km², with the Shane Hideout as the hub. Ship that before touching anything else.

| Cavern | Region | Role | Milestone |
|---|---|---|---|
| **Quiet Lawn Cavern** | Western | Starting cavern, Shane Hideout, tutorial slinging | M1 |
| **Chillbore Cavern** | Western | Ice biome, Frostcrawler nesting grounds | M3 |
| **Scrapheap Cavern** | Western | Boss Ember's Scrap Force, salvage economy, blaster parts | M3 |
| **Slagrock Cavern** | Southern | Viggo Dare's territory, volcanic, vertical chimneys | M3 |
| **Bandoleer Cavern** | Western | Duel circuit, tournament arena | M3 |
| **The Eastern Caverns** | Eastern | Junjie, Slug Fu training, distinct architecture | M4 |
| **Cavern of Time** | — | Inescapable maze, puzzle dungeon | M4 |
| **Deep Caverns** | Deep | Blakk's operations, Dark Bane, endgame | M4 |

Named landmarks: **The Shane Hideout** (player home, slug habitat, Kord's garage, fast-travel anchor), **Blakk Industries** (fortress, endgame raid), **Red Hook's forge** (blaster crafting), **the Molenoid Kingdom** (Pronto's people).

### 4.2 The hybrid build model

Three layers, authored in this order:

**Layer 1 — Cavern graph (hand-authored, never procedural).**
A `.tres` region graph: each node is a cavern with world-space AABB, region grouping, biome profile, and tunnel connections. ~30 nodes at full scope, 1 for M1, 8 by M3. Procedural macro layout is why so many open worlds feel like nothing — the 99 Caverns are a *place*, and places are authored.

**Layer 2 — Terrain (procedurally generated, baked, then hand-sculpted).**
Generate heightmaps per cavern with layered noise in an editor tool, bake into Terrain3D region files, then hand-sculpt what matters. Procgen is an authoring accelerator, **not a runtime system.** You never generate terrain at runtime.

```gdscript
# tools/generate_cavern.gd — EditorScript. Editor-time only.
@tool
extends EditorScript

func _run() -> void:
    var profile: BiomeProfile = load("res://data/biomes/quiet_lawn.tres")
    var noise := FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = profile.base_frequency
    noise.fractal_octaves = 5
    # domain warp → cavern walls; ridged noise → stalagmite fields;
    # erosion pass; then write heights into Terrain3D storage and save.
```

**Layer 3 — Set pieces and scatter.**
Hideouts, settlements, arenas, Blakk outposts, slug nesting grounds: hand-built `.tscn` at authored transforms. Vegetation, rocks, crystals, debris: rule-based scatter via Terrain3D foliage instancing, seeded per-cavern so it's deterministic and never needs saving.

### 4.3 Streaming

```
WorldStreamer (autoload)
  ├── samples player position at ~4 Hz (not every frame)
  ├── computes active chunk set from a 3×3 grid around the player
  ├── LOADS entering chunks via WorkerThreadPool + ResourceLoader.load_threaded_request
  ├── UNLOADS exiting chunks after ~5 s hysteresis (prevents border thrash)
  └── emits chunk_loaded / chunk_unloading on EventBus
```

Chunk size **256 m**. Terrain3D manages its own terrain LOD independently — your streamer manages *scene content*: buildings, NPCs, props, navmeshes.

Three content tiers by radius:
- **r=0** (player chunk + 8 neighbours): full detail, physics on, NPCs simulated
- **r=2**: visual only, no physics, NPCs frozen to proxy state
- **r=3+**: impostors, or nothing when occluded by cavern walls

**Verticality.** Caverns stack, which breaks a flat 2D chunk grid. Chunks are **columns** — 256×256 m footprint spanning full cavern height, subdivided into 2–4 vertical **decks** that load independently. On a Slagrock chimney floor you need the upper deck's geometry for silhouette but not its NPCs.

**Floating origin.** Godot 3D uses 32-bit floats; past ~4 km from origin you get visible jitter in physics and shadows. Build `OriginShifter` in M1 — when the player passes 2 km, translate the world root back and emit `origin_shifted(offset: Vector3)` for every system caching world positions. Retrofitting this after 40 systems cache positions is brutal. **Do it early.**

### 4.4 Navigation

Bake `NavigationRegion3D` per chunk, **offline**, stored as separate resources loaded with the chunk. Never bake at runtime. Godot 4's `NavigationServer3D` stitches adjacent regions via edge-connection margins if chunk bounds stay consistent.

Three navmesh layers: **ground** (walking NPCs, agent radius 0.5 m), **flight** (airborne Velocimorphs, sparser, higher clearance), **mecha** (wider agent radius, gentler slope limit, for mounted traversal and Mecha Beast NPCs).

---

## 5. Characters and NPCs

### 5.1 Canon roster

**Playable / Shane Gang**

| Character | Species | Role | Signature |
|---|---|---|---|
| **Eli Shane** | Human | Player character, Protector of Slugterra | Burpy (Infurnus) |
| **Kord Zane** | Cave troll | Mechanic — blaster and Mecha Beast upgrades | Strong slinger, Rammstone-type |
| **Trixie Sting** | Human | Slug expert, documentarian — bestiary and slug-locating quests | Tracking/utility slugs |
| **Pronto Geronimole** | Molenoid | Tracker — pathfinding and treasure quests | Slugsniper rifle |
| **Junjie** | Human | Eastern Caverns hero — teaches Slug Fu | Joo-Joo (Infurnus) |

Companions are **AI-controlled followers** in the field, each with an ability the player calls: Kord repairs and breaches, Trixie tags and analyses enemy slugs, Pronto reveals hidden paths and caches. Follower slot count is 1 at M1, 2 by M3.

**Allies**

| Character | Role |
|---|---|
| **Will Shane** | Eli's missing father, prior owner of Burpy — main-quest driver |
| **Shanai** | Legendary Shane-lineage trainer; combo tutor (Negashade + Ping) |
| **Red Hook** | Blastersmith — crafting and upgrade vendor |
| **Dana Por** | Ally slinger; Shadow Walker device, Arachnet specialist, wrist blasters |

**Antagonists**

| Character | Faction | Role |
|---|---|---|
| **Dr. Thaddeus Blakk** | Blakk Industries | Primary antagonist; Harbinger Firestorm blaster; runs the ghouling operation |
| **Tad Blakk** | Blakk Industries | His son; befriends then betrays — mid-game arc |
| **Twist** | Blakk Industries | Former ally turned traitor; Loki ghoul |
| **El Diablos Nacho** | Blakk / Dark Bane | Enforcer, secretly Dark Bane |
| **Brimstone** | Dark Bane | Dark Bane leader; endgame boss |
| **Locke and Lode** | Freelance | Twin slingers — recurring paired mini-boss |
| **Sedo** | Blakk Industries | Molenoid, Pronto's nemesis |
| **John Bull** | Duel circuit | Tournament champion; Tempesto ghoul |
| **Viggo Dare** | Slagrock Cavern | Territorial ruler; regional boss |
| **Quentin** | Independent | Mad scientist; pilots the Titan battle tank — vehicle boss |
| **Mr. Saturday** | Independent | Cryptogriff mind control — stealth/horror mission |
| **Boss Ember** | Scrap Force | Octoad, rules Scrapheap Cavern |
| **Shock Wire** | Freelance | Tazerling user — tutorial duel opponent |

**Neutral factions:** the **Shadow Clan** (maintain slug-energy balance — a faction whose reputation gates endgame content), the **Molenoid Kingdom**, the **Hooligang** (low-tier nuisance enemies).

### 5.2 Three NPC tiers

Don't build one NPC class. Build three, with a promotion path:

| Tier | Count | Simulation | Examples |
|---|---|---|---|
| **Ambient** | ~200 | Animation + waypoint loop, no BT, no perception | Cavern townsfolk, molenoids |
| **Interactive** | ~40 | Full LimboAI tree, perception, dialogue, schedule | Vendors, rival slingers, Hooligang |
| **Director** | ~15 | Interactive + persistent world-state effects | Shane Gang, Blakk, named bosses |

Ambient promote to Interactive when the player looks at them within 8 m and they have dialogue. **This tiering is the single largest perf lever in the project** — 200 behavior trees ticking will consume the entire frame budget.

### 5.3 Behavior tree (LimboAI)

Priority selector per Interactive NPC:

```
Selector (root)
├── Sequence [Flee]         ← guard: hp < 25% AND cowardice > threshold
├── Sequence [Duel]         ← guard: has_hostile_target
│   └── Selector
│       ├── Retreat & heal        (hp low, has Boon Doc or consumable)
│       ├── Counter-pick slug     (query matchup matrix vs player's recent elements)
│       ├── Reposition to cover   (nav query to nearest cover point)
│       └── Charge & sling        (charge above 100 mph, lead target, fire)
├── Sequence [Investigate]  ← guard: heard_sound OR saw_something
├── Sequence [Schedule]     ← follow DailySchedule for current WorldClock hour
└── Idle / wander
```

**Blackboard keys:** `target`, `last_known_target_pos`, `home_pos`, `threat_level`, `player_recent_elements[]`, `own_slug_belt[]`, `current_schedule_task`.

The **counter-pick node** is the highest intelligence-per-line-of-code in the whole project. An NPC that notices you lean on Burpy and swaps to a water slug reads as genuinely smart. Give Blakk's lieutenants a longer `player_recent_elements` memory window than trash mobs — that alone makes boss fights feel different without any special-case AI.

### 5.4 Perception

One `Area3D` for hearing radius; vision on a **staggered round-robin timer**, ~5 Hz per NPC, never all NPCs on the same frame. Order the checks cheap-to-expensive: cone test → distance → raycast.

Negashade's `Blinded` status multiplies effective cone angle by 0.2 and range by 0.4. That is the stealth system, and it comes free from the slug roster.

### 5.5 Schedules and dialogue

`DailySchedule` resource: array of `(hour, location_id, activity)`. `WorldClock` autoload drives day/night — suggest 24 real minutes = 24 game hours. Caverns have no sun, so "day/night" is bioluminescence cycling and settlement activity, which is both cheaper to render and more distinctive.

When an NPC's chunk unloads, don't simulate — on reload, snap them to where the schedule says they should be. Nobody will notice; it costs nothing.

**Dialogue:** write your own. A `.tres` graph of nodes with `text`, `speaker`, `conditions[]`, `effects[]`, `responses[]`. Conditions query `GameState` (quest flags, faction rep, slugs owned, items). Do not pull in a large dialogue addon at M1 — integration cost exceeds write cost at this scale, and a custom one stays LLM-authorable, which matters for §12.

---

## 6. Player systems

### 6.1 Controller

`CharacterBody3D`, not `RigidBody3D` — deterministic and tunable.

States: `Idle, Walk, Run, Jump, Fall, Climb, Slide, Aim, Fire, Mounted, Staggered, Ghouled`.

Build a `MovementProvider` interface from day one so Mecha Beast riding swaps the provider rather than adding branches to a 900-line `_physics_process`. Mounted movement is canon-central; retrofitting it is expensive.

### 6.2 Camera

`SpringArm3D` third-person, over-shoulder on aim. Three profiles as `.tres` — `explore`, `aim`, `duel` — tween-blended. Add **soft occlusion fade** on top of SpringArm's raycast collapse: hard collapse in tight cavern tunnels is nauseating, and this game is all tunnels.

### 6.3 The blaster — the core interaction

Get this right and the game works with grey capsules. Get it wrong and no amount of world saves it.

```
INPUT: hold fire → charge 0.0 → 1.0 over 0.6 s (curve, not linear)
       release   → muzzle velocity = lerp(min_v, max_v, curve.sample(charge))

min_v = 20 m/s  ( 45 mph) — WELL BELOW threshold; shot is a dud
max_v = 62 m/s  (139 mph) — comfortably above

VELOCITY_THRESHOLD = 44.7 m/s (100 mph — canon)
```

The **failure band is the design**. A panic shot fizzles. It's the skill gate, the tension source, and the reason the charge meter is worth watching. Render the 100 mph threshold as a hard marked notch on the charge UI — the player must always know which side of it they're on.

Blaster upgrades (Red Hook, Kord) move these numbers: faster charge curve, higher `max_v`, a wider "perfect release" window near max that grants a damage bonus. That gives blastersmithing real mechanical weight rather than cosmetic tiers.

**Projectile:** custom kinematic integration, **not** `RigidBody3D`. You need frame-exact control of the velocity check, ricochet counts (Speedstinger), Slug Fu steering, and homing return. Integrate manually and raycast between last and current position each tick — this also prevents tunnelling at 62 m/s.

**Slug Fu** (unlocked mid-game via Junjie): holding aim after release grants limited post-fire steering — a steering-force budget consumed over ~1.2 s, with turn authority scaling on the slug's experience level. Raises the skill ceiling substantially and justifies an entire Eastern Caverns act.

**Ammo wheel:** radial selector, time to 0.25× while open. Belt of **6 equipped slugs** chosen at the Hideout or at rest points; full collection in a separate menu. Constraining the loadout is a design win — it forces real decisions and keeps the wheel readable.

---

## 7. Slug system

### 7.1 Data-driven definition

```gdscript
# src/slug/slug_data.gd
class_name SlugData extends Resource

@export var id: StringName                        # &"infurnus"
@export var display_name: String                  # "Infurnus"
@export var element: Element                      # Element resource
@export var rarity: Rarity
@export_range(0.5, 2.0) var mass_factor: float    # affects ballistic arc
@export var velocity_threshold: float = 44.7      # canon 100 mph; per-slug variance allowed
@export var velocimorph_duration: float = 4.0
@export var cooldown: float = 6.0
@export var dormant_scene: PackedScene            # ← licensor asset, greybox placeholder until then
@export var velocimorph_scene: PackedScene        # ← licensor asset
@export var effect_script: Script                 # extends VelocimorphEffect
@export var base_power: float
@export var accuracy_cone_deg: float = 1.5
@export var ghoul_counterpart: SlugData           # null if none
@export var can_be_ghouled: bool = true
```

Adding a slug = one `.tres` + one effect script + two mesh references. Zero system code. This is what makes the post-v1 roster a content task, and it's also the cleanest possible LLM benchmark unit (§12).

### 7.2 Projectile lifecycle

```
DORMANT_FLIGHT ──(speed ≥ 44.7 m/s)──> TRANSFORMING (0.25 s anim, 60 ms hitstop)
     │                                        │
     │(impact while under threshold)          ▼
     ▼                                  VELOCIMORPH (effect_script runs, duration)
   DUD (bounces, lies dormant 1.5 s,           │
        auto-recall, NO cooldown penalty)      ▼
                                          REVERTING (shrink anim)
                                                │
                                                ▼
                                        RETURNING (homes to belt ~1.2 s,
                                                   then cooldown begins)
                                                │
                                                ▼
                                        +EXPERIENCE (only on successful transform)
```

**Recall-on-dud without cooldown penalty is deliberate.** Punish the miss with lost tempo, not lost resource. Resource punishment makes players hoard their slugs and never use the mechanic the whole game is built on.

**Experience only accrues on successful transformation** — canon, and it neatly makes the skill gate double as the progression gate.

### 7.3 Slug energy, experience, bonding

Canon gives you the progression system; this is the implementation.

Per owned slug instance, runtime state:

| Stat | Range | Effect |
|---|---|---|
| `experience` | 0 → ∞ | Permanent, never decays (canon). Drives power tiers at thresholds. |
| `energy` | 0–100 | Consumed per shot, regenerates at rest. Powers the blaster. |
| `trust` | 0–100 | Low trust widens `accuracy_cone_deg` up to 3× and adds a 10% failure-to-transform chance |
| `fatigue` | 0–100 | Repeated firing without rest → longer cooldowns, weaker effect scaling |
| `is_ghouled` | bool | Set by Goon Doc hits; unusable until purified by Boon Doc |

Trust rises through rest at the Hideout habitat, feeding, and winning duels with that slug. Keep it **legible** — small mood icon per belt slot. If a player can't tell why a shot missed, depth reads as jank.

### 7.4 Capture

Wild slugs spawn at nesting grounds per cavern, weighted by biome (Frostcrawlers in Chillbore, Lavalynx in Slagrock). Capture is a mini-encounter: approach without spooking (they flee on noise/sight — reuse the NPC perception component), then a timed non-damaging capture shot. Rarer slugs have tighter timing windows and faster flee triggers.

---

## 8. Combat, quests, saving

**Combat.** A damage packet struct — `source`, `element`, `base_power`, `experience_tier`, `status_to_apply`, `impact_point` — resolved by one `CombatResolver` autoload. One code path for player→NPC, NPC→player, NPC→NPC.

**Duels.** `DuelController` fences an arena, runs rounds, enforces slinger etiquette rules, and reports to faction reputation. Tournament brackets at Bandoleer Cavern (John Bull's circuit) reuse the same controller with a bracket wrapper.

**Quests.** `QuestData` with `stages[]`, each stage carrying `objectives[]` — `duel`, `capture_slug`, `purify_ghoul`, `reach`, `talk`, `collect`, `escort`, `defend` — plus `completion_effects[]`. `QuestTracker` autoload subscribes to `EventBus` and evaluates reactively. **Never poll quest state.**

**Faction reputation.** Independent scalars for Shane Gang, Shadow Clan, Molenoid Kingdom, Scrap Force, Blakk Industries. Reputation gates vendors, dialogue branches and endgame access.

**Save.** Dictionary → `FileAccess` + `var_to_bytes`. **Version the format from save #1.** Persist: player transform + cavern, owned slugs with full per-instance state (experience, energy, trust, fatigue, ghouled), belt loadout, blaster upgrades, quest states, faction reps, world flags, and chunk-level deltas (looted containers, destroyed props, captured nests, purified ghouls) as a sparse dict keyed by chunk coord. Do **not** save terrain or static scene content. The sparse-delta design is the part people get wrong and then cannot fix without breaking every existing save.

---

## 9. Tech stack

Verified current as of September 2026.

| Layer | Choice | Version | License | Why |
|---|---|---|---|---|
| Engine | **Godot** | 4.6.3-stable | MIT | Text-based `.tscn`/`.tres` — an LLM can author the whole project as files. This is what makes §12 viable at all. |
| Language | **GDScript**, C# for hot paths | — | — | GDScript for gameplay. Drop to C# only where the profiler demands it. Don't start in C#. |
| Terrain | **Terrain3D** (TokisanGames) | 1.x | MIT | GDExtension/C++. Up to 10 LOD levels, 64 m → 65.5 km worlds, sculpting, holes, texture painting, foliage instancing with LOD + shadow impostors, 32 textures. Callable from GDScript. |
| NPC AI | **LimboAI** | 1.8.x (Godot 4.6+) | MIT | Behavior trees + HSMs with blackboard and a visual debugger. Ships as both C++ module and GDExtension, switchable without breaking the project. Start with GDExtension. |
| Testing | **gdUnit4** | current | MIT | Headless CI runs, GDScript + C#, maintained GitHub Action. Non-negotiable given §12. |
| VCS | Git + **Git LFS** | — | — | LFS for `.glb`/`.png`/terrain `.res` from commit one. Licensor art will be large. Retrofitting LFS is miserable. |
| DCC | **Blender** 4.x | — | GPL | Retopo, rigging, retargeting licensor assets. `.blend` imports natively. |

**Addon discipline: three, and that's it.** Terrain3D and LimboAI each save roughly a month. Everything else you write, because every addon is something you'll be debugging at 2 a.m. Vendor them into `addons/` at pinned versions rather than depending on the asset library.

---

## 10. Project structure

```
slugterra/
├── project.godot
├── addons/                   # Terrain3D, LimboAI, gdUnit4 — pinned, never hand-edited
├── src/
│   ├── autoload/             # GameState, EventBus, SaveManager, WorldClock, CombatResolver, AudioDirector
│   ├── player/               # controller, camera rig, blaster, ammo wheel, slug_fu
│   ├── slug/
│   │   ├── slug_data.gd
│   │   ├── slug_instance.gd          # runtime state: xp, energy, trust, fatigue, ghouled
│   │   ├── slug_projectile.gd        # dormant flight + velocity check
│   │   ├── velocimorph.gd
│   │   └── effects/                  # one script per slug effect
│   ├── npc/
│   │   ├── npc_base.gd
│   │   ├── perception.gd
│   │   ├── trees/                    # LimboAI .tres behavior trees
│   │   └── schedules/
│   ├── world/
│   │   ├── world_streamer.gd
│   │   ├── cavern.gd
│   │   ├── procgen/
│   │   └── origin_shifter.gd
│   ├── combat/               # damage, elements, statuses, duel_controller, ghouling
│   ├── quest/
│   └── ui/
├── data/                     # .tres — the game's actual content
│   ├── slugs/                # 12 SlugData + ghoul counterparts
│   ├── elements/             # 10×10 matchup matrix, status rules table
│   ├── characters/
│   ├── caverns/              # cavern graph, biome profiles
│   └── quests/
├── assets/
│   ├── licensed/             # ← WildBrain-supplied, LFS, quarantined
│   └── placeholder/          # ← CC0 + primitives for greyboxing
├── scenes/
│   ├── caverns/              # handcrafted .tscn
│   └── prefabs/
├── tests/                    # gdUnit4
└── tools/                    # editor scripts, validators, build scripts
```

**The `data/` vs `src/` split is the most important structural decision in this document.** Content in `.tres`, systems in `.gd`. Consequences: adding slug #13 is a data file; an LLM can add content without touching systems; and `tools/validate_data.gd` can walk `data/` and catch every broken reference before runtime. Do this from commit one.

**`assets/licensed/` is quarantined on purpose.** Every reference to it goes through a `.tres` indirection, never a hardcoded path. That way the greybox build runs with zero licensed assets present, and the licensed build is a folder drop. It also means your public repo and your benchmark harness can exclude that folder entirely.

---

## 11. Asset pipeline

**Characters and slugs: licensor-supplied.** Model sheets, style guide and approved assets come from WildBrain. Your job is the technical side of intake:

```
1. RECEIVE    Licensor assets (likely FBX/OBJ/Maya, show-production topology)
2. AUDIT      Tri count, bone count, material slots, scale, up-axis, naming
3. REDUCE     Blender decimate/retopo to game budget:
              slug dormant 1.5–4k tris · velocimorph 8–15k · humanoid 15–25k
4. RETARGET   Show rigs are animation rigs, not game rigs. Retarget to a
              standard humanoid skeleton (Rigify-compatible) for NPCs;
              simple 6–12 bone custom rigs for slugs
5. ANIM       Dormant: idle, hop, alert, fire-spin. Velocimorph: emerge, act, revert
6. EXPORT     .blend → res://assets/licensed/ (Godot imports natively).
              Set import presets once per folder via .import overrides
7. VALIDATE   tools/validate_assets.gd — tri/bone counts, missing materials,
              non-power-of-two textures. Runs in CI.
```

**Greybox now, don't wait.** M0 and M1 run entirely on primitives and CC0 stand-ins, so a slow license negotiation costs you zero development time:

- **Kenney** (CC0) — stylised placeholder props and characters
- **Quaternius** (CC0) — low-poly nature and rigged characters
- **Poly Haven** (CC0) — HDRIs (use these; skip the PBR textures, wrong look)

Slugs greybox as coloured spheres with a scale-up on transform. That is genuinely enough to test whether the 100 mph mechanic is fun.

**Environments are yours to build** — caverns, rock formations, settlements, props are original geometry in the show's world, not protected character designs. AI 3D generation (Meshy, Tripo, Hyper3D) is legitimately useful here at volume: crystals, rocks, mushrooms, crates, machinery, ruins. It's weakest exactly where characters live, which is fine, because characters aren't your problem on this project.

**Style target:** flat-shaded, high-contrast, strong rim lighting, emissive accents. Bioluminescent caverns are extremely forgiving of low-poly geometry, and emissives read as polish for almost no cost. This also happens to sit close to the show's own look, which will help at licensor approval.

---

## 12. Performance budget

Target **60 fps at 1080p on a mid-range laptop**. Your dev machine is the min spec — that's a feature, it keeps you honest.

| Budget | Target |
|---|---|
| Frame time | 16.6 ms: ≤6 ms CPU game logic, ≤8 ms render, 2.6 ms headroom |
| Draw calls | < 1,200 |
| Visible tris | < 1.5 M |
| Active `_process` / `_physics_process` nodes | < 400 |
| Behavior trees ticking | < 25 |
| Terrain LOD levels | Cap at 6, not Terrain3D's max 10 |
| Dynamic (non-baked) lights in view | < 8 |

**Optimisation order — do not skip to step 4:**
1. **Don't simulate what isn't near the player** (NPC tiers, chunk radii) — wins by an order of magnitude over everything below
2. **MultiMesh everything repeated** (foliage, crystals, rocks, debris, crowd props)
3. **Bake lighting** in settlements; dynamic lights only where gameplay needs them
4. Only then micro-optimise scripts, profiler open

The cavern setting is a gift: enclosed geometry means occlusion culling actually works. Hand-place `OccluderInstance3D` at every tunnel mouth.

---

## 13. Benchmark protocol — Fable 5.1 vs GPT-6

The half of the project serving your stated goal. "Which game felt better" is worthless; this is the harness that produces a real result.

### 13.1 Why this project benchmarks well

- **Long-horizon** — tasks needing 5+ files of held context, not snippet completion
- **Text-native** — Godot projects are entirely text, so both models produce complete verifiable output
- **Objectively testable** — headless gdUnit4 gives pass/fail, not opinion
- **Compounding** — later tasks build on earlier ones, exposing architectural quality that single-shot benchmarks miss

### 13.2 Method

Fix everything except the model:

1. **Shared baseline.** You build M0 by hand. Both models start from an identical commit.
2. **Sealed task specs**, written before any model runs. No adapting a spec after seeing a failure.
3. **Sealed tests.** gdUnit4 suites written in advance, never shown to the models. Tests are ground truth.
4. **Identical harness** — same tools, system prompt, file context, turn budget (40/task). Log everything.
5. **Blind grading.** Strip identifying markers; grade later, or have someone else grade.
6. **N ≥ 3 runs per task per model.** Single runs are noise. This is the step everyone skips and the one that makes the result publishable.
7. **Exclude `assets/licensed/`** from the benchmark repo entirely — it's irrelevant to code tasks and keeps the harness shareable.

### 13.3 Task ladder

| # | Task | Difficulty | Tests |
|---|---|---|---|
| 1 | Add Flaringo as slug #13 given the `SlugData` pattern | Trivial | Pattern following |
| 2 | Implement the 7-rule status cross-interaction table | Easy | Spec adherence, completeness |
| 3 | Write `OriginShifter` + retrofit 6 systems to handle `origin_shifted` | Medium | Cross-file reasoning, finding all call sites |
| 4 | Chunk streaming: threaded load, hysteresis unload, 3 content tiers | Medium-hard | Concurrency, resource lifecycle |
| 5 | Build the duel behavior tree in LimboAI incl. element counter-picking | Hard | Third-party API use, game-feel judgement |
| 6 | Save/load: versioned format + sparse chunk deltas | Hard | Serialisation design, edge cases |
| 7 | Implement the ghouling system — Goon Doc corrupts a belt slug, Boon Doc purifies | Hard | Multi-system state, save interaction |
| 8 | Profile a deliberately broken build; fix 3 planted perf bugs | Hard | Diagnosis under ambiguity |
| 9 | Given only §4 of this doc, design and implement the cavern graph system | Very hard | Open-ended architecture |

### 13.4 Rubric (100 pts/task)

| Dimension | Pts | Measured by |
|---|---|---|
| Tests pass | 30 | Automated (gdUnit4 headless) |
| Runs without error | 15 | Automated (`godot --headless` boot + smoke scene) |
| Meets written spec | 15 | Manual checklist, blind |
| Architectural fit | 15 | Blind review — matches existing patterns or fights them? |
| No regressions | 10 | Full pre-existing suite |
| Perf budget respected | 10 | Automated profiler assertions |
| Turns / tokens used | 5 | Logged, normalised |

Track qualitatively alongside: **hallucinated Godot 4 APIs** (models emit Godot 3 syntax constantly — this is the single most common failure and worth counting), whether the model **ran its own tests** before declaring done, and whether it **asked clarifying questions** on deliberately underspecified task 9.

### 13.5 CI

GitHub Actions on every push: `godot --headless --import`, gdUnit4 via the maintained action, then a smoke test booting the M1 scene, simulating 600 frames, asserting no errors and frame time within budget. That automates 55 of the 100 points on every model run.

**Publish this.** You already have IEEE and IJSRCSEIT publications. A rigorous long-horizon LLM-agent-on-game-development benchmark with N≥3 and blind grading is genuinely underserved, and it's a stronger MS application artifact than a half-finished game — which is a real risk on a project this size. Design §13 for a paper from the start. Note the benchmark stands on its own regardless of how the license negotiation goes: the tasks are all systems code, none of it touches licensed art.

---

## 14. Milestones

| Milestone | Content | Target |
|---|---|---|
| **M0 — Greybox loop** | Controller, camera, charge-and-fire blaster with the 100 mph band, Burpy (sphere), 1 dummy target, 200 m flat plane | 2 weeks |
| **M1 — Vertical slice** | Quiet Lawn Cavern, 1 km² terrain, Shane Hideout, 4 slugs, 3 NPC archetypes, 1 duel (Shock Wire), capture, save/load, floating origin | 6–8 weeks |
| **M2 — Systems complete** | All 12 slugs + 12 ghouls, ghouling/purification, quests, faction rep, slug bonding, blaster upgrades, full matchup matrix | +8 weeks |
| **M3 — World** | Chillbore, Scrapheap, Slagrock, Bandoleer; streaming between caverns; Mecha Beast traversal; ~25 POIs; 40 NPCs; tournament | +12 weeks |
| **M4 — Ship** | Eastern Caverns + Slug Fu, Deep Caverns, Cavern of Time, main quest, Blakk and Brimstone, audio, optimisation | +12 weeks |

**M1 is the real target.** Internship plus final year plus this is a lot. A polished Quiet Lawn vertical slice is a portfolio piece, a licensor demo, and a benchmark baseline all at once. M2+ is the "this is working, keep going" phase. Projects die at M1½ far more often than at M4.

---

## 15. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Scope death — open world is the solo-dev graveyard | **High** | M1 is the goal. Ship one cavern before touching M2. |
| License doesn't close, or closes with restrictions | Medium | `assets/licensed/` quarantine + `.tres` indirection means the greybox build is fully playable without it. Systems, benchmark and portfolio value survive intact either way. |
| Licensor asset intake is harder than expected (production topology, non-game rigs) | Medium | Budget real Blender retarget time. Audit the first delivery immediately, don't assume it's game-ready. |
| Time — internship + final year + this | **High** | 8 focused hours/week beats 30 sporadic. Burn-down against M1. |
| Floating-origin retrofit | Medium | Build it in M1. Cheap early, brutal later. |
| Terrain3D / LimboAI breaking changes | Medium | Pin versions, vendor into `addons/`. |
| Benchmark contaminated by scaffolding drift | Medium | Freeze the baseline commit and all task specs before any model runs. Version-control the harness itself. |

---

## 16. Immediate next steps

1. Install Godot 4.6.3; vendor Terrain3D, LimboAI, gdUnit4 into `addons/` at pinned versions
2. Create the §10 skeleton exactly, Git LFS configured, `assets/licensed/` gitignored
3. Build M0: `CharacterBody3D` + SpringArm camera + charge-and-fire blaster with the 100 mph threshold + Burpy as a coloured sphere that scales up on transform + one dummy target. Flat 200 m plane. No terrain, no art.
4. **Play M0 for an hour.** If the charge-and-dud loop isn't fun with a grey capsule firing a red sphere, nothing downstream fixes it. Cheapest possible test of the entire premise.
5. Freeze M0 as the benchmark baseline commit; write the sealed task specs and test suites.

---

## Sources

**Canon reference**
- [Slugterra — Wikipedia](https://en.wikipedia.org/wiki/Slugterra) · [Slugterra: Return of the Elementals](https://en.wikipedia.org/wiki/Slugterra:_Return_of_the_Elementals)
- [Slugs — SlugTerra Wiki](https://slugterra.fandom.com/wiki/Slugs) · [Elemental Slugs](https://slugterra.fandom.com/wiki/Elemental_Slugs) · [List of Slugterra slugs](https://en.everybodywiki.com/List_of_Slugterra_slugs)
- [List of Slugterra characters](https://wikimili.com/en/List_of_Slugterra_characters) · [Characters in Slugterra — TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/Characters/Slugterra)
- [The 99 Caverns](https://slugterra.fandom.com/wiki/The_99_Caverns) · [Quiet Lawn Cavern](https://slugterra.fandom.com/wiki/Quiet_Lawn_Cavern) · [Chillbore Cavern](https://slugterra.fandom.com/wiki/Chillbore_Cavern) · [The Eastern Caverns](https://slugterra.fandom.com/wiki/The_Eastern_Caverns)
- [DHX Media to acquire Nerd Corps — WildBrain](https://www.wildbrain.com/trade-news/dhx-media-to-acquire-nerd-corps)

**Technical**
- [Godot 4.6.3-stable](https://github.com/godotengine/godot/releases/tag/4.6.3-stable) · [Godot release blog](https://godotengine.org/blog/release/)
- [Terrain3D](https://github.com/TokisanGames/Terrain3D) · [Terrain3D docs](https://terrain3d.readthedocs.io/en/stable/api/class_terrain3d.html)
- [LimboAI](https://github.com/limbonaut/limboai) · [LimboAI docs](https://limboai.readthedocs.io/)
- [gdUnit4 GitHub Action](https://github.com/godot-gdunit-labs/gdUnit4-action) · [GUT + GitHub Actions CI](https://helpmetest.com/blog/godot-ci-cd-testing/)
- [Godot Open World Database (streaming reference)](https://github.com/DigitallyTailored/Godot-Open-World-Database) · [Open-world architecture in Godot](https://dredyson.com/how-i-built-a-witcher-3-inspired-open-world-architecture-in-godot-as-a-solo-saas-builder-a-complete-step-by-step-guide-to-open-world-data-streaming-chunk-loading-and-lean-development-witho/)
- [Free CC0 asset sources 2026](https://app.cinevva.com/guides/free-3d-model-sites) · [AI 3D tools for game assets](https://www.meshy.ai/blog/best-ai-tools-for-3d-game-assets)