# Technical Stack

## Fixed target

- Godot Engine 4.7.2.
- Mobile-first landscape application.
- GDScript is the default game-language unless a measured hotspot or native dependency justifies another language.
- Offline gameplay remains complete without external services.

## Planned/evaluated dependencies

Dependencies are pinned only when introduced and validated.

### Voxel Tools (Zylann)

Preferred terrain implementation candidate.

Current researched capability includes:

- Godot 4.7.2-era release/build support;
- GDExtension and custom-module editions;
- SDF smooth terrain;
- Transvoxel LOD;
- runtime edits;
- chunk streaming/threading;
- physics integration;
- voxel material channels;
- instancing.

Shipping choice between module/custom engine and GDExtension requires Android+iOS validation.

Terrain3D is no longer the primary Black Island surface strategy; ADR-0002 is superseded by ADR-0004.

### LimboAI

Preferred NPC/enemy behavior-tree + HSM execution layer, wrapped behind Black Island AI/domain state.

### Dialogue Manager

Preferred deterministic authored branching dialogue layer.

### Universal LPC

Character visual/content upstream source. Black Island compiles it into its own catalog; runtime does not depend on the LPC website implementation.

### Inventory libraries

Do not adopt a third-party inventory package if it conflicts with ADR-0006 multi-inventory transaction semantics.

A library such as GLoot may still be evaluated for useful storage/UI primitives, but `InventoryTransactionCoordinator`, ownership, revisions, craft scopes and anti-duplication rules remain Black Island authority.

### Water references

No water addon is shipping-locked.

Family Time is a behavioral reference only. Open-source Godot voxel/cellular water projects may be studied for algorithms, but Black Island owns `IWaterWorld`/WaterService and mobile performance rules.

## Black Island-owned layers

- constrained island generator;
- WorldChunk/stream orchestration around voxel dependency;
- BuildGrid/shared edges/support solver;
- sparse dynamic water/hydrology service;
- deterministic biome/prop/foliage generation;
- FarmPlot lifecycle;
- player motor/camera/interaction;
- LPC compiler/catalog/composer/cache;
- authoritative inventory transaction coordinator;
- crafting/workstation/container scopes;
- combat definitions/movesets/combos/skills/Ultimates;
- mob ecology/corpse/loot state;
- NPC social model;
- CaveRun + persistent anchor/elevator systems;
- optional AI provider/social orchestrator;
- Black Island Tools editor plugin;
- game-specific UI/UX/progression.

## Dependency rule

Third-party systems are implementation details behind project-owned interfaces.

Save files and gameplay definitions must remain migratable if an addon is replaced.
