# Open Design Checklist

This list contains the remaining design/technical decisions or implementation validations after the current world/player systems lock.

## P0 — world foundation validation

### 1. Voxel Tools mobile proof

Architecture/profile is now defined in `VOXEL_WORLD_IMPLEMENTATION.md`:

- 0.5 m terrain voxel target;
- 1 m BuildCell;
- 64 m cubical project WorldChunks;
- vertical chunking;
- 3x3 horizontal near ring;
- smaller internal mesh/data blocks;
- smooth SDF/Transvoxel direction.

Still required:

- choose Module/custom Godot build vs GDExtension shipping path;
- Android + iOS export validation;
- benchmark 32-vs-16 voxel mesh blocks;
- final LOD distances;
- collision update delay/budget;
- edit latency target;
- hard terrain-memory budget;
- terrain delta compaction benchmark.

### 2. Water implementation proof

Behavior/architecture is defined in `WATER_AND_HYDROLOGY.md`.

Still required:

- prototype sparse active water grid;
- choose exact amount precision/cell layout;
- benchmark 10/15/20 Hz simulation;
- sleeping/stability thresholds;
- river macro-flow integration;
- waterfall mesh/VFX implementation;
- current-force tuning;
- save/unload behavior under unsettled water;
- mobile quality tiers.

### 3. Island physical profile

Once PlayerMotor sustained movement speed is playable:

- derive island diameter for 20-30 minute direct traversal target;
- determine coast width;
- plains/forest/elevation proportions;
- village candidate constraints;
- travel corridor density;
- world soft-boundary radius/hard-boundary radius;
- validate distant ocean/decorative-island horizon.

### 4. Island generation algorithms/content

Architecture exists, but still needs concrete generator parameters for:

- coast shape;
- broad hills/ridges;
- river/lake count/placement;
- beaches;
- forest clearings;
- biome masks;
- POIs;
- village/initial spawn;
- cave entrance;
- generator validation/retry budget.

## P0 — player foundation

### 5. PlayerMotor tuning

Camera direction is locked: angled gameplay + third-person Build Mode, no baseline first-person.

Still tune:

- acceleration/deceleration;
- base walk/run speeds;
- max slope;
- step/snap values;
- falling;
- swim movement;
- current resistance;
- stamina regeneration/tool costs;
- camera pitch/yaw/distance/FOV vs orthographic trial;
- obstruction fade thresholds;
- mobile joystick response/dead zones.

### 6. InteractionTargeter

Define exact priority/selection policy among:

- combat target;
- NPC;
- corpse;
- death/drop bag;
- door/workbench/chest;
- crop/FarmPlot;
- harvestable prop;
- structure socket;
- terrain voxel;
- water.

Need contextual target cycling/aim assist rules for touch.

## P1 — world ecology/content

### 7. Resource gathering

Technical system still needs concrete rules for:

- tree HP/progress;
- rock/ore-vein HP/progress;
- tool tag/tiers;
- stamina costs;
- hit feedback;
- stump/remnant policy;
- regrowth timing;
- surface resource rarity;
- cave ore tables;
- interaction between prop resources and destructible voxel ore/terrain.

### 8. Prop content tables

Biome generator architecture is locked. Need actual Chapter 1 content definitions/densities for:

- coastal props;
- plains props;
- forest props;
- trees;
- bushes/flowers;
- rocks;
- resource nodes;
- cave crystals/mushrooms/trees;
- rare props/POIs.

### 9. Farming content/balance

FarmPlot lifecycle is locked. Need:

- Chapter 1 crop/seed list;
- exact growth days;
- yield tables;
- seed prices/economy;
- fertilizer items/tier values;
- rain intensity thresholds;
- whether specific crops tolerate dryness differently;
- seasons if Chapter 1 uses them.

### 10. Weather/day-night

Need dedicated pass for:

- day length;
- rain/storm scheduling;
- cloud/lighting transitions;
- heavy-rain farming effects;
- night mob state changes/spawns;
- save/time progression;
- weather impact on water where practical.

## P1 — building/content

### 11. Structure catalog

Support rule is locked at baseline two-cell reach from real grounded support provenance.

Need actual Chapter 1 pieces:

- foundations;
- ceilings/platforms;
- walls;
- door frames/doors;
- window walls;
- pillars;
- stairs/ramps;
- roofs if in Chapter 1;
- workbench/chests;
- costs, HP and repair values;
- collapse debris/refund rules.

Wood vs stone changes durability/cost/visual, not support reach.

### 12. Build Mode feedback

Need final:

- grid rendering;
- socket highlights;
- valid/invalid ghost language;
- invalid reason cue;
- support-root visualization/debug mode;
- rotation controls;
- demolish preview;
- mobile placement gestures.

## P1 — inventory/economy

### 13. Remaining inventory UX

Core values are locked: 20-slot 5x4 player inventory, 8 hotbar, five equipment slots and stack defaults.

Still decide:

- backpack upgrade curve;
- chest slot counts/tier progression;
- sort/filter/search;
- valuable-item drop confirmation;
- exact responsive dual-pane layout;
- quick transfer direction rules when >2 valid containers exist;
- container naming/ownership UI.

### 14. Crafting content

Transaction/queue behavior is locked, including permanent downward clamp and timer reset on load/reorder.

Still define:

- player-vs-workbench recipe sets;
- workstation logistics radius;
- output destination priority details per station;
- recipe unlock progression;
- recipe migration tests;
- transaction stress/fuzz tests for anti-duplication.

### 15. Currency/economy

Need wallet/currency sources/sinks, Farmer shop behavior, prices and village economy integration.

## P1 — combat

### 16. Weapon/moveset content

Combat architecture is locked. Need concrete Chapter 1 definitions for:

- sword;
- axe/combat axe if applicable;
- hammer/mace;
- daggers;
- bow;
- staff/wand;
- guarded weapon/shield packages;
- normal/heavy combo graphs;
- weapon skills;
- cooldowns/resource costs.

### 17. Ultimate system content

Need:

- boss Ultimate drop/unlock probability/rules;
- equip UX;
- charge/cooldown model;
- first Chapter 1 Ultimates;
- boss stagger exceptions.

### 18. Combat feel validation

Tune:

- dodge distance/i-frames;
- parry window;
- guard arc/damage reduction/break recovery;
- hitstop;
- knockback/stagger;
- aim assist;
- heavy-aim hold threshold;
- mobile button layout/input buffering.

## P1 — mobs/loot

### 19. Mob content definitions

Disposition framework is locked. Need concrete mob list and rules:

- passive fauna;
- defensive passive fauna;
- territorial neutrals;
- night aggressors;
- pack-threshold aggressors;
- cave biome pools;
- boss profiles.

### 20. Corpse/loot balance

Need exact:

- decomposition durations;
- knife/axe/sword harvest ratios;
- meat/hide/etc. yields;
- delicate loot tables;
- death-bag lifetime/persistence;
- player death inventory rules;
- drop-bag merge/cleanup rules.

## P1 — caves

### 21. Cave generation

Lifecycle/biomes/anchor progression are defined. Need:

- floor topology generator;
- descent placement rules;
- difficulty/depth curve;
- ore tables;
- standard/darkness/luminous biome frequency;
- boss/special floor scheduling;
- run reset trigger details;
- hot-cache memory budget.

### 22. Cave anchor totem

Need:

- final player-facing name;
- recipe/drop/source;
- rarity;
- placement requirements;
- whether activated anchors can be destroyed;
- elevator construction/UX/cost.

## P1 — LPC/player presentation

### 23. LPC pipeline implementation + profiling

Architecture is locked in `LPC_PIPELINE.md`; still implement/test:

- upstream compiler;
- stable catalog schema;
- aliases/migration;
- compatibility matrix;
- custom/oversized clips;
- recolor composer;
- credit/license registry;
- live catalog/deltas;
- cache memory limits.

### 24. Character creator visual UX

Layout/category behavior is defined. Still need:

- final tab icons/order;
- thumbnail style/cache limit;
- name length/validation;
- clothing unlock presentation;
- community-upload eligibility threshold;
- final wardrobe restrictions.

### 25. Name generation

Create large initial first-name/surname pools behind `NameGenerator` interface.

Later add syllabic generator without changing NPC identity callers.

## P1 — village/NPC systems

### 26. Initial survivor implementation

Lock detailed content for:

- Farmer (seed supply/shop/tutorial);
- Explorer/Adventurer;
- Miner (opening can fail/die);
- opening rescue timing/failure state;
- impact of Miner death on early economy/tutorial.

### 27. Jobs/economy/relationships

Existing NPC architecture still needs concrete Chapter 1 job loops, schedules, skill progression and social content.

## P2 — presentation/technical

### 28. Final art/render profile

Direction is cartoon/pixel-art hybrid. Still lock:

- terrain shader palette/materials;
- lighting/environment settings;
- shadow distance/resolution;
- LPC texture filtering;
- outline/highlight shader;
- VFX density;
- day/night color treatment;
- mobile renderer/quality presets.

Foliage should use mipmaps with alpha-test coverage preservation and primarily alpha-scissor/cutout where art permits.

### 29. Mobile performance budgets

Set hard budgets after first integrated benchmark:

- total memory;
- voxel data;
- terrain mesh/collision;
- foliage instances/draw calls;
- LPC texture cache;
- active mobs/NPCs;
- water active cells;
- frame time/worker/main-thread integration;
- thermal sustained test.

### 30. Save schema/migration

Need formal schema versions/migrations for:

- world voxel deltas;
- inventory stacks;
- structures/support graph reconstruction;
- FarmPlots;
- cave anchors;
- LPC appearance IDs;
- NPC identities.

### 31. Future networking/tribes/community

Not Chapter 1 core.

Keep ownership and inventory transactions compatible with future authoritative server/host, tribe containers/structures, PvP/raids and community appearance service.

## Substantially locked

Do not reopen casually without an ADR/design revision:

- Godot 4.7.2;
- `game/` project root;
- smooth volumetric voxel terrain;
- 0.5 m terrain voxel / 1 m build-cell initial scale;
- 64 m cubical WorldChunk addressing including vertical chunks;
- separate build grid/shared edges/sockets;
- two-cell baseline horizontal support from real roots with provenance inheritance;
- wood/stone durability differs but structural reach does not;
- unsupported structure collapse with alternate-root recomputation;
- angled gameplay camera + third-person Build Mode; no baseline first person;
- dynamic sparse local water architecture;
- FarmPlot as dedicated state rather than crop state inside terrain voxel;
- biome-driven deterministic prop generation/suppression;
- 20-slot inventory / 8 hotbar / 5 equipment slots;
- atomic multi-inventory transaction coordinator;
- per-unit five-slot craft queue;
- cave floors ephemeral by default, persistent only through progression anchors;
- mob disposition + corpse harvesting/death-bag model;
- normal/heavy/skill/Ultimate/dodge/guard-parry combat architecture;
- LPC catalog/composition architecture;
- game remains fully functional offline.
