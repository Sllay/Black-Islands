# ADR-0004 — Smooth Voxel World + Separate Structural Build Grid

Status: Accepted

## Decision

Black Island surface terrain is volumetric voxel data rendered as a smooth surface. Voxels are gameplay/storage samples, not visible cubes.

Initial world scale is now:

- terrain voxel spacing target: 0.5 m;
- BuildGrid cell: 1.0 m;
- project WorldChunk: 64 x 64 x 64 m;
- chunks exist on X/Y/Z, including vertical streaming.

Construction is not stored as terrain voxels. It uses a separate integer-aligned `BuildGrid`; pieces occupy cells, shared edges or point/center sockets.

Caves remain separate generated worlds and are not physically carved below the island.

## Why

This gives Black Island:

- precise digging/removal and predictable empty volume;
- smooth organic terrain rather than visible cubes;
- runtime terrain deformation;
- smooth material transitions;
- channels/holes/overhang potential;
- exact integer alignment between terrain and construction;
- clean separation of terrain, farming state and modular ARK-like structures.

## Important distinction

A 64 m WorldChunk is a project streaming/persistence/addressing unit, not one dense render mesh/data block.

At 0.5 m resolution it spans 128^3 sample positions. The voxel dependency subdivides it into smaller data/mesh/collision regions so local edits remain mobile-safe.

## Core invariants

1. A voxel is data, never one Godot Node.
2. Terrain presentation is chunked/batched smooth mesh.
3. Local terrain edits rebuild local internal blocks/borders, never the entire 64 m WorldChunk.
4. `BUILD_UNIT / VOXEL_SIZE` remains an integer.
5. Structure placement never uses visual mesh triangles as occupancy authority.
6. Walls occupy shared edges.
7. Structural support traces to real root provenance; connectivity alone is not support.
8. WorldChunks stream vertically as well as horizontally.
9. Untouched generated terrain should remain implicit/generator-backed where possible.
10. Farming crop/fertilizer/moisture state is a dedicated FarmPlot domain, not generic voxel metadata.

## Preferred implementation candidate

Zylann Voxel Tools is the preferred current candidate because it provides smooth SDF terrain, Transvoxel LOD, runtime editing, streaming, physics integration and instancing.

It remains wrapped behind Black Island interfaces and must pass Android/iOS export/performance tests. Architecture is not allowed to depend on one transient plugin scene layout.

## Material presentation

Logical material ownership/weights remain precise, while rendering blends compatible material boundaries using smooth weights/masks and controlled edge variation.

Paths can use terrain material painting.

FarmPlots use dedicated gameplay state/visual patches anchored to terrain/build cells.

## Persistence

Prefer:

`procedural seed/profile/version + edited voxel/data blocks + material edits + persistent entities`

rather than full dense world serialization.

## Detailed profile

See `docs/architecture/VOXEL_WORLD_IMPLEMENTATION.md` for mesh block, LOD, collision, streaming and benchmark strategy.
