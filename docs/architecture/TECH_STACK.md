# Technical Stack

## Fixed target

- Godot Engine 4.7.2.
- Mobile-first landscape application.
- GDScript is the default project language unless a measured hotspot or third-party extension justifies another language.

## Planned/evaluated dependencies

Dependencies are pinned only when introduced in an implementation phase.

- Terrain3D: preferred surface terrain candidate.
- LimboAI: preferred NPC/enemy behavior-tree + state-machine layer.
- Dialogue Manager: preferred deterministic branching dialogue layer.
- Universal LPC: character visual source/composition pipeline.
- GLoot: inventory candidate; evaluate before adoption rather than duplicating mature inventory primitives.

## Black Island-owned layers

- design-constrained island generator;
- logical world-cell/stud model;
- persistence and streaming orchestration;
- combat definitions/movesets/combos;
- transactional crafting queue;
- village/NPC social model;
- optional AI provider abstraction/social orchestrator;
- mine-floor generation/state/cache;
- Black Island Tools editor plugin;
- game-specific UI/UX and progression.

## Dependency rule

Third-party systems are implementation details behind game-owned interfaces. Game data must not become impossible to migrate because an addon owns the only representation of it.
