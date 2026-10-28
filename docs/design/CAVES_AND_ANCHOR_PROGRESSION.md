# Caves & Anchor Progression — Design/Technical Spec

Status: Accepted core direction.

## Core rule

Cave/mine floors are separate generated worlds and are **ephemeral by default**.

A normal cave expedition behaves as a run:

`surface -> floor 1 -> floor 2 -> ... -> return to surface`

While the player remains in the same expedition, recently visited adjacent floors may stay in hot/session cache for fast backtracking.

When the expedition is ended by returning to the surface/explicit reset condition, unanchored floors are allowed to be discarded. A future expedition regenerates them from a new run seed/profile.

Therefore normal cave mining does not permanently exhaust the world's underground resource layout.

## CaveRun

Conceptual state:

```text
CaveRun
- run_id
- run_seed
- generation_version
- current_floor
- session_floor_cache
- run events/rewards state
```

Floor seed can derive deterministically from:

`run_seed + floor_index + floor_profile`

This allows deterministic regeneration inside one run without making the floor permanently tied to the save.

## Unanchored floor lifecycle

During one active CaveRun:

- destroyed terrain stays destroyed while that floor remains in session/hot cache;
- opened containers/defeated enemies remain resolved for the current run;
- backtracking can restore floor session state;
- unloaded session floors may serialize compact temporary data if memory requires it.

After the run is abandoned/closed:

- temporary floor state may be deleted;
- next run generates a different layout/resources/encounters according to new run seed.

## Totem of Anchoring

Final player-facing baseline name: **Totem of Anchoring**.

Technical stable ID may use a normalized form such as `totem_of_anchoring` while localization controls display text.

The Totem is rare because it converts a normally shifting cave floor into permanent world state.

Lore direction:

- cave floors are unstable/shifting between expeditions;
- an Anchoring Totem roots one generated floor in place;
- consecutive anchors form a stabilizing chain through depth;
- this explains both procedural rerolls and the no-skip progression rule in-world.

When successfully activated, the floor changes lifecycle:

`EPHEMERAL -> ANCHORED_PERSISTENT`

Persist at least:

- anchor identity;
- floor index/profile/seed;
- required terrain edits;
- player structures;
- persistent containers;
- elevator stop state;
- special POI/NPC/world state that must survive;
- relevant water changes.

An anchored floor no longer rerolls as an ordinary unanchored floor while that anchor remains valid.

## Consecutive progression rule

Anchoring cannot skip progression.

Floor 1 may be the first anchor.

To anchor floor N > 1, the required previous progression chain must already be anchored/validated.

Baseline:

`1 -> 2 -> 3 -> 4 -> ...`

The player cannot simply place anchors on floor 1 and floor 10 and permanently bypass floors 2-9.

This makes the rare anchor system a meaningful long-term descent investment and supports the lore that deeper floors are stabilized by the anchor chain above them.

## Elevator network

Anchored floors become eligible elevator destinations.

`CaveElevatorNetwork` is derived from the player's valid anchored progression chain.

If floors 1..10 are anchored, the player may select any unlocked anchored stop according to elevator UI/rules rather than physically descending every floor each trip.

The elevator does not create persistence by itself. It only exposes destinations that already satisfy the anchor rules.

If only floors 1, 5 and 10 are configured as actual elevator stops after all required intermediate anchors exist, the elevator UI can expose those stop floors while the full anchor chain still validates progression.

## Anchor removal/destruction

Exact game rule remains balance content, but implementation must support deterministic handling if an anchor becomes invalid:

- do not silently corrupt/delete player structures while the player is on the floor;
- mark dependent elevator routes invalid;
- resolve whether persistence becomes orphaned, frozen or recoverable through an explicit rule;
- never reroll an occupied loaded persistent floor underneath the player.

Chapter 1 may make activated anchors non-destructible by ordinary actions to simplify this edge case.

## Floor generation

Each floor chooses a `CaveFloorProfile` before detailed generation.

Profile can control:

- biome(s);
- room/corridor topology;
- ore/resource tables;
- enemy ecology;
- descent location rules;
- water presence;
- POIs;
- darkness/lighting;
- boss/special event chance.

Current named biome direction is defined in `CAVE_BIOMES_AND_GENERATION.md`:

- Standard Cave;
- Darkness;
- Luminous Forest.

Floor index does not permanently determine biome unless a progression/event rule says so.

## First-floor preload

The surface world itself is generated once at save creation and persists through seed + deltas.

At save creation Black Island may also generate/cache the first cave floor's entry/spawn envelope so first entry is fast.

While the player explores Floor 1, the next-floor spawn envelope can begin prefetching.

This does not make unanchored Floor 1 permanently persistent; it is simply an initial/preloaded CaveRun floor.

## Resource renewal

Because normal floors reroll between runs, ore/resource regeneration is naturally tied to new floor generation.

Anchored persistent floors do **not** automatically reroll their resource layout. Any resource regrowth/respawn there must follow explicit resource definitions, preventing a persistent floor from being regenerated around player construction.

## Streaming

Entering a descent/entrance begins preloading only the destination floor's spawn envelope/near sectors.

Transition flow:

`approach portal -> request destination -> preload spawn envelope -> dark/eyes-closed/loading mask -> swap world -> reveal -> stream remaining sectors`

Do not wait for the entire cave floor to generate before allowing entry if a safe spawn envelope is ready.

## Hot cache

Within a CaveRun, keep the immediately previous/next relevant floor session in hot cache when memory budget permits.

Example:

```text
CURRENT Floor 5
HOT     Floor 4
PREFETCH Floor 6 spawn envelope
COLD    other ephemeral floors
```

Anchored floors are persisted to save storage but their Scene/presentation can still unload.

Persistence does not mean always resident in memory.

## Surface return

Returning to the surface ends or suspends the CaveRun according to final UX. Current direction: normal unanchored run state may be discarded so re-entry is fresh/randomized.

Anchored floors survive regardless of the normal run reset.

## Required tests

- unanchored floor rerolls after run reset;
- backtracking during one run preserves temporary state;
- anchored floor survives surface return;
- Floor 10 cannot anchor without required previous progression chain;
- Totem of Anchoring activation is persisted exactly once;
- elevator exposes only valid anchored stops;
- unloading anchored floor does not lose authoritative state;
- cave reroll never overwrites anchored floor state;
- new run resources/biome may differ according to run seed;
- first cave entry can use pre-generated safe Floor 1 envelope without making the floor permanently anchored;
- entering later destination requires only safe spawn-envelope readiness, not full-floor completion.
