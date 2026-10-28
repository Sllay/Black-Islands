# World Ecology & Offscreen Simulation — Design/Technical Spec

Status: accepted architecture direction; numeric caps require mobile benchmarks.

## Goal

The surface should feel alive without simulating every creature with full Godot physics/AI at all distances.

Black Island borrows the useful *idea* behind ARK stasis — expensive actors stop full simulation when players are far away — but adds a coarse logical simulation tier for entities that must continue meaningful long-range behavior such as zombie migration.

## Persistent entity record

Important/long-lived creatures should have authoritative data independent from their current Scene node.

Conceptual record:

```text
WorldMobState
- persistent_id
- mob_definition_id
- level
- current_hp/status
- world_position or region position
- home_region / territory
- disposition state
- group_id
- current high-level intent
- target region/entity id optional
- last_simulated_world_time
- respawn/despawn policy
- inventory/corpse-relevant state
```

A loaded CharacterBody3D is a presentation/execution adapter over this state, not the only place the creature exists.

## Simulation tiers

### Tier A — Active

Near player / gameplay relevant.

- full CharacterBody3D movement;
- collision;
- LimboAI/perception/combat;
- normal animation/VFX;
- highest update rate.

### Tier B — Near proxy

Near enough that its movement may soon matter, but not visible/interactive.

- no expensive visual presentation;
- simplified navigation/steering;
- perception at reduced frequency;
- reduced update rate such as a few Hz, benchmarked later.

### Tier C — Regional logical simulation

Far from player but behavior must progress.

- no Scene physics;
- movement across a coarse `RegionGraph`/navigation sectors;
- scheduled state updates, e.g. fractions of a Hz to ~1 Hz depending on type;
- combat between unobserved ordinary fauna should normally resolve statistically/event-wise rather than simulating hitboxes.

### Tier D — Stasis/scheduled

Entity is not currently required to move continuously.

- preserve authoritative record;
- advance only deadlines/schedules/needs that matter;
- wake on player proximity, world event, migration trigger, time-of-day change or explicit simulation request.

## Wake/sleep transition

Loading an entity must not teleport it into impossible geometry.

Flow:

```text
WorldMobState
-> ensure terrain/structures for spawn envelope are ready
-> resolve safe position
-> instantiate/pool visual+physics actor
-> restore state/intent
```

On deactivation:

```text
actor snapshot -> WorldMobState -> return scene actor to pool/unload
```

## Zombie migration

Zombies originate from cave/world spawn logic and can migrate toward population concentrations even when outside render range.

Do not pathfind every distant zombie against detailed terrain.

Use:

```text
PopulationHeatMap
+ RegionGraph
+ zombie group intent
```

Population heat can consider:

- player;
- village NPC density;
- future tribe settlement populations;
- relevant noise/raid attraction events.

A distant zombie group advances region-to-region logically. When it reaches the active simulation radius it materializes at a valid edge/entry position and full AI takes over.

This enables raids to feel like world movement rather than enemies simply spawning beside the player.

## Skeleton lifecycle

Initial lore/behavior direction:

- skeleton bodies/dormant remains exist or are represented during daytime;
- spirit/ghost activity awakens them at night;
- active skeletons become night threats;
- daytime transition returns surviving skeletons to dormant state according to definition rather than requiring arbitrary despawn/re-spawn.

The system stores the skeleton entity state, not a permanent active AI node.

## Spawn caps

Never use one unlimited global spawner.

Use layered budgets:

- biome/region population target;
- species population target;
- active-AI cap near players;
- global logical population cap;
- special raid/event budget independent where appropriate.

Example *benchmark starting points*, not locked content:

```text
active hostile actors near player: ~20 max baseline test
logical skeleton population: tens, not hundreds of fully active actors
```

The final values come from device profiling and encounter design.

## Intro and raids

The opening begins during an existing zombie attack on the ruined village.

Later raid progression may begin with small groups in the approximate 5–10 zombie range, then scale by progression/event difficulty.

Raid spawning should prefer migration/entry regions where possible. Emergency encounter generation can still instantiate groups through validated map edges if the simulation needs to guarantee an event.

## Passive surface fauna

Initial surface fauna direction includes:

- cow;
- pig;
- chicken;
- rabbit;
- tropical fish species/visual variants.

These fill ecological/resource roles without needing unique mechanics for every species.

## Fish schools and bird flocks — Boids

Use Craig Reynolds-style Boids for school/flock motion:

1. **Separation** — avoid crowding local neighbors.
2. **Alignment** — steer toward neighbors' average heading.
3. **Cohesion** — steer toward local group center.

Naive all-to-all neighbor search is O(n²) and should not be used for larger groups.

Use spatial hashing/uniform buckets so a boid queries only its own/adjacent buckets.

### Visual bird flocks

Birds in the sky are primarily ambience:

- no CharacterBody3D per bird;
- lightweight boid state arrays;
- MultiMesh/GPU-friendly presentation where practical;
- low-frequency steering update + interpolation;
- flock can despawn/reseed outside relevant visual envelope.

### Fish schools

Fish can use the same boid foundation constrained to water volumes.

Separate:

- visual school members (cheap/batched);
- gameplay fish/interactable/catchable entities when required.

A school does not need 50 full AI nodes merely because 50 sprites/meshes are visible.

## Group behavior

Pack/group systems use a registry/spatial query rather than scene-wide searches.

Examples:

- aggressive only when nearby pack size >= 3;
- flee/avoid when group size falls below threshold;
- flock migration target;
- herd defense.

## Persistence policy

Not every ambient boid needs save persistence.

Persist:

- meaningful wildlife/enemy entities the design says should survive player absence;
- named/unique/special entities;
- state relevant to quests/taming/future systems.

Regenerate:

- pure distant bird ambience;
- disposable fish-school visuals;
- non-meaningful VFX ecology.

## Required tests

- persistent mob leaves Active tier and later restores without duplication;
- zombie group advances between regions while no Scene actor exists;
- waking an entity waits for collision/terrain readiness;
- day/night skeleton transition does not duplicate bodies;
- active caps prevent huge offscreen populations becoming full actors simultaneously;
- boid neighbor work scales spatially rather than all-to-all;
- visual flock can despawn/reseed without touching persistent ecology;
- pack aggression threshold updates from spatial group registry.
