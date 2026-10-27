# World, Terrain and Streaming Architecture

## Surface world

Preferred model:
- smooth visual terrain using Terrain3D after compatibility/performance validation;
- Black Island logical cell/stud grid layered over the surface for farming, occupancy, construction checks and constrained terrain edits.

The logical grid is gameplay data, not visible voxel geometry.

## Island generation pipeline

`Seed -> IslandProfile -> base mask -> warp/macro elevation -> coast shaping -> hills -> hydrology -> biome allocation -> village candidates -> POIs/resources -> validation -> accepted world`.

`IslandProfile` constrains valid river/lake arrangements before generation so noise does not dictate design.

## Village placement

Candidate scoring considers at least buildable area, flatness/slope, water proximity, dangerous terrain, cave/POI spacing and required expansion room.

## Runtime streaming

Separate:
- data layer;
- presentation layer;
- simulation layer.

Worker threads may generate/decode/prepare pure data. SceneTree mutations and unsafe engine interactions are applied on the main thread.

Avoid churn from creating/freeing thousands of Nodes. Use pooling and batched/instanced presentation for repeated objects where appropriate.

## Mines

Mine floors are separate world states/scenes, not terrain physically underneath the island.

Flow:
`surface cave portal -> dark transition -> preloaded spawn envelope -> MineFloor N -> stream remaining sectors`.

Near a descent/return portal, begin preloading the destination spawn envelope. If not ready when crossing, hold the masking/loading transition until the destination is safe to reveal.

Maintain a small hot cache of adjacent/recent floors when memory budget permits.

`MineFloorData` remains authoritative even when the floor Scene is unloaded.
