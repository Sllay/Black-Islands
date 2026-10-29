# ADR-0004 — RC0 platform, world, foliage and persistence baseline

Status: Accepted for S01-RC0 planning

## Context

S01-P00 through P04 proved the playable foundation but also exposed prototype decisions that should not become Season 2 dependencies: scripted voxel generation, custom foliage patches, player-owned world snapshots, no production main menu/settings flow, placeholder structure scale/HP, provisional mob AI, and no explicit rendering-quality architecture.

## Decisions

### Rendering has two independent axes

1. **Renderer backend**: Forward+ desktop, Mobile, or Compatibility (`gl_compatibility`). This is startup/export-level and is not treated as a safe hot-swappable runtime quality toggle.
2. **Quality preset**: Low / Medium / High, data-driven and runtime-applicable where the underlying renderer supports the requested feature.

Compatibility is a real supported fallback target, not merely a debug mode.

### World and player saves are independent identities

A world is not the owner of a character. A character can later enter multiple worlds/servers, and a world may host multiple characters.

World-owned state and player-owned state are persisted separately with versioned migrations.

### World generation uses native Voxel Tools graph execution

Production base SDF generation moves from per-voxel GDScript `VoxelGeneratorScript` hot loops to `VoxelGeneratorGraph` where expressible. GDScript orchestrates profiles/seed/metadata and sparse delta persistence rather than producing the entire base voxel field one sample at a time.

### Chapter 1 world profile becomes versioned data

The current ~480×420 m prototype is not the production scale. RC0 targets roughly four times the current land area as an initial baseline (~2× linear dimensions), with exact dimensions profile-driven and validated rather than permanently hardcoded.

Terrain uses smooth SDF geometry while respecting logical elevation bands for generation/gameplay constraints.

### Natural foliage uses VoxelInstancer

Grass and other high-count natural surface detail prefer VoxelInstancer/MultiMesh presentation with LOD/fading and shader animation. Gameplay identity remains project-owned for harvestable/persistent resources.

### AI orchestration uses LimboAI

Pin LimboAI v1.8.1 for the Godot 4.7.2 baseline. Domain state remains project-owned. LimboAI decides intent; a separate locomotion/navigation layer executes movement.

### Validation is checkpointed

RC0 is split into R1 (UI/player/building/AI/persistence) and R2 (world/render/foliage/streaming). Each checkpoint gets focused tests + one runtime proof + push. Historical full-suite repetition is avoided unless touched code requires it.

## Consequences

- Season 2 begins only after RC0 R1/R2 acceptance.
- Existing development saves may require one documented migration/reset during RC0.
- Renderer backend changes may require restart/export selection; quality changes are staged and applied safely.
- Foliage density is improved through instancing/LOD, not by reducing the intended visual coverage to hide a poor implementation.
