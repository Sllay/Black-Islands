# Black Island — Chapter 1 Production Plan

Three Seasons, four Phases each. Every phase ends in a playable increment.

## Season 1 — Foundation

### S1-P1 — Boot, repository, save shell, mobile shell
- Godot project in `game/`.
- boot flow and real Main scene.
- save-slot shell (4 slots).
- landscape-safe UI foundation.
- debug/test scene without polluting the production HUD.

### S1-P2 — World foundation
- volumetric voxel island data with smooth rendered terrain surface.
- first validated chunk/mesh/collision streaming profile on target mobile constraints.
- material/state painting foundation with smooth neighbor blending.
- separate integer-aligned `BuildGrid`/world occupancy foundation.
- constrained procedural island generation.
- seed + terrain-delta persistence foundation.
- player controller and gameplay camera baseline; first-person switch only if it does not endanger the phase.

### S1-P3 — Character/gameplay foundation
- initial compiled LPC catalog/import path and appearance composition/cache pipeline.
- LPC Sprite3D presentation tied to semantic player actions.
- inventory + 8-slot hotbar + inventory button.
- interaction targeting.
- combat baseline.
- at least one NPC and representative enemy behaviors.

### S1-P4 — First playable loop
- intro cutscene/attack.
- initial village survivors.
- gather/craft/build/farm minimums.
- first structural support/snap rules demonstrable in real gameplay.
- sleeping/day transition shell.
- Season 1 test scene demonstrates all foundation systems in gameplay form.

## Season 2 — Completion

### S2-P1 — Combat/progression
- weapon-defined classes/movesets.
- combo graph, hitstop, knockback and readable telegraphs.
- elements/reactions.
- level/XP and passive skill tree.

### S2-P2 — Village/NPC life
- jobs, skills, schedules.
- relationship graph and memory.
- Dialogue Manager integration.
- Social Director local-first events.
- optional LLM provider/orchestrator layer.

### S2-P3 — Caves/exploration
- separate cave-floor worlds.
- transition/preload/cache pipeline.
- destructible/procedural floor data.
- underground biome foundation.
- floor progression, encounters, rescue events and representative boss.

### S2-P4 — Production tools/content completion
- modular construction completion with support graph/collapse rules.
- robust transactional crafting queue.
- Black Island Tools editor surfaces for items/recipes/NPCs/cutscenes and validation.
- enough Chapter 1 content to run end-to-end.

## Season 3 — Polish

### S3-P1 — Performance
- mobile profiling.
- voxel/chunk/mesh/collision budget tuning.
- pooling, prop/foliage streaming, LOD/instancing.
- LPC cache/memory tuning.
- load-transition tuning.

### S3-P2 — UX/feel
- HUD polish, feedback, safe areas and responsive scaling.
- combat feel, camera, input, drag/drop and touch feedback.
- build-mode grid/socket/support feedback.

### S3-P3 — Reliability
- save migration/versioning.
- exploit/duplication regression tests.
- structure support/collapse regression tests.
- terrain-delta recovery/edge cases.

### S3-P4 — Chapter 1 RC
- bug burn-down.
- balance pass.
- credits/licenses.
- export/build validation.
- release-candidate checkpoint.
