# Black Island — Chapter 1 Production Plan

Three Seasons, four Phases each. Every phase ends in a playable increment.

## Season 1 — Foundation

### S1-P1 — Boot, repository, save shell, mobile shell
- Godot project in `game/`.
- boot flow and real Main scene.
- save-slot shell (4 slots).
- landscape-safe UI foundation.
- debug/test scene without polluting production HUD.

### S1-P2 — World first
- integrate/validate smooth volumetric voxel terrain path.
- initial 0.5 m voxel / 64 m WorldChunk profile.
- vertical chunk streaming and 3x3 horizontal near ring.
- smooth meshing, collision and LOD benchmark on mobile.
- terrain material blending/painting foundation.
- separate 1 m BuildGrid coordinate foundation.
- deterministic island generator baseline: beach/plains/forest/elevation.
- ocean + basic generated water body foundation.
- seed + terrain-delta persistence.
- world boundary/horizon prototype.

Deliverable: a real navigable generated island streaming correctly before character/content complexity is piled on.

### S1-P3 — Player second
- CharacterBody3D PlayerMotor on smooth voxel slopes.
- angled exploration/combat camera.
- third-person Build Mode camera transition.
- LPC compiled catalog/import proof + composed Sprite3D player.
- semantic LPC animation/action bridge.
- interaction targeter baseline.
- 20-slot inventory + 8 hotbar + equipment shell.
- combat baseline: normal/heavy direction + dodge.

Deliverable: the player can traverse, target, interact and fight/test on the real generated world.

### S1-P4 — Ecology/gameplay surface third
- biome prop generation/streaming baseline.
- grass/foliage suppression and regrowth.
- trees/rocks/representative harvesting.
- FarmPlot, watering and one crop loop.
- first modular foundation/wall/ceiling/pillar support rules.
- chest/container + safe transaction foundation.
- one passive/neutral/aggressive representative mob behavior.
- corpse/loot/drop-bag baseline.
- opening survivors/intro slice where scope permits.

Deliverable: Season 1 test scene/game proves world -> player -> props/farming -> mob/loot interaction as real gameplay.

## Season 2 — Completion

### S2-P1 — Combat/progression
- full weapon-defined movesets/combos.
- heavy attack variants.
- Skill + boss-derived Ultimate systems.
- guard/parry weapon packages.
- hitstop, knockback, stagger and telegraphs.
- elements/reactions.
- XP/passive progression.

### S2-P2 — Village/NPC life
- Farmer/Explorer/Miner opening roles.
- jobs, skills and schedules.
- relationship graph and memory.
- Dialogue Manager integration.
- Social Director local-first events.
- village shops/economy baseline.
- optional LLM provider/orchestrator layer remains non-authoritative.

### S2-P3 — Caves/exploration
- ephemeral CaveRun floor generation.
- preload/spawn-envelope transition pipeline.
- Standard/Darkness/Luminous-Forest biome content.
- floor difficulty/resources/enemies.
- rare CaveAnchorTotem progression.
- persistent anchored floor data.
- elevator network.
- representative boss/Ultimate reward.

### S2-P4 — Production tools/content completion
- modular structure catalog completion.
- workstation + nearby chest crafting scopes.
- robust transactional five-slot crafting queue.
- character creator/wardrobe content integration.
- Black Island Tools editor surfaces for items/recipes/structures/crops/NPCs/mobs/biomes/cutscenes and validation.
- enough Chapter 1 content for end-to-end loop.

## Season 3 — Polish

### S3-P1 — Performance
- target-mobile profiling.
- voxel/chunk/mesh/collision budgets.
- water active-cell budgets.
- prop/foliage streaming, LOD and instancing.
- LPC cache/memory tuning.
- NPC/mob update budgets.
- sustained thermal/traversal testing.

### S3-P2 — UX/feel
- HUD/inventory safe-area polish.
- combat feel and touch tuning.
- camera/obstruction polish.
- build grid/socket/support feedback.
- drag/drop/quantity transfer/container UX.
- water/swimming/current feedback.

### S3-P3 — Reliability
- save migrations/versioning.
- inventory/craft/container exploit fuzz/regression tests.
- support/collapse regression tests.
- terrain-delta recovery.
- cave anchor/run lifecycle edge cases.
- LPC catalog migration/credit validation.

### S3-P4 — Chapter 1 RC
- bug burn-down.
- balance/content pass.
- credits/licenses.
- mobile export/build validation.
- release-candidate checkpoint.
