# Voxel World Implementation Profile

Status: Accepted initial technical profile; benchmark constants may be tuned without changing the architecture.

## Core scale

Black Island uses a precise integer relationship between construction and terrain.

- `BuildCell = 1.0 m`
- `TerrainVoxel = 0.5 m`
- one build cell spans `2 x 2` terrain voxels horizontally;
- the same 0.5 m voxel spacing applies vertically.

This ratio is deliberately simple so build sockets, terrain edits, farming anchors and navigation sampling can convert coordinates without floating-point drift.

## WorldChunk

The project-level streaming/persistence chunk is:

`64 m x 64 m x 64 m`

Chunks exist in X, Y and Z; vertical chunking is mandatory.

At 0.5 m voxel spacing, one full WorldChunk spans `128 x 128 x 128 = 2,097,152` voxel sample positions. A dense 16-bit channel alone would be roughly 4 MiB before material channels, mesh, collision and runtime overhead. Therefore a WorldChunk is **not** one monolithic dense mesh/data allocation.

A WorldChunk is primarily:

- stable world address;
- persistence/delta container;
- streaming/scheduling unit;
- biome/prop ownership region;
- coarse debugging/profiling region.

Voxel data and render/collision work are subdivided internally.

## Preferred voxel dependency

Preferred implementation candidate is **Voxel Tools for Godot** by Zylann, currently compatible with the Godot 4.7 generation and providing:

- volumetric runtime editing;
- SDF smooth terrain;
- Transvoxel LOD;
- chunk streaming;
- threaded generation/meshing;
- physics collision integration;
- voxel material channels;
- instancing support.

Black Island must wrap the dependency behind project-owned interfaces. Do not let saves/gameplay code depend directly on plugin node paths or transient plugin internals.

The module/custom-engine build and GDExtension editions must be profiled on Android and iOS before choosing the shipping integration. The architecture must survive switching between the two.

## Smooth terrain representation

Use an SDF/density channel for geometry and compact material channels for surface texturing.

Rendering target:

`VoxelLodTerrain + VoxelMesherTransvoxel` or an equivalent project-owned wrapper.

Voxels are never visible cubes unless a future content type intentionally requests blocky presentation.

## Internal block sizes

The 64 m WorldChunk is subdivided into smaller plugin/data/mesh blocks.

Initial profile with 0.5 m world scale:

- plugin data block: 16 voxels = 8 m world span;
- preferred surface mesh block trial: 32 voxels = 16 m world span;
- alternate high-edit-frequency trial: 16 voxels = 8 m world span.

A 64 m WorldChunk therefore contains 4 x 4 x 4 = 64 logical 16 m mesh regions when using 32-voxel mesh blocks.

Recommended first benchmark:

- surface island: mesh block size 32 to reduce draw calls;
- cave/high-edit stress test: compare 16 vs 32 because smaller blocks reduce remesh cost after digging.

Do not rebuild all 64 m after a local pickaxe/hoe/path edit.

## WorldChunk residency

Do not interpret a 3x3 visible region as `3 x 3 x 3` fully dense chunks.

Streaming is sparse in Y:

- horizontal residency is centered around the player/viewer;
- only vertical chunks intersecting generated terrain, player-accessible cavities, water or persistent edits need full data/presentation;
- pure air chunks above terrain are implicit;
- deep untouched solid regions remain generator-defined until requested/edited.

This is critical for mobile memory.

## Initial streaming rings

Start conservatively and profile.

### Gameplay/near ring

- central WorldChunk plus its 8 horizontal neighbors = 3x3 horizontal active region;
- highest terrain detail where needed;
- gameplay props/NPC interaction enabled according to simulation rules;
- collisions only where the player/gameplay can realistically reach.

### Visual outer ring

If the target device maintains budget, add an outer visual ring (for example 5x5 horizontal coverage) using lower LOD and reduced prop detail.

Do not equate visual residency with full simulation residency.

Future render distance is expressed in **chunk rings/distance**, not a fixed count of total chunks.

## LOD

Initial surface target:

- 4 terrain LOD levels for testing;
- LOD0 local editable region;
- progressively lower-detail terrain outside gameplay range;
- far ocean/horizon/remote decorative land should use dedicated low-cost presentation rather than forcing full-resolution voxel data.

Exact distances are benchmark variables.

Only LOD0/loaded editable regions may accept destructive terrain actions. Input tools must query `is_area_editable`/equivalent before committing an edit.

## Collision strategy

Collision is generated only for gameplay-near terrain.

Rules:

- no collision for distant visual-only LOD unless explicitly required;
- terrain edits mark local collision blocks dirty;
- repeated edits are coalesced before expensive collision rebuild when safe;
- collision application is budgeted across frames;
- visual response may update before final high-quality collision if the action remains logically safe;
- never rebuild the whole WorldChunk collider after one local edit.

Candidate first profile: collision on nearest LOD only.

## Threading

Pure generation, voxel calculation and meshing should run through Voxel Tools/internal worker jobs or Black Island worker tasks where safe.

Godot SceneTree mutations remain main-thread work.

Main-thread terrain integration must have a strict per-frame time budget. If several chunks complete simultaneously, apply them over multiple frames instead of causing a hitch.

Do not allocate every CPU core to terrain. Leave capacity for AI, audio, loading and the operating system.

## Terrain editing

Semantic terrain tools call a project-owned `TerrainEditService`.

Examples:

- pickaxe: subtract SDF/matter in a bounded shape;
- shovel/path tool: surface material paint;
- build preparation: constrained flatten/add/remove operations;
- future explosion: larger bounded removal shape.

Editing flow:

`action -> probe -> validate editability -> mutate voxel data/material -> dirty local mesh/collision/material regions -> persist delta -> notify foliage/build/navigation/water systems`

All dependent systems receive the edited AABB/region. They do not scan the whole world afterward.

## Material blending

Logical terrain ownership stays discrete while presentation blends boundaries.

Use the smooth-voxel material/texture-weight system to support:

- grass/dirt;
- sand/soil;
- paths;
- rock;
- biome surfaces;
- wet/dry transitions where appropriate.

Neighbor-compatible materials should blend with soft/noisy masks rather than straight grid seams. Material painting should update local weights, not spawn one terrain node per cell.

Farming is an exception: the persistent `FarmPlot` state is a dedicated gameplay object anchored to the grid; it may use a local mesh/decal/patch visual while the underlying terrain remains voxel-authoritative.

## Persistence

Generated untouched terrain is reconstructed from the save seed.

Persist primarily:

`seed + generator/profile version + edited voxel/data blocks + material deltas + persistent entities`

Do not serialize every untouched voxel.

Edited data is versioned and compactable. If a later compaction proves an edited block equal to regenerated baseline, it may be removed from the delta store.

## Build relationship

The build grid uses 1 m cells and integer coordinates derived from voxel coordinates.

`build_x = floor(world_x / 1m)`

Terrain/build conversions must go through one shared coordinate utility so farming, foundations, targeting and navigation cannot disagree about boundaries.

## World height / build limit

Initial building ceiling: approximately `+100 m` relative to the world's reference sea level/origin plane, subject to level-design validation.

Attempting construction above the allowed world/build height returns a deterministic placement failure (`WORLD_HEIGHT_LIMIT`) instead of relying on physics accidents.

Terrain generation itself may use separate vertical bounds.

## Profiling gates

Before expanding beyond the first 3x3 near ring, profile on target-class mobile hardware:

- frame time CPU/GPU;
- resident voxel data;
- generated mesh memory;
- collision memory/rebuild time;
- terrain worker queue depth;
- main-thread integration time;
- remesh latency after edits;
- draw calls;
- thermal behavior during sustained traversal/digging.

Only expand chunk rings after the baseline remains stable around 60 FPS under representative gameplay load.
