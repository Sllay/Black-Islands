# Open Design Checklist

This list contains the remaining design decisions and, increasingly, **implementation validations** after the current world/player/ecology lock.

Many formerly open architecture questions are now documented. Do not reopen a locked system casually just because implementation has not started yet.

## P0 — World implementation validation

### 1. Voxel Tools mobile proof

Architecture is defined in `VOXEL_WORLD_IMPLEMENTATION.md`.

Codex must implement/profile:

- Godot 4.7.2 integration path (GDExtension/module decision);
- Android + iOS export validation;
- 16-vs-32 voxel mesh/data block benchmarks;
- LOD/ring distances;
- collision regeneration delay/budget;
- edit latency;
- terrain memory budget;
- delta persistence/compaction.

### 2. Water simulation proof

Architecture is defined in `WATER_AND_HYDROLOGY.md`.

Need implementation benchmarks for:

- sparse active-cell water grid;
- 10/15/20 Hz simulation targets;
- sleep/stability thresholds;
- river macro flow;
- waterfall renderer;
- current force on player/mobs;
- unsettled-water save/unload;
- mobile quality tiers.

### 3. Island physical scale

After PlayerMotor speed exists, derive physical island diameter from the desired roughly 20–30 minute traversal feel.

Need tune:

- actual direct-line traversal target;
- coast width;
- settlement spacing;
- village/cave/POI distances;
- soft/hard world boundary radii;
- horizon ocean/decorative distant islands.

### 4. Procedural island generator parameters

Architecture/biome content direction exists. Still implement/tune:

- coastline morphology;
- river/lake profile constraints;
- tropical plains/hills/forest distribution;
- village candidate scoring;
- cave entrance/POIs;
- validation/retry budget;
- deterministic prop integration.

## P0 — Player implementation

### 5. PlayerMotor/camera tuning

Locked camera model: angled gameplay + third-person Build Mode.

Need test/tune:

- movement acceleration/deceleration;
- walk/run speeds;
- stamina behavior;
- slope/step/ground snapping;
- swimming/current response;
- camera pitch/distance/FOV vs orthographic-style trial;
- obstruction fading;
- mobile joystick dead zones/response.

### 6. InteractionTargeter

Need implement/test priority among:

- combat target;
- NPC;
- corpse;
- DeathBag/WorldDropBag;
- door/chest/workbench;
- FarmPlot;
- harvestable prop;
- structure/socket;
- terrain voxel;
- water.

Touch aim assist/target cycling still needs gameplay validation.

## P1 — Resource/farming content tuning

### 7. Harvest content values

Architecture is locked in `HARVESTING_AND_RESOURCES.md` and ARK research is captured.

Need actual content data:

- tree/rock/ore harvest health;
- deterministic resource reserve ranges;
- axe/pickaxe/knife harvest power;
- tool-quality curves;
- stamina/durability costs;
- regrowth/respawn durations;
- cave ore tables;
- stump/remnant rules.

### 8. Farming content

FarmPlot lifecycle is locked. Need:

- Chapter 1 crops/seeds;
- growth days/stages;
- yields/prices;
- fertilizer items/multipliers;
- exact rain saturation threshold;
- dry-crop tolerance if any;
- crop visuals.

## P1 — Ecology/mobs

### 9. Offscreen simulation benchmark

Architecture is locked in `WORLD_ECOLOGY_AND_OFFSCREEN_SIMULATION.md`.

Need measure:

- Active/Proxy/Regional/Stasis distances and update rates;
- mob pool sizes;
- logical population cap;
- wake/despawn latency;
- zombie RegionGraph migration cost;
- Boids flock/school counts and update frequency.

### 10. Initial mob stats/content

Initial fauna/enemy list is defined in `INITIAL_MOBS_AND_RESOURCES.md`.

Need actual definitions for:

- Cow;
- Pig;
- Chicken;
- Rabbit;
- fish visual variants;
- Skeleton;
- Zombie;
- first neutral/territorial creature(s);
- first cave mob sets;
- corpse decomposition durations;
- exact harvest/loot values;
- XP/level curves per family.

### 11. Raid progression

Need concrete progression for:

- opening scripted assault;
- first systemic 5–10 zombie raid baseline;
- population-heat attraction;
- raid warning/telegraph;
- later difficulty/quantity scaling.

## P1 — Weather/time

### 12. Weather balance + implementation

Architecture is locked in `WEATHER_DAY_NIGHT_AND_FIRE.md`.

Need tune:

- 16-minute day / 6-minute night play feel;
- weather frequency/duration;
- thunderstorm/lightning rate;
- tree ignition/spread probabilities;
- rain/water coupling;
- exact charred-tree charcoal yield;
- day/night lighting transitions.

## P1 — Building/content

### 13. Structure catalog/costs

Tier/HP baseline is locked in `STRUCTURE_TIERS_AND_LARGE_BUILDS.md`:

`Thatch 5k -> Wood 8k -> Stone 12k -> Darkstone 16k -> Scrap 22k -> Iron 30k` base HP.

Need concrete Chapter 1 definitions/costs for:

- foundation;
- ceiling/platform;
- wall/window/doorframe/door;
- pillar;
- stairs/ramps;
- roof variants;
- chest/workbench;
- large village wall/gate blueprint;
- repair/refund/collapse debris rules.

### 14. Large ConstructionSite gameplay

Architecture is defined. Need tune:

- work-unit values;
- player work rate;
- Builder NPC rate;
- helper scaling/diminishing returns;
- cancellation/destruction refund policy;
- UI/progress feedback.

### 15. Build Mode UX

Need final:

- grid rendering;
- socket highlight;
- ghost colors;
- invalid reason feedback;
- support debug/preview;
- rotation/demolition gestures.

## P1 — Inventory/crafting/economy

### 16. Remaining inventory UX

Core inventory/transaction rules are locked.

Need:

- backpack upgrade curve;
- chest sizes/tiers;
- sort/filter/search;
- valuable-item drop confirmation;
- responsive phone/tablet layout;
- quick-transfer behavior with several containers.

### 17. Crafting content

Need:

- player recipe set;
- workstation recipe sets;
- workstation logistics radius;
- unlock progression;
- recipe costs/times;
- stress/fuzz transaction tests.

### 18. Currency/economy

Need actual wallet economy:

- currency name/source/sinks;
- Farmer seed prices;
- Vendor stock/prices;
- Blacksmith services;
- NPC production/trading loops.

## P1 — Combat

### 19. Weapon numerical balance

Family identities/combo concepts are locked in `WEAPON_FAMILIES_AND_COMBOS.md` for:

- Sword;
- Daggers;
- Club/Mace;
- Axe;
- Hammer;
- Bow.

Need implementation/content values:

- damage;
- timing;
- stamina/resource costs;
- knockback/stagger;
- combo windows;
- Skills;
- elemental/common/rare weapon examples.

### 20. Combat feel

Need gameplay tuning:

- Dodge distance/i-frames;
- parry window;
- guard arc/reduction/break;
- hitstop;
- heavy aim threshold;
- aim assist;
- input buffer/cancel timing.

### 21. Defense/level curves

Baseline diminishing-return Defense formula and stat architecture are documented in `COMBAT_STATS_AND_LEVEL_SCALING.md`.

Need playtest:

- ordinary mob HP level curve;
- damage curve;
- Defense distribution;
- boss profiles;
- whether 100 Defense = 50% mitigation anchor produces desired pacing.

### 22. Ultimate content

Need:

- boss Ultimate unlock/drop rules;
- first boss Ultimates;
- charge/cooldown model;
- equip UX.

## P1 — Caves

### 23. Cave generator implementation

Biome/lifecycle direction is locked:

- Standard Cave;
- Darkness;
- Luminous Forest;
- unanchored procedural rerolls;
- Totem of Anchoring persistence.

Need implement/tune:

- topology;
- biome field scoring/frequencies;
- ore/resource tables;
- Floor 1 save-creation preload;
- Floor N+1 prefetch;
- descent placement;
- difficulty/depth curves;
- hot-cache budget.

### 24. Totem of Anchoring economy

Name/lore/progression role are locked.

Need:

- recipe/drop source;
- rarity;
- placement/activation cost;
- destruction policy;
- elevator construction and UX.

## P1 — LPC/characters/NPC content

### 25. LPC pipeline implementation

Architecture remains to be implemented/profiled:

- upstream compiler;
- catalog schema;
- alias migration;
- compatibility matrix;
- oversized/custom animations;
- recolor composer;
- license/credit registry;
- live catalog/deltas;
- mobile cache limits.

### 26. Character creator production UX

Architecture exists. Need final visual implementation:

- icons/tab order;
- thumbnails/cache;
- name input validation;
- wardrobe unlock UI;
- random/community appearance thresholds.

### 27. Name dataset

Architecture is locked in `NPC_NAMES_AND_JOBS.md`.

Codex/subagent task later:

- generate ~1,000 validated NameToken entries;
- normalize/deduplicate;
- mark first/surname eligibility;
- profanity/content validation;
- add tests;
- preserve future SyllabicNameProvider plug-in seam.

### 28. NPC jobs/economy

Initial job families are defined:

- Farmer;
- Miner;
- Blacksmith;
- Vendor;
- Adventurer/Explorer;
- Gatherer;
- Builder.

Need concrete schedules/task loops/skill curves/economy and opening survivor content.

## P2 — Presentation

### 29. Technical art profiling

Direction is locked in `VISUAL_RENDERING_DIRECTION.md`.

Need device tests for:

- Mobile renderer;
- directional shadow profile;
- alpha-scissor foliage + alpha-to-coverage/mipmap coverage;
- LPC filtering;
- contextual outline approach;
- Luminous Forest emissive/light budget;
- storm/water VFX;
- dense village/forest benchmark scenes.

## P2 — Save/reliability

### 30. Save serialization implementation

Architecture is locked in `SAVE_AND_MIGRATION.md`.

Codex must choose/test:

- serialization format;
- atomic file replacement on iOS/Android;
- chunk delta encoding/compaction;
- backup/recovery;
- migration registry;
- active CaveRun resume data;
- fuzz/crash tests around inventory transaction boundaries.

## P2 — Mobile performance budgets

### 31. Hard budgets

Only integrated prototypes can establish final:

- memory ceiling;
- terrain/mesh/collision memory;
- LPC texture cache;
- active mob count;
- water cells;
- foliage/draw calls;
- worker/main-thread frame budget;
- sustained thermal performance.

## P3 — Future networking/tribes/community

Not Chapter 1 core.

Keep ownership/transaction architecture compatible with:

- tribe-owned structures/containers/NPCs;
- server-authoritative transactions;
- PvP/raids;
- community appearance service;
- larger streamed worlds.

## Substantially locked

Do not reopen casually without a design revision/ADR:

- Godot 4.7.2 / `game/` project root;
- voxel-authoritative smooth terrain;
- 0.5 m terrain voxel / 1 m BuildCell;
- 64 m cubical WorldChunk addressing including vertical;
- surface generated once per save + deltas;
- square build grid/shared edges/sockets;
- two-cell real-root support provenance;
- structural material changes durability, not support reach;
- Thatch/Wood/Stone/Darkstone/Scrap/Iron progression;
- unsupported collapse with alternate-root recomputation;
- large structures use paid ConstructionSites/work progress;
- angled gameplay + third-person Build Mode;
- sparse dynamic water architecture;
- FarmPlot state model;
- ARK-inspired generic harvest architecture with finite reserves;
- deterministic surface biome/prop model and initial biome families;
- 16m day? No: baseline is 16 real minutes of dawn/day/dusk + 6 minutes night;
- rain/thunderstorm/lightning/charred-tree direction;
- Boids for fish/bird visual groups;
- tiered offscreen mob simulation;
- 20-slot inventory / 8 hotbar / 5 equipment;
- atomic multi-inventory transaction coordinator;
- per-unit five-slot craft queue;
- Standard/Darkness/Luminous Forest cave families;
- ephemeral CaveRuns + Totem of Anchoring chain;
- six initial weapon families + normal/common elemental/rare aspect separation;
- Skill tied to weapon, Ultimate boss-derived;
- diminishing-return Defense baseline (`100 Defense = 50% mitigation`);
- initial passive fauna + Skeleton/Zombie direction;
- LPC catalog/composition architecture;
- mobile cartoon/pixel-art technical render direction;
- authoritative-state save/migration architecture;
- fully offline baseline game.
