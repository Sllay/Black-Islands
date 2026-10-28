# World, Terrain and Streaming Architecture

## Surface world

Accepted model:

- authoritative volumetric voxel terrain;
- smooth SDF/Transvoxel-style presentation;
- 0.5 m terrain voxel spacing target;
- 1 m `BuildGrid` cell;
- 64 x 64 x 64 m project `WorldChunk` addressing/streaming regions;
- vertical chunking in Y as well as X/Z;
- separate building, navigation, water and prop systems derived from authoritative world state.

Detailed voxel implementation profile: `VOXEL_WORLD_IMPLEMENTATION.md`.

## Voxel dependency

Preferred candidate is Zylann Voxel Tools wrapped behind Black Island interfaces. It must pass Android/iOS performance/export validation before shipping dependency is locked.

`WorldChunk` is not the same thing as the voxel plugin's smaller data/mesh blocks.

At 0.5 m resolution a 64 m WorldChunk spans 128^3 sample positions, so Black Island never treats it as one monolithic dense remesh/collider allocation.

## Chunk residency

Initial near region:

- player WorldChunk + 8 horizontal neighbors (3x3 horizontal ring);
- vertical residency is sparse and based on actual terrain/cavity/edited data rather than loading a full 3x3x3 dense cube;
- pure air is implicit;
- untouched deep solid terrain stays generator-defined until required.

If mobile profiling remains stable around 60 FPS under representative load, add outer chunk rings using lower LOD/reduced prop simulation.

Render distance is expressed as chunk rings/distance, not one fixed total count.

## Internal mesh/collision blocks

Use smaller blocks inside WorldChunks.

Initial trial:

- surface mesh blocks: 32 voxels (~16 m at 0.5 m scale) to reduce draw calls;
- compare 16-voxel (~8 m) blocks in highly destructible cave scenarios;
- collision only in gameplay-near regions/nearest required LOD;
- local edits rebuild affected blocks/borders, never the entire 64 m WorldChunk.

## Terrain edits

Project-owned `TerrainEditService` validates and applies density/material operations.

Flow:

`action -> 3D probe -> validate editable region -> mutate SDF/material -> dirty local blocks -> persist delta -> notify water/foliage/navigation/build/farming -> budgeted presentation/collision update`

Godot SceneTree and unsafe render/physics mutations remain main-thread work. Pure generation/meshing uses worker/plugin jobs where safe.

## Terrain materials

Terrain material ownership is discrete, but compatible boundaries blend visually.

Presentation may combine:

- material weights;
- neighbor topology;
- smooth masks;
- controlled edge noise;
- biome transition weights.

Equal materials merge cleanly; different materials should not normally form straight `| |` cell boundaries.

Paths are terrain painting.

Farming is **not** stored as a generic `TILLED_*` terrain material state anymore. A `FarmPlotState` is a dedicated gameplay object anchored to the 1 m grid/surface while underlying terrain remains voxel-authoritative. See `FARMING_AND_FOLIAGE.md`.

## Save model

Base terrain is deterministic from:

`world seed + IslandProfile + generation version`

Persist primarily:

- modified voxel/data blocks;
- material edits;
- structures;
- suppression/prop mutations;
- FarmPlots;
- persistent entities;
- relevant water deviations;
- world progression.

Do not serialize untouched generated terrain.

## Island generation pipeline

`Seed -> IslandProfile -> base island volume/mask -> macro elevation -> coastline -> broad hills -> hydrology -> biome weights -> village candidates -> POIs -> resources/props -> validation -> accepted world`

Noise provides fields; design profiles/validators determine acceptable geography.

## Surface biome direction

Chapter 1 surface direction:

- beach/tropical coast around shoreline;
- open plains/tropical interior transition;
- central/appropriate forest regions;
- broad gentle elevation/hills mixed with flatter buildable areas.

Detailed biome/prop rules: `docs/design/BIOMES_AND_PROP_GENERATION.md`.

## World physical size

Design target is a medium-large island whose direct point-to-point traversal feels approximately 20-30 minutes at ordinary player travel speed.

Do not hard-code island diameter before the player motor's sustained travel speed is tuned.

Use:

`target direct distance = measured sustained travel speed x target traversal seconds`

Then validate that generated paths/terrain obstacles produce the intended real gameplay time.

World-generation profile stores physical size so Chapter 1 can use a smaller iteration profile without changing save architecture.

## Ocean and world boundary

The rendered ocean continues well beyond the playable island boundary to preserve horizon/depth.

Far ocean is cheap presentation, not fully simulated dynamic water.

A distant decorative island/land silhouette may be used as noninteractive horizon dressing through an impostor/very-low-detail mesh.

### Soft boundary / treadmill zone

Before the absolute world limit, an outer ocean zone gradually suppresses outward logical movement while continuing water animation, swim motion and camera feedback so the player experiences "travel" without actually advancing into unbounded world coordinates.

Implementation should use smooth radial movement attenuation/re-centering/presentation tricks rather than visible teleport snaps.

After approximately 5 continuous real minutes attempting to travel outward in this zone, the character may show a small thought/speech line such as a localized equivalent of "Am I actually getting anywhere?".

### Hard fail-safe

Beyond the soft zone, keep an invisible absolute collision/bounds safety layer so physics bugs cannot send the player into numerical/streaming limbo.

No build/loot/important gameplay content is placed in the soft/hard boundary region.

## Water

Dynamic water is a separate sparse simulation aligned with terrain/build coordinates.

- ocean: mostly analytic/static sea field;
- rivers/lakes: generated sleeping water regions;
- local edits: activate sparse flow cells;
- currents can affect actors;
- waterfalls are flow classifications/presentation;
- simulation runs at a lower fixed rate than rendering and sleeps stable cells.

Detailed rules: `WATER_AND_HYDROLOGY.md`.

## Props and foliage

Props are generated deterministically per biome/chunk using stable spawn IDs for persistent harvestables and batched instancing for disposable clutter.

Structure/path/FarmPlot/terrain edits update local suppression masks rather than regenerating all world props.

Grass can regrow after suppression is removed if the underlying biome/material is eligible.

## Runtime streaming layers

Keep distinct:

- **data** — voxel/edit blocks, persistent entities, biome candidates, water state;
- **presentation** — meshes, foliage MultiMeshes, props, VFX;
- **simulation** — gameplay state that may continue or advance independently of loaded presentation.

Worker jobs prepare pure data; main thread applies SceneTree/render/physics changes within time budgets.

## Navigation

Navigation data is derived from terrain/build state rather than treating the render mesh as the only truth.

Local terrain/build changes dirty navigation cells/regions. Do not globally rebake the whole island after every foundation or terrain edit.

## Caves

Cave floors are separate generated worlds, not a continuous volume under the island.

Default floors are **ephemeral per CaveRun**. They can preserve temporary state while the player remains in the run/backtracks, but ordinary unanchored floors may reroll after returning to the surface.

A rare `CaveAnchorTotem` placeholder system can convert a floor into persistent anchored state. Anchors progress consecutively and expose elevator stops.

See `docs/design/CAVES_AND_ANCHOR_PROGRESSION.md`.

## Cave transitions

`surface portal -> preload floor spawn envelope -> dark/loading transition -> reveal safe destination -> stream remaining sectors`

Do not require full-floor generation before entry.

Hot-cache adjacent floors during a run when memory allows.

## Build height

Initial construction cap is approximately +100 m relative to world reference/sea level. Placement beyond it fails deterministically.
