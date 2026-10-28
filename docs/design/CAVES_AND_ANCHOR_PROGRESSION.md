# Caves & Anchor Progression — Design/Technical Spec

Status: Accepted core direction; player-facing totem name remains open.

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

## Persistent anchor totem

A rare special totem can claim/anchor a cave floor.

The final player-facing name is intentionally left open; technical placeholder:

`CaveAnchorTotem`

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

This makes the rare anchor system a meaningful long-term descent investment.

## Elevator network

Anchored floors become eligible elevator destinations.

`CaveElevatorNetwork` is derived from the player's valid anchored progression chain.

If floors 1..10 are anchored, the player may select any unlocked anchored stop according to elevator UI/rules rather than physically descending every floor each trip.

The elevator does not create persistence by itself. It only exposes destinations that already satisfy the anchor rules.

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

See `BIOMES_AND_PROP_GENERATION.md`.

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
- floor 10 cannot anchor without required previous progression chain;
- elevator exposes only valid anchored stops;
- unloading anchored floor does not lose authoritative state;
- cave reroll never overwrites anchored floor state;
- new run resources differ according to run seed;
- entering destination requires only safe spawn-envelope readiness, not full-floor completion.
