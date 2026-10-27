# ADR-0004 — Smooth Voxel World + Separate Structural Build Grid

Status: Accepted

## Decision

Black Island surface terrain is volumetric voxel data rendered as a smooth surface. Voxels are gameplay/storage cells, not visible cubes.

Construction is not stored as terrain voxels. It uses a separate integer-aligned `BuildGrid` whose unit size is an integer multiple of voxel size. Structure pieces occupy cells, shared edges or point/center sockets according to their role.

Mines/caves remain separate generated floor worlds/scenes. They may use the same smooth-voxel principles internally, but are not physically carved beneath the surface island.

## Why

This gives Black Island:

- precise digging/removal and predictable empty volume;
- runtime terrain deformation without a blocky visual style;
- one material/state per voxel for farming, paths and terrain gameplay;
- smooth hills, coastlines and material transitions;
- future support for channels, holes, overhangs and more advanced terrain edits;
- deterministic integer alignment between terrain and construction;
- a clean separation between terrain topology and modular ARK-like structures.

## Core invariants

1. A voxel is data, never one Godot Node.
2. Terrain chunks generate batched meshes and collision.
3. Terrain edits dirty only affected chunks plus required border neighbors.
4. `BUILD_UNIT / VOXEL_SIZE` must be an integer.
5. Structure placement never relies on visual mesh coordinates as authoritative occupancy state.
6. Walls occupy shared edges, not duplicated per adjacent cell.
7. Structural support is graph-based and must trace to real support roots; connectivity alone is not support.
8. Remote/content updates may add data/assets but must not execute arbitrary code.

## Material presentation

Logical material ownership remains discrete per voxel, while rendering blends boundaries with neighboring materials. Neighbor topology, transition weights and controlled edge noise may be used to avoid visible square seams. Equal materials merge visually; different materials meet through smooth transition masks rather than a hard straight border whenever the material pair supports blending.

## Runtime terrain editing

Conceptual flow:

`tool/action -> terrain probe -> voxel edit operation -> mark local chunk dirty -> worker prepares new mesh data -> main thread applies mesh/collision -> persist delta`

The save stores the deterministic world seed plus terrain deltas/persistent mutations rather than a full copy of every unmodified voxel whenever practical.

## Construction relationship

Terrain answers questions such as surface height, solidity, slope and support contact. `BuildGrid` answers occupancy, snap and structural questions.

Examples:

- Foundation: occupies a build cell and requires valid ground/structural support.
- Wall/door/window wall: occupies one shared edge.
- Ceiling/platform: occupies a structural cell at an elevation and can extend horizontally within support rules.
- Pillar/post: occupies a point/center socket and can transmit support vertically when it reaches a valid support source.

Detailed rules live in `docs/design/BUILDING_AND_STRUCTURAL_SUPPORT.md`.

## Validation requirement

The exact voxel size, chunk dimensions, meshing implementation and mobile budgets remain benchmark decisions. The architectural decision is voxel-authoritative + smooth presentation, not a commitment to one library or fixed chunk size.
