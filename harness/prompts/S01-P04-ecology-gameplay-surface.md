# Codex Prompt — S01-P04 Ecology / Gameplay Surface

You are implementing Season 1 Part 4 of Black Island. Follow `AGENTS.md` exactly. Start only from a validated P03 state where the real player traverses the real generated island with LPC presentation, targeting, inventory state and combat baseline.

## Read in this order
1. `AGENTS.md`
2. `harness/context/S01-P04.md`
3. `docs/design/BIOMES_AND_PROP_GENERATION.md`
4. `docs/design/FARMING_AND_FOLIAGE.md`
5. `docs/design/HARVESTING_AND_RESOURCES.md`
6. `docs/design/BUILDING_AND_STRUCTURAL_SUPPORT.md`
7. `docs/design/MOBS_CORPSES_AND_LOOT.md`
8. `docs/design/INVENTORY_AND_CRAFTING.md`
9. `docs/architecture/WORLD_STREAMING.md`
10. `docs/architecture/SAVE_AND_MIGRATION.md`
11. relevant implementation files only

Do not preload caves/full NPC-social/full Season 2 combat docs unless a direct dependency is unavoidable.

## Goal
Turn the P03 world/player prototype into the first real Black Island gameplay surface: biome props and grass exist, resources can be harvested, one farming loop works, modular building works at foundation level, containers use safe transactions, representative mobs live/die/harvest correctly, and drops persist through the proper bag/corpse model.

The phase ends with an integrated Season 1 playable slice. Do not build these systems as disconnected labs only.

## 1. Biome prop generation baseline
Use the deterministic biome/world data from P02 to generate representative content for at least:
- beach/coastal strip;
- tropical plains;
- tropical hills/elevation;
- central forest.

Implement data-driven `PropSpawnDefinition`/equivalent with constraints such as:
- biome;
- terrain material;
- slope;
- height;
- distance to water;
- density;
- cluster/scatter behavior;
- rarity;
- persistent vs disposable status.

Use deterministic spawn IDs/seeded placement so unload/reload does not reshuffle persistent resource props unexpectedly.

Repeated visual props should use MultiMesh/instancing/pooling where appropriate. Do not create one expensive full AI/physics Node for every grass blade.

## 2. Grass/foliage system
Implement local foliage generation and suppression:
- grass/foliage appears only on eligible terrain/biome;
- placing foundation suppresses foliage under/around its footprint;
- road/path painting suppresses foliage;
- FarmPlot suppresses ordinary grass;
- terrain excavation invalidates unsupported foliage;
- demolition/removal releases suppression and allows regrowth when terrain is eligible;
- update locally rather than regenerating the whole biome.

Use the current rendering direction: mipmaps, alpha-test coverage preservation and primarily cutout/alpha-scissor foliage where art permits.

## 3. Generic resource harvesting
Implement the ARK-inspired Black Island harvest architecture from `HARVESTING_AND_RESOURCES.md`.

Required concepts:
- `HarvestableState`/harvest health separate from ordinary combat HP where appropriate;
- finite `ResourceReserve`s;
- tool `HarvestProfile` / damage-type affinity;
- actual harvest damage clamped to remaining harvest health;
- yield derived from actual harvest fraction + tool quality/efficiency + per-resource affinity;
- no overkill duplication;
- resource reserves cannot go negative;
- all authoritative item output enters inventory/world through transaction APIs.

Prove on at least:
- one tree;
- one rock/resource node;
- one corpse in mob section below.

Representative tool differences should be visible. Do not yet build the entire tool-tier catalog.

## 4. Farming vertical slice
Implement the accepted dedicated `FarmPlot` state rather than packing crop state into terrain voxels.

Minimum loop:
`eligible dirt/grass -> hoe -> FarmPlot dry -> plant one seed -> water -> growth progression -> harvest`

Required behavior:
- hoe does not mine/remove terrain density; it prepares/suppresses grass and creates the plot;
- road/path remains terrain material painting, not FarmPlot;
- plot stores seed/crop ID, moisture, growth progress/stage, fertilizer seam and decay state;
- one representative crop definition is enough for P04;
- normal watering target supports roughly one game-day moisture behavior as current design seam;
- abandoned dry empty plot can decay/remove according to configured deadline;
- unsupported plot breaks if terrain under it is removed;
- seed/item return follows data rule, not hard-coded crop name.

Weather/rain integration may be a seam/mock event in P04 if the full weather scheduler is not implemented yet; do not block the whole phase on final storm system.

## 5. Modular construction baseline
Implement first real building pieces on the P02/P03 BuildGrid:
- Foundation;
- Wall;
- Ceiling/Platform;
- Pillar.

Required occupancy model:
- foundation/ceiling: cell slots;
- wall: shared edge;
- pillar: point/center socket;
- double wall on same shared edge impossible by ownership/state, not only collision.

Implement support provenance baseline:
- grounded foundation/root supports up to two horizontal ceiling cells in permitted directions;
- wall/foundation/pillar placed on already cantilevered geometry does not reset root distance;
- grounded pillar/true ground path can create new real support root;
- multiple valid support roots may coexist;
- destroying one support only collapses the subset that loses all valid support candidates;
- no global material load-capacity simulation;
- material tier changes durability, not support reach.

P04 can use one material tier first if needed, but definitions must support the accepted Thatch/Wood/Stone/Darkstone/Scrap/Iron tier data later.

## 6. Container + transaction foundation
Implement reusable inventory containers and the authoritative transaction coordinator seam.

Minimum:
- one chest/container;
- player <-> chest transfer;
- revision/version checks so one stack cannot be owned by two containers;
- quantity transfer path supporting full-stack and partial-stack transactions;
- double-click/full transfer behavior can be represented at UI layer if practical;
- UI must never directly mutate two inventories independently.

Stress-test transaction ordering sufficiently to catch obvious duplication during transfer.

Full nearby-workbench multi-chest recipe scope may remain Season 2 if necessary, but the transaction architecture must already support multiple inventory participants.

## 7. Representative mobs
Implement at least three representative behaviors using the shared mob framework rather than three bespoke AI codebases:

### Passive representative
Example: rabbit/chicken/cow.
- does not hunt player;
- flee or configured defend-on-hit response.

### Neutral representative
- attacks only under one contextual trigger such as territory/proximity.
- gives readable warning before aggression where applicable.

### Aggressive representative
- attacks on configured condition, preferably proving one day/night or perception rule seam.

Use LimboAI/HSM if already validated/introduced by repo architecture; otherwise keep behavior executor replaceable and data-driven.

## 8. Corpse / loot / harvesting
On death:
`Alive -> Death -> CorpseState -> loot/harvest -> decomposition/despawn`

Prove both channels:
- delicate/interact loot;
- harvest-by-tool yields.

Example implementation may use chicken/cow-style data:
- interact/open corpse -> feather/milk/specific delicate item;
- knife/axe/other tool -> different hide/meat yield weighting.

Protected loot categories must be able to convert atomically into a `DeathBagInventory` if corpse disappears/decomposes according to policy.

World loose drops should use generic `WorldDropBag`/package containers rather than one physics object per stack.

## 9. Offscreen simulation seam
Do not fully simulate distant mobs with physics.

Implement enough architecture for states such as:
- ACTIVE;
- NEAR_PROXY;
- REGIONAL;
- STASIS.

For P04, prove at least that moving far enough can deactivate expensive presentation/AI while preserving authoritative mob identity/state, then restore it without duplicating/killing the mob.

Do not implement full zombie migration/raid simulation unless scope remains healthy after required deliverables pass.

## 10. Save integration
Persist authoritative implemented state:
- harvested/destroyed persistent props;
- FarmPlots;
- placed structures;
- chest/container contents;
- persistent mob state required by current implementation;
- protected death/drop bags where policy requires.

Do not persist generated foliage blades, MultiMesh instance buffers, navigation caches or other derivable presentation state.

## 11. SeasonTest integrated validation
Update the dedicated test scene/debug tooling so the same running build can demonstrate:
- biome/foliage streaming;
- harvest tree/rock;
- farm one crop;
- place foundation/wall/ceiling/pillar and demonstrate support/collapse;
- transfer items chest <-> player;
- fight representative mob;
- loot/harvest corpse;
- verify save/reload of representative mutations.

Debug instrumentation must remain collapsible/non-production.

## Out of scope
- full village social AI;
- full cave gameplay;
- all Chapter 1 crops/structures/tools/mobs;
- complete weather/lightning simulation;
- full workstation craft queue UX;
- full weapon family/Skill/Ultimate content;
- multiplayer/tribes.

## Required anti-exploit/regression tests
- resource overkill cannot create yield beyond reserve;
- concurrent/ordered chest transfer cannot duplicate a stack;
- looting corpse and converting corpse loot to death bag cannot duplicate same item;
- foundation suppresses foliage and demolition later permits eligible regrowth;
- wall shared edge cannot hold two walls;
- fake floating wall/pillar does not reset horizontal support;
- bridge/section with alternate support survives removal of unrelated root;
- FarmPlot breaks when supporting terrain is removed;
- harvested persistent resource does not respawn merely because its chunk streamed out/in unless definition allows it;
- offscreen mob unload/reload preserves one identity;
- P01/P02/P03 boot/save/world/player regressions remain passing.

## Performance evidence
Record at least desktop proxy numbers if real mobile is unavailable:
- foliage/prop instance count and draw-call strategy;
- active mob count used in test;
- frame-time while streaming props;
- transaction stress test count/results;
- structure support recompute size/time for a representative local structure;
- save size/change after representative mutations.

Never label desktop proxy as mobile validation.

## Checkpoints
C01: biome props + foliage suppression + generic harvesting.
C02: FarmPlot + modular building/support + chest transactions.
C03: mobs/corpses/drop bags + offscreen seam + integrated SeasonTest/save regression.

## Definition of done
Season 1 has a real integrated vertical slice: create/load save -> generated smooth island -> real player -> harvest -> farm -> build -> fight/interact -> loot/container -> save/reload. Placeholder art/content is acceptable; disconnected scripts are not.

## Final handoff
Return branch + final SHA, exact playable loop, files changed, implemented definitions, tests/pass-fail, profiling/platform label, known exploits/risks, deferred Season 2 items, and recommendation whether Season 1 is ready for merge/extended mobile testing.
