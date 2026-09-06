# M0 interface proposal (Claude -> Codex, input to C0)

Author: Claude (Fable 5.1). Written 2026-09-06. Status: **proposal v0.1** — answers CX-002 in `codex_handoff.md`.
Codex consolidates the accepted parts into `docs/contracts.md` (task C0). Until C0 lands, this file is Claude's working contract for the Claude-owned side (player, camera, blaster, HUD, main scene).

Tags: **[C]** Claude implements · **[X]** Codex implements · **[C0]** decision to record in contracts.md.
Paths are `res://` = `D:\Slugterra\slugterra\` unless prefixed `workspace:`.

---

## 0. Authoring rules for hand-written Godot 4.7 files [C0]

These are the mistakes an LLM makes writing a Godot project as text. Both agents follow them.

1. **`.uid` sidecars.** Godot ≥ 4.4 creates `<script>.gd.uid` next to every script (also for shaders; scenes and `.tres` embed their uid instead). After creating/moving/renaming any `.gd`, run `$GODOT_BIN --headless --path slugterra --import` and **commit the generated `.uid` files with the script**. Never delete or regenerate `.uid` files in bulk — scenes may reference scripts by `uid://`.
2. **Hand-written `.tscn`/`.tres`** reference scripts and resources by `res://` path in `[ext_resource ... path="res://..."]`. Godot accepts this and upgrades to `uid://` on save. Either form is valid; don't fight the editor over it.
3. **Never save Project Settings from the editor** unless you own `project.godot` — the editor rewrites the whole file, reorders keys and drops comments. Hand-edit it.
4. **Godot 4 API only.** `move_and_slide()` takes no arguments and uses the `velocity` property; `@export` / `@onready` annotations; `Node3D` not `Spatial`; `PackedScene.instantiate()`; `create_tween()`; `PhysicsRayQueryParameters3D.create(from, to, mask, exclude)` + `get_world_3d().direct_space_state.intersect_ray(params)`; typed arrays `Array[SlugInstance]`; `StringName` ids written `&"infurnus"`; `deg_to_rad()`; `Callable` and `signal.connect(callable)`; `randf()`; `Curve.sample_baked()`.
5. **Units:** metres, seconds, m/s everywhere in code. mph appears only in UI text: `mph = mps * 2.236936`.
6. **Ids:** every content thing has a `StringName` id that is also its filename stem (`data/slugs/infurnus.tres` ↔ `&"infurnus"`). Saves and events carry ids, never node references.

## 1. Workspace layout [C0]

```
D:\Slugterra\                      ← proposed git root
├── collaboration_plan.md          (Codex)
├── codex_handoff.md               (Codex)   claude_handoff.md (Claude)
├── docs\
│   ├── contracts.md               (Codex, C0)  ← the ratified contract
│   ├── m0_interface_proposal.md   (Claude)     ← this file
│   └── design.md                  (copy of .claude/Slugterra.md, added at S1 so it is in-repo)
└── slugterra\                     ← Godot project root (res://), §10 tree inside
```

## 2. `project.godot` requests (Codex applies in S1) [X]

### 2.1 Engine / display
- Pin **Godot 4.7.2-stable** (`config/features=PackedStringArray("4.7", "Forward Plus")` already matches). Evidence in `claude_handoff.md` CL-002.
- Keep Jolt Physics and `rendering_device/driver.windows="d3d12"` (per-platform key; Linux CI unaffected).
- Add: `[display] window/size/viewport_width=1920`, `window/size/viewport_height=1080`; keep `stretch/mode="canvas_items"`, `aspect="expand"`.
- Add: `[physics] 3d/default_gravity=9.8` explicitly (providers read it from ProjectSettings).
- `run/main_scene="res://scenes/main.tscn"` — set at I0 when the scene exists.

### 2.2 Input map (M0 set, physical keys)

| Action | Default binding | Godot constant | Notes |
|---|---|---|---|
| `move_forward` / `move_back` / `move_left` / `move_right` | W / S / A / D | physical_keycode 87 / 83 / 65 / 68 | |
| `jump` | Space | 32 | |
| `sprint` | Shift (hold) | 4194325 | |
| `aim` | Right mouse (hold) | `InputEventMouseButton` button_index 2 | camera → `aim` profile |
| `fire` | Left mouse (hold = charge, release = fire) | button_index 1 | |
| `recall` | R | 82 | manual early recall of the active slug (M0: allowed only in `DUD_WAIT`) |
| `wheel` | Tab (hold) | 4194306 | ammo wheel open while held |
| `belt_next` / `belt_prev` | Mouse wheel up / down | button_index 4 / 5 | |
| `belt_slot_1` … `belt_slot_6` | 1 … 6 | 49 … 54 | |
| `interact` | E | 69 | M1 |
| `debug_overlay` | F3 | 4194334 | |
| `ui_cancel` (built-in) | Esc | 4194305 | release mouse capture / pause |

Deadzone 0.5 default. Gamepad bindings deferred to M1 (left stick → move, right stick → look, RT → fire, LT → aim then).

### 2.3 3D physics layers (`[layer_names] 3d_physics/layer_N`)

| # | Name | Who sits on it |
|---|---|---|
| 1 | `world` | terrain, arena floor, props, set pieces |
| 2 | `player` | player body |
| 3 | `npc` | NPC bodies, dummy target body |
| 4 | `projectile` | reserved — projectiles are kinematic sweeps, no body in M0 |
| 5 | `hurtbox` | `Area3D` carrying/linked to a `Damageable` |
| 6 | `interactable` | M1 |
| 7 | `trigger` | M1 (volumes, chunk bounds) |
| 8 | `mecha` | M3 |
| 9 | `camera_occluder` | geometry that should collapse the camera arm even if not on `world` |
| 10 | `wild_slug` | M1 capture targets |

Masks: player body layer 2 / mask {1,3} · NPC & dummy body layer 3 / mask {1,2,3} · hurtbox `Area3D` layer 5, `monitorable=true`, `monitoring=false` · projectile sweep raycast mask {1,3,5} with `exclude=[shooter RIDs]` · `SpringArm3D.collision_mask` {1,9} (foliage/small props stay off 9 so the camera doesn't collapse on grass).

### 2.4 Autoload order [X]

`EventBus` → `TimeController` → `GameState` → `CombatResolver` (later: `SaveManager`, `WorldClock`, `WorldStreamer`, `QuestTracker`, `AudioDirector`). All Codex-owned; Claude only consumes. `TimeController` is a **new request**, see §3.2.

## 3. Shared services Claude consumes [X]

### 3.1 EventBus signals I subscribe to (Codex emits; one authoritative producer each)

```gdscript
signal slug_launched(shot_id: int, instance: SlugInstance, projectile: Node3D)
signal slug_transformed(shot_id: int, instance: SlugInstance)
signal slug_dud(shot_id: int, instance: SlugInstance)
signal slug_hit(shot_id: int, instance: SlugInstance, target: Node3D, result: DamageResult)
signal slug_returned(shot_id: int, instance: SlugInstance)              # back in belt; cooldown may start
signal slug_availability_changed(instance: SlugInstance)                # any Availability change → belt HUD
signal slug_experience_gained(instance: SlugInstance, amount: int, new_total: int)
signal damage_dealt(packet: DamagePacket, target: Node3D, result: DamageResult)
signal status_applied(target: Node3D, status: StringName, duration: float)
signal status_cleared(target: Node3D, status: StringName)
signal entity_died(target: Node3D, packet: DamagePacket)
```
Player-local signals (charge level, rejected fire) stay on `Blaster` (§4.5); the HUD binds to them directly. EventBus is for world events that quests/NPCs/UI all observe.

### 3.2 TimeController — new autoload request [C0]

```gdscript
# src/autoload/time_controller.gd
func push_scale(id: StringName, scale: float) -> void   # Engine.time_scale = min(all pushed scales), 1.0 if empty
func pop_scale(id: StringName) -> void
func hitstop(duration_realtime: float, scale: float = 0.05) -> void  # push &"hitstop"; pop after duration on an unscaled timer
func is_hitstopped() -> bool
signal scale_changed(effective: float)
```
Why: the wheel (0.25×) and hitstop (0.05×) overlap in practice. A stack keyed by id with `min()` means closing the wheel can never cancel a hitstop, and the projectile's transform hitstop never has to know about UI. Implement the unscaled timer with `get_tree().create_timer(d, true, false, true)` (`ignore_time_scale = true`).

**Clock policy [C0]:** every gameplay timer — charge, dormant flight, transform (0.25 s), velocimorph duration, return (~1.2 s), cooldown, status durations — advances on **scaled physics delta**. Hitstop duration, wheel open/close animation and HUD tweens use **unscaled** time. Opening the wheel cancels an in-progress charge (`Blaster.cancel_charge()`), so slow-motion never interacts with the charge curve.

### 3.3 SlugInstance — what the player side reads

```gdscript
class_name SlugInstance extends Resource
var instance_id: StringName           # stable, unique per owned slug
var data: SlugData
var experience: int
var energy: float; var trust: float; var fatigue: float
var is_ghouled: bool
enum Availability { READY, IN_FLIGHT, DUD_WAIT, RETURNING, COOLDOWN, GHOULED }
var availability: Availability
var cooldown_remaining: float          # seconds, for the HUD sweep
func is_ready() -> bool
func experience_tier() -> int
func mood_icon_key() -> StringName     # M1: derived from trust/fatigue; HUD shows it per slot
```

### 3.4 SlugBelt — Codex script, node placed by Claude at `Player/Belt`

```gdscript
class_name SlugBelt extends Node
const SLOT_COUNT := 6
var active_index: int
func get_slot(i: int) -> SlugInstance          # null if empty
func get_active() -> SlugInstance
func select(i: int) -> void
func cycle(direction: int) -> void             # +1 / -1, skips empty slots
signal active_changed(index: int, instance: SlugInstance)
signal slots_changed()
```
M0: `GameState` seeds slot 0 with one Infurnus instance ("Burpy"), slots 1–5 empty. Belt editing UI is M1.

### 3.5 Launch boundary [C0]

```gdscript
class_name LaunchRequest extends RefCounted
var instance: SlugInstance
var source: Node3D                    # shooter; used for raycast exclude and events
var source_id: StringName             # &"player" | npc id
var muzzle_transform: Transform3D
var direction: Vector3                # normalised, world space
var speed_mps: float
var parent: Node                      # node to add the projectile under (see §5: group "projectile_container")

class_name LaunchResult extends RefCounted
var accepted: bool
var reason: StringName                # &"ok" | &"unavailable" | &"cooldown" | &"ghouled" | &"no_slug"
var shot_id: int
var projectile: Node3D                # SlugProjectile; null when rejected

class_name SlugLauncher                # src/slug/slug_launcher.gd
static func launch(request: LaunchRequest) -> LaunchResult
```

Decisions I am asking C0 to record:

- **Transform eligibility is decided from `speed_mps` at launch**, inclusive: `speed_mps >= instance.data.velocity_threshold` → the shot will transform (after the 0.25 s TRANSFORMING window, or on impact if sooner); otherwise it is dud-bound. Rationale: the HUD notch must be a truthful promise. If eligibility were re-evaluated per tick, a 40 m/s shot fired downhill could accelerate past 44.7 m/s under gravity and transform "below the notch", which reads as a bug. Per-tick speed is still tracked for debug/HUD. Ricochet (Speedstinger) and Slug Fu may re-evaluate speed at ricochet — decide when those land.
- Impact **during** TRANSFORMING resolves as a transformed hit, exactly once; the visual completes at the impact point.
- **Dud:** bounce (restitution ≈ 0.3, strong damping), rest 1.5 s, auto-return, **no cooldown, no XP, no energy cost**. `recall` action may shorten the 1.5 s wait.
- **Energy (M0):** `energy -= data.energy_cost` on successful transform; energy **never gates a shot in M0**. One skill gate (velocity) for the playtest. Gating/regen rules are settled in S2 with Frostcrawler/Tazerling.
- **Recovery:** flight timeout 8 s or leaving the arena bounds → forced RETURNING. The instance is released to READY/COOLDOWN only by the projectile service; if the source node is freed mid-flight, return to the belt position last recorded on the instance so an owned slug is never stranded or permanently reserved.

### 3.6 Damageable — I place it on prefabs and read it from UI

```gdscript
class_name Damageable extends Node
@export var max_hp: float = 100.0
@export var defender_element: StringName = &"none"
var hp: float
var statuses: Dictionary                        # StringName -> remaining seconds
func receive(packet: DamagePacket) -> DamageResult   # delegates to CombatResolver.resolve
signal damaged(result: DamageResult)
signal died()
signal status_changed(status: StringName, active: bool)
```

## 4. Player-side interfaces Claude owns [C]

### 4.1 Player prefab `res://scenes/prefabs/player/player.tscn`

```
Player (CharacterBody3D · player_controller.gd · group "player" · layer 2 · mask 1|3)
├── Collision      CollisionShape3D  CapsuleShape3D r=0.35 h=1.8
├── Visual         Node3D → MeshInstance3D capsule + a "nose" box so facing is readable
├── Movement       Node
│   └── Ground     GroundMovementProvider · config = res://data/player/ground_movement.tres
├── CameraRig      camera_rig.tscn → Pivot (y=1.6) → SpringArm3D → Camera3D
├── Blaster        Node3D · blaster.gd · charge_config = res://data/player/charge_default.tres
│   └── Muzzle     Marker3D (right shoulder: +0.35 x, 1.45 y, 0.4 z forward)
└── Belt           SlugBelt (Codex script §3.4)
```

### 4.2 PlayerController

```gdscript
class_name PlayerController extends CharacterBody3D
enum State { IDLE, WALK, RUN, JUMP, FALL, CLIMB, SLIDE, AIM, FIRE, MOUNTED, STAGGERED, GHOULED }
# M0 implements IDLE, WALK, RUN, JUMP, FALL, AIM, FIRE; the rest exist as enum values only.
signal state_changed(from: State, to: State)
var state: State
func set_movement_provider(provider: MovementProvider) -> void
func get_blaster() -> Blaster
func get_camera_rig() -> CameraRig
func get_belt() -> SlugBelt
```
Loop per physics frame: read input → `MoveIntent` → active provider writes `velocity` → `move_and_slide()` → derive state (`is_on_floor()`, planar speed, aim held, blaster charging). Facing: toward move direction in explore; locked to camera yaw while aiming. Mouse: captured on start and on click; `ui_cancel` releases; click re-captures.

### 4.3 Movement

```gdscript
class_name MoveIntent extends RefCounted
var move_axis: Vector2          # input-space, y = forward
var look_basis: Basis           # camera yaw basis (no pitch) for world-relative movement
var jump_pressed: bool          # just pressed this frame
var jump_held: bool
var sprint: bool
var aim: bool

class_name MovementProvider extends Node
func activate(body: CharacterBody3D) -> void
func deactivate(body: CharacterBody3D) -> void
func apply(body: CharacterBody3D, intent: MoveIntent, delta: float) -> void   # writes body.velocity only
func suggested_state(body: CharacterBody3D, intent: MoveIntent) -> PlayerController.State

class_name MovementConfig extends Resource      # data/player/ground_movement.tres
@export var walk_speed := 4.5
@export var run_speed := 7.5
@export var aim_speed := 3.0
@export var acceleration := 30.0
@export var deceleration := 40.0
@export var air_control := 0.4
@export var jump_velocity := 5.5
@export var gravity_scale := 1.0                 # × ProjectSettings physics/3d/default_gravity
@export var coyote_time := 0.12
@export var jump_buffer := 0.12
@export var turn_speed_deg := 720.0
```
`GroundMovementProvider` implements the above. The Mecha Beast provider (M3) is a sibling node swapped in by `set_movement_provider()`; the controller never branches on mount state.

### 4.4 CameraRig

```gdscript
class_name CameraRig extends Node3D
@export var profiles: Dictionary                 # StringName -> CameraProfile (explore / aim / duel)
func set_profile(id: StringName, blend_seconds: float = 0.25) -> void
func get_camera() -> Camera3D
func get_aim_origin() -> Vector3
func get_aim_direction() -> Vector3
func get_aim_point(max_distance: float = 500.0) -> Vector3   # raycast mask {1,3,5}, exclude player; miss → origin + dir * max_distance
func get_yaw_basis() -> Basis                               # feeds MoveIntent.look_basis
signal profile_changed(id: StringName)

class_name CameraProfile extends Resource       # data/camera/explore.tres · aim.tres · duel.tres
@export var arm_length := 3.5
@export var shoulder_offset := Vector2(0.0, 0.0) # x = side, y = up, metres; aim uses (0.6, 0.1)
@export var pivot_height := 1.6
@export var fov := 75.0
@export var sensitivity := 0.12                  # deg per mouse px
@export var pitch_min_deg := -60.0
@export var pitch_max_deg := 70.0
@export var follow_lag := 0.0                    # 0 = rigid
@export var occlusion_fade_distance := 1.2
```
Soft occlusion fade: when `SpringArm3D.get_hit_length()` < `occlusion_fade_distance`, fade `Player/Visual` alpha proportionally instead of letting the camera clip through the capsule. Only layers {1,9} collapse the arm.

### 4.5 Blaster

```gdscript
class_name Blaster extends Node3D
@export var charge_config: ChargeConfig
@export var muzzle: Marker3D
var belt: SlugBelt                                # injected by PlayerController
var camera_rig: CameraRig                         # injected
func begin_charge() -> void                       # emits fire_rejected immediately if belt.get_active() is null / not ready
func cancel_charge() -> void
func release() -> LaunchResult                    # builds LaunchRequest and calls SlugLauncher.launch()
func is_charging() -> bool
func get_charge() -> float                        # 0..1
signal charge_started()
signal charge_changed(charge01: float, projected_speed_mps: float)   # every physics frame while charging
signal charge_cancelled()
signal fired(result: LaunchResult)
signal fire_rejected(reason: StringName)

class_name ChargeConfig extends Resource        # data/player/charge_default.tres
@export var charge_time := 0.6
@export var curve: Curve                          # monotonic 0..1 → 0..1, ease-out so early release is punished
@export var min_speed := 20.0                     # 45 mph — dud
@export var max_speed := 62.0                     # 139 mph
@export var perfect_window := 0.0                 # fraction of charge near 1.0 granting a bonus; 0 = off in M0, upgrades widen it
func speed_for_charge(charge01: float) -> float   # lerp(min_speed, max_speed, curve.sample_baked(charge01))
func charge_for_speed(speed: float) -> float      # bisection on the monotonic curve; drives the HUD notch
```
Launch direction = `(camera_rig.get_aim_point() - muzzle.global_position).normalized()` — standard over-shoulder correction so the slug goes where the crosshair points. Charge accumulates on scaled physics delta; holding at full charge is allowed (no auto-fire). Threshold notch position = `charge_config.charge_for_speed(belt.get_active().data.velocity_threshold)` — per-breed, from `SlugData`, never a hardcoded 44.7 in UI. Blaster upgrades (M2) are new `ChargeConfig` resources.

### 4.6 HUD `res://scenes/ui/hud.tscn` (CanvasLayer) and wheel

- **ChargeMeter** — arc or bar; hard notch at the threshold; fill colour flips at the notch; live mph readout while charging.
- **Crosshair** — dot in explore, reticle in aim.
- **BeltStrip** — 6 slots, active highlight, availability state (ready / in flight / dud / cooldown sweep / ghouled), mood icon slot (M1).
- **ShotFeedback** — last shot text: `DUD · 41 mph` or `138 mph · TRANSFORM`, fades.
- **DebugOverlay** (F3) — fps, frame ms, physics ms, player state, projectile count, `TimeController` stack, last `LaunchResult.reason`.
- **AmmoWheel** `res://scenes/ui/ammo_wheel.tscn` — radial 6; opens while `wheel` held; `TimeController.push_scale(&"wheel", 0.25)` on open, `pop_scale` on close; hover/select → `belt.select(i)`; cancels any charge on open.

## 5. Scene assembly (I0) `res://scenes/main.tscn` [C]

```
Main (Node3D)
├── World (Node3D · group "world_root")          ← the node OriginShifter will translate in M1
│   ├── Arena          200 × 200 m PlaneMesh + StaticBody3D/BoxShape3D (0.5 thick) · layer 1
│   ├── Cover          a few boxes, a ramp, two pillars (arc and cover testing) · layer 1|9
│   ├── Targets        DummyTarget × 3 at 10 m / 30 m / 60 m (Codex prefab, instanced not edited)
│   └── Projectiles    Node3D · group "projectile_container"   ← LaunchRequest.parent
├── Player             player.tscn at (0, 1, 0)
├── Environment        WorldEnvironment (dark ambient, light fog, tonemap) · DirectionalLight3D (dim, cool) · 2–3 OmniLight3D (warm / teal emissive accents)
└── UI                 HUD (CanvasLayer) · AmmoWheel
```
Smoke contract (Q0, Codex writes, Claude keeps green): `tests/smoke/test_main_boot.gd` → `scene_runner("res://scenes/main.tscn")`, `simulate_frames(600)`, assert no engine errors, `Player` and HUD present; optional scripted shot: `begin_charge()`, simulate 40 physics frames, `release()`, await `EventBus.slug_transformed`.

## 6. Tests Claude will write (gdUnit4, `tests/player/`) [C]

| Suite | Asserts |
|---|---|
| `test_charge_config.gd` | `speed_for_charge(0) == min`, `(1) == max`, monotonic over 100 samples, `charge_for_speed(44.7)` in (0,1) and round-trips within 0.01 m/s |
| `test_blaster.gd` | charge accumulates with delta and clamps at 1; release at low charge produces `speed_mps < 44.7`; at/above notch charge produces `>= 44.7`; `fire_rejected` when no ready slug (fake belt until B0 lands) |
| `test_ground_movement.gd` | gravity applies in air; jump sets `velocity.y`; coyote window honoured; sprint reaches `run_speed`; aim caps at `aim_speed` |
| `test_camera_rig.gd` | profile blend reaches target values; `get_aim_point()` on a miss equals `origin + dir * max_distance`; pitch clamps |
| `smoke/test_main_boot.gd` | shared with Codex (Q0) |

## 7. Decisions for C0 to ratify (summary)

1. Transform eligibility from launch speed (§3.5).
2. `TimeController` autoload + clock policy (§3.2).
3. `SlugBelt` state is Codex's; wheel/strip presentation is Claude's (§3.4).
4. Projectile parent via group `projectile_container` under `World` (§5) — needed for origin shifting later.
5. HUD binds to `Blaster` signals directly; EventBus carries world events (§3.1).
6. Godot pin 4.7.2-stable (claude_handoff.md CL-002).
7. Authoring rules §0 go into contracts.md verbatim.
