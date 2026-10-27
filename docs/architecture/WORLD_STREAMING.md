# World, Terrain and Streaming Architecture

## Surface world

Accepted model:

- authoritative volumetric voxel terrain data;
- smooth generated terrain mesh rather than visible block cubes;
- material/state stored per voxel or compact voxel record;
- separate Black Island `BuildGrid` aligned by an integer ratio to voxel size;
- separate navigation/simulation data derived from world state rather than using render geometry as authority.

The previous Terrain3D/heightmap-first direction is superseded by `ADR-0004-smooth-voxel-world-and-build-grid.md`.

## Terrain chunks

A voxel is data, never a Node. Chunks own compact voxel storage and produce batched mesh/collision presentation.

Candidate chunk dimensions and voxel scale remain benchmark decisions. Never lock a chunk size merely because it is conventional.

Runtime edit flow:

`action/tool -> terrain probe -> edit density/material -> dirty affected chunk(s) -> background-safe mesh-data preparation where supported -> main-thread scene/physics apply -> persistent terrain delta`

Edits at chunk boundaries must dirty all neighboring chunks needed to rebuild a seamless surface.

## Smooth material presentation

Logical material ownership is discrete, but material boundaries should not normally render as square seams.

The visual layer may combine:

- neighboring voxel material weights;
- topology/auto-tile-like neighborhood classification;
- smooth transition masks;
- controlled edge noise/distortion;
- material-specific blend rules.

Equal materials visually merge. Different compatible materials transition softly across their shared boundary while gameplay remains cell-precise.

Examples include grass-to-path, grass-to-tilled-soil, dry-to-wet soil and biome material transitions.

## Farming and local painting

Hoe/path/farming actions target the authoritative terrain cell/voxel surface. A gameplay action may change a material/state without changing terrain density.

Examples:

- `GRASS -> TILLED_DRY`
- `TILLED_DRY -> TILLED_WET`
- `GRASS -> PATH_DIRT`

The renderer updates only the local terrain region required by the material change.

## Save model

World generation is deterministic from a seed. Prefer saving:

`generated base(seed) + terrain/material deltas + persistent object/world state`

rather than serializing every unchanged voxel.

The delta format must support compaction/migration because long-running saves may accumulate many edits.

## Island generation pipeline

`Seed -> IslandProfile -> base island volume/mask -> macro elevation -> coast shaping -> hills/mountains -> hydrology -> biome allocation -> village candidates -> POIs/resources -> prop/vegetation pass -> validation -> accepted world`.

`IslandProfile` constrains valid river/lake arrangements before generation so noise does not dictate design.

## Village placement

Candidate scoring considers at least buildable area, flatness/slope, water proximity, dangerous terrain, cave/POI spacing and required expansion room.

## Biomes and props

The surface island will support biome-driven terrain materials, vegetation and prop generation. Exact prop generation, foliage suppression/regrowth, biome transition rules and object persistence are not yet locked and are tracked as an open design task.

The architecture must support larger future islands with multiple major/minor biomes without requiring a world-format rewrite.

## Runtime streaming

Separate:

- **data layer** — voxel chunks, persistent entities, biome/prop data;
- **presentation layer** — terrain meshes, foliage instances, props, VFX;
- **simulation layer** — NPC/world simulation state independent of whether presentation is loaded.

Worker threads may generate/decode/prepare pure data. SceneTree mutations and unsafe engine interactions are applied on the main thread.

Avoid churn from creating/freeing thousands of Nodes. Use pooling and batched/instanced presentation for repeated objects where appropriate.

## Construction relationship

`BuildGrid` is integer-aligned to terrain but independent from terrain voxels. Foundations/cells, shared wall edges, ceilings/platforms and support sockets live in the building domain. Terrain supplies solidity/height/contact information.

Detailed structural rules live in `docs/design/BUILDING_AND_STRUCTURAL_SUPPORT.md`.

## Mines / cave floors

The mine/cave is not physically carved under the island as one continuous underground world. Each floor is a separate generated world state/scene and may contain its own underground biomes, voxel terrain, props and lighting rules.

Flow:

`surface cave portal -> dark transition -> preloaded spawn envelope -> CaveFloor N -> stream remaining sectors`.

Near a descent/return portal, begin preloading the destination spawn envelope. If not ready when crossing, hold the masking/loading transition until the destination is safe to reveal.

Maintain a small hot cache of adjacent/recent floors when memory budget permits.

`MineFloorData` remains authoritative even when the floor Scene is unloaded, including destroyed terrain/cells, containers, special NPCs, important enemies, exits, POIs and events.
