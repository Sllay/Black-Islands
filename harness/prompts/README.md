# Black Island — Codex Execution Prompts

These prompts are deliberately sequential. Do not hand Codex all five as one giant task.

## Order

1. `S01-P00-bootstrap.md`
   - prepare toolchain/repository/validation;
   - research/pin voxel integration candidate;
   - refresh compact phase context packets;
   - no gameplay implementation.

2. `S01-P01-boot-shell.md`
   - real Godot boot flow;
   - four save slots;
   - mobile landscape/safe-area foundation;
   - production HUD shell;
   - debug/test scene.

3. `S01-P02-world-foundation.md`
   - smooth volumetric voxel world;
   - 0.5 m voxels / 64 m WorldChunks / vertical streaming;
   - deterministic island;
   - material/edit proof;
   - 1 m BuildGrid foundation;
   - save delta/ocean/world-boundary proof.

4. `S01-P03-player-foundation.md`
   - real PlayerMotor on generated world;
   - angled gameplay + third-person Build camera;
   - LPC composed Sprite3D proof;
   - targeter;
   - 20-slot inventory / 8 hotbar shell;
   - normal/heavy/dodge combat baseline.

5. `S01-P04-ecology-gameplay-surface.md`
   - biome props/foliage;
   - generic ARK-inspired harvesting;
   - one crop farming loop;
   - modular foundation/wall/ceiling/pillar support;
   - safe chest transactions;
   - representative mobs/corpses/drop bags;
   - integrated Season 1 playable slice.

## Gate rule

Do not start part N+1 until part N has:

- acceptance criteria checked;
- regressions checked;
- `harness/build/...` handoff/log updated;
- validated commit pushed;
- compact handoff produced.

If a phase exposes an architectural blocker, stop at the smallest reproducible evidence, document it, and resolve/ADR it before building later systems on a false assumption.

## Context discipline

Each prompt tells Codex what to read. Follow progressive disclosure from `AGENTS.md`; do not preload every design document into every phase.

## Art rule

Placeholder meshes/materials/UI are acceptable during Season 1 when the system contract is preserved. A phase is not complete if only backend scripts exist: each part must finish with a real playable/testable increment.