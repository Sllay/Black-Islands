# Codex Prompt — S01-P02 World Foundation

You are implementing Season 1 Part 2 of Black Island. Follow `AGENTS.md` exactly. Start only from a validated P01 state where the real project boots and enters Main.

## Read in this order
1. `AGENTS.md`
2. `harness/context/S01-P02.md`
3. `docs/architecture/VOXEL_WORLD_IMPLEMENTATION.md`
4. `docs/architecture/WORLD_STREAMING.md`
5. `docs/architecture/WATER_AND_HYDROLOGY.md`
6. `docs/design/BIOMES_AND_PROP_GENERATION.md`
7. `docs/architecture/SAVE_AND_MIGRATION.md`
8. `docs/decisions/ADR-0004-smooth-voxel-world-and-build-grid.md`
9. `research/VOXEL_TOOLS_INTEGRATION.md` if present

Read only implementation files relevant to this phase after that.

## Goal
Build the first real generated Black Island world using smooth volumetric voxel terrain, streaming and deterministic save identity. The phase ends with a navigable, persistent island prototype running through the production Main flow, not a disconnected tech demo.

## Fixed architecture
- terrain voxel target: 0.5 m;
- BuildCell: 1.0 m;
- project WorldChunk address space: 64 x 64 x 64 m;
- vertical chunks exist;
- near horizontal streaming baseline: 3x3 WorldChunk ring around the active area;
- WorldChunk is not required to equal one monolithic mesh/collision block;
- smooth volumetric surface, not visible Minecraft cubes;
- deterministic surface island generated once per save;
- save seed + mutations/deltas, not generated mesh/collision caches;
- BuildGrid is separate from terrain authority.

## Implementation priorities
### 1. Integrate the selected smooth-voxel path
Use the P00 research/pinned Voxel Tools route if validated. Wrap dependency use behind Black Island-owned world interfaces/services. Do not let gameplay code depend directly on arbitrary addon internals.

Prove:
- smooth terrain generation;
- runtime local density/material edit;
- collision update;
- chunk boundary continuity;
- vertical chunk addressing.

If the dependency cannot satisfy the phase on the current platform/toolchain, document the blocker and produce the smallest evidence-driven fallback/prototype; do not secretly replace the project with a custom voxel engine.

### 2. World coordinate model
Implement explicit conversion utilities for:
- world position <-> voxel coordinate;
- world position <-> WorldChunk coordinate;
- world/voxel <-> 1 m BuildGrid coordinate.

These functions must be deterministic and tested at positive/negative coordinates and boundaries.

### 3. Streaming
Implement first streaming controller with:
- 3x3 horizontal near ring;
- vertical chunks loaded only where data/surface/player needs them;
- asynchronous/background-safe generation/data preparation where supported;
- SceneTree/resource application on the main thread where required;
- unload without losing authoritative persistent state;
- hysteresis/debounce so crossing a boundary does not thrash load/unload.

Track profiling counters in debug UI: loaded chunks, pending jobs, mesh rebuilds, collision rebuilds, memory estimates if available.

### 4. Deterministic island baseline
Generate a medium island profile sufficient to validate the architecture:
- surrounding beach/coast;
- tropical plains;
- gentle elevation/hills;
- central/denser forest mask/region data;
- ocean surrounding island;
- village/spawn candidate area kept reasonably buildable;
- seed deterministic.

Do not chase final beauty/content density in this phase. Shape must be recognizably island-like and navigable.

### 5. Material foundation
Prove discrete logical materials with smooth presentation/blending where practical, including at least:
- sand/beach;
- grass;
- dirt/stone representative material.

Implement a local material paint test operation that changes only the intended logical voxel/surface region and rebuilds only affected mesh region/neighbors.

Do not implement FarmPlot yet.

### 6. BuildGrid foundation
Implement coordinate/occupancy foundation only:
- 1 m integer cell coordinates;
- shared-edge representation seam for future walls;
- world-to-cell debug highlight;
- no full building catalog/support solver yet.

### 7. Save/persistence
On save creation:
- generate/store world seed and generation version;
- surface generation is considered established for that save;
- reloading the same save reproduces the same base island;
- record at least one local terrain/material mutation as a delta and prove it survives reload;
- never serialize generated mesh/collision buffers as world truth.

### 8. Water/ocean baseline
Do not attempt full dynamic Family-Time-like hydrology yet.
Prove:
- ocean visual/interaction boundary around island;
- generated basic lake/river/water-body hook if generator produces one;
- architecture seam for future `WaterGrid` simulation;
- near/far ocean representation can use different quality paths.

### 9. World boundary/horizon
Prototype:
- distant ocean beyond playable island;
- hard fail-safe boundary far outside normal play;
- soft illusion/treadmill boundary hook without trapping normal traversal;
- optional distant decorative land silhouette if very cheap.

Do not spend phase time polishing this beyond proof.

## Performance requirements
This is a measurement phase. Record actual timings/memory where tools allow:
- initial world generation;
- chunk load/unload;
- local remesh after edit;
- collision update latency;
- loaded chunk count;
- frame-time impact while crossing chunk borders.

Do not claim mobile performance from desktop-only numbers. If physical mobile export is unavailable, clearly mark the result `desktop proxy only`.

## Out of scope
- final water simulation;
- player LPC/combat/inventory;
- final props/foliage ecology;
- farming;
- NPCs/mobs;
- caves;
- final building system.

Use a temporary debug pawn/camera only if necessary to inspect the world; P03 will implement the real player.

## Required tests
- same seed -> same sampled terrain/material values;
- different seed -> meaningfully different island;
- voxel/chunk/build-grid coordinate boundary tests;
- edit at chunk border updates both required sides without seam;
- unload/reload preserves saved terrain delta;
- crossing chunk borders does not duplicate/loss world state;
- vertical chunk coordinate/load proof;
- project still boots through P01 production flow.

## Checkpoints
C01: dependency integration + smooth voxel proof + coordinate tests.
C02: deterministic island + 3x3/vertical streaming + material paint.
C03: save delta + BuildGrid foundation + ocean/boundary + profiling/handoff.

## Done when
A real save enters a generated, smooth, navigable island through Main; chunks stream; one terrain/material edit persists; BuildGrid coordinates work; performance evidence exists; no later gameplay system is faked as complete.

## Final handoff
Return branch + SHA, exact dependency/version used, playable path, generated-world seed used for validation, tests, profiling numbers with platform label, files changed, unresolved performance risks, and exact task for S01-P03.