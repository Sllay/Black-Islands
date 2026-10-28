# Black Island — GDD (Living)

## High concept

Black Island is a mobile-first 2.5D life/farming action RPG with village management, survival-style modular construction, procedural island exploration and regenerating multi-floor cave expeditions.

The visual/world readability takes inspiration from games such as Cult of the Lamb while construction/inventory depth takes structural inspiration from survival games such as ARK. Systems remain Black Island-owned and data-driven.

## View and presentation

- real 3D world;
- 2D LPC-derived characters as composed/cached `Sprite3D` billboards;
- cartoon/pixel-art hybrid art direction;
- primary gameplay camera is elevated/angled for combat/world readability;
- no core first-person mode;
- Build Mode transitions to a closer third-person construction camera for precision;
- contextual outlines are primarily interaction/target feedback rather than permanent full-scene outlines.

See `docs/design/PLAYER_LPC_AND_3D_PRESENTATION.md`.

## Player visual / LPC

Player/NPC appearance is compiled from the LPC catalog with body compatibility, layers/z-order, multiple recolor channels, custom/oversized animation support and license/credit validation.

Gameplay requests semantic actions (`MOVE`, `CHOP`, `MINE`, `MELEE_SLASH`, etc.); it never depends directly on upstream LPC filenames/animation strings.

See `docs/architecture/LPC_PIPELINE.md`.

## Character creator

Creator shows a large live preview plus catalog-driven category tabs/grids for body, face, hair, clothing, accessories and colors.

Recolor UI exposes LPC semantic palette channels instead of one generic tint.

A Randomize action intentionally uses only light curation: compatibility/legal breakage is prevented, but unusual combinations are allowed.

The same framework can customize newly recruited NPCs without changing their gameplay identity.

See `docs/design/CHARACTER_CREATOR.md`.

## World terrain

Each surface save generates an island from a deterministic seed/profile.

Accepted terrain architecture:

- volumetric voxel authority;
- target voxel spacing 0.5 m;
- smooth SDF/Transvoxel-style rendered surface;
- `BuildGrid` cell = 1 m;
- project WorldChunks = 64 x 64 x 64 m and exist vertically as well as horizontally;
- WorldChunk is a streaming/persistence unit, not one monolithic dense mesh allocation.

Initial near streaming region is the player chunk plus 8 horizontal neighbors (3x3). Vertical residency is sparse. Additional rings are added only after mobile profiling remains stable.

See `docs/architecture/VOXEL_WORLD_IMPLEMENTATION.md` and `WORLD_STREAMING.md`.

## Island scale and boundary

Intended island traversal should feel roughly 20-30 minutes point-to-point at ordinary travel speed. Physical diameter is derived after player movement speed is tuned rather than guessed first.

Ocean continues visually beyond the playable world. An outer soft ocean boundary creates a treadmill/attenuated-progress illusion before a hard invisible fail-safe boundary. Long persistence in the soft boundary can trigger a humorous localized thought line after roughly five minutes.

## Surface biome direction

Chapter 1 surface uses:

- tropical/beach shoreline surrounding island;
- open plains/tropical interior transition;
- central/appropriate forest;
- broad gentle elevations/hills mixed with buildable lower-relief terrain.

World should feel visually filled, not like sparse procedural terrain.

See `docs/design/BIOMES_AND_PROP_GENERATION.md`.

## Water

Water is gameplay-simulated locally rather than only visual.

Goals include:

- generated oceans/rivers/lakes;
- local downhill propagation into player-dug channels;
- accumulation;
- currents affecting actors;
- swimming;
- waterfall classification/presentation;
- water sources for farming.

The ocean horizon is not fully cell-simulated. Stable inland water sleeps until disturbed.

See `docs/architecture/WATER_AND_HYDROLOGY.md`.

## Props and foliage

Biome-driven prop generation uses deterministic stable spawn IDs for persistent harvestables and batched/instanced presentation for disposable grass/clutter.

Foundations, paths, FarmPlots, water and terrain edits locally suppress incompatible foliage.

When suppression disappears, eligible natural grass can regrow.

## Farming

Farming uses dedicated `FarmPlotState` anchored to the 1 m grid/surface rather than encoding full crop state inside voxel material.

Hoe on valid grass/dirt suppresses grass/prepares dirt and creates a FarmPlot without physically mining the terrain.

Shovel/path creation remains terrain material painting.

FarmPlot tracks seed, growth, moisture, fertilizer and decay.

Direction:

- normal watering protects moisture for around one in-game day;
- strong rain may extend to roughly three days;
- crop growth is day-oriented but visually progresses continuously;
- fertilizer can provide configurable growth multipliers;
- abandoned dry plots may decay after about 30 active gameplay minutes;
- natural dirt may return to grass after roughly 3-6 in-game days when eligible.

See `docs/design/FARMING_AND_FOLIAGE.md`.

## Building

Construction uses square 1 m cells plus shared wall edges and center/point sockets.

- foundations/floors/ceilings/platforms occupy structural cells;
- walls/door/window frames occupy shared edges;
- pillars use point/center support sockets;
- adjacent foundations share the same edge, preventing double walls.

A grounded support origin provides an initial two-cell horizontal ceiling/platform reach in supported directions. Walls/elevated foundations/floating pillars inherit the original support root; they do not reset horizontal reach. A pillar genuinely reaching ground creates a new support root.

Destroying support recomputes all valid root paths. Only structures with no remaining valid support candidate collapse.

Wood/stone structural tiers share support reach; stone differs mainly through durability/HP/cost/visuals, not magical load capacity.

Initial construction height cap is approximately +100 m from world reference/sea level.

See `docs/design/BUILDING_AND_STRUCTURAL_SUPPORT.md`.

## Intro and initial village

The player appears mysteriously near a devastated settlement and regains control during an attack/tutorial sequence.

Initial core survivors/roles:

- Farmer — survives opening; supplies/sells seeds and supports farming introduction;
- Explorer/Adventurer — survives opening and supports exploration/content guidance;
- Miner — can die if the player is too slow during the opening, making the village's early resource support materially different.

The player becomes the settlement's practical leader/caretaker.

## Inventory

No carry-weight system.

Initial player inventory:

- 20 slots total, interpreted as a 5x4 grid;
- 8-slot hotbar;
- hotbar accepts weapons, tools, consumables/food, structures/build items and explicitly eligible usable items;
- equipment: helmet, torso, legs, two accessories;
- active weapon is selected from hotbar.

Initial stack defaults:

- resources 256;
- consumables 32;
- tools/weapons/armor/accessories 1;
- structures 12;
- projectile/ammunition-style items 999;
- currency is a separate wallet/UI value.

See `docs/design/INVENTORY_AND_CRAFTING.md`.

## Inventory UI / containers

Normal fullscreen inventory places crafting and player inventory in opposing panes while keeping health/stamina/mana visible.

Craft recipe grid uses 5 horizontal columns and scrollable vertical rows. Craft queue has 5 visible slots.

Opening a chest/container enters dual-inventory mode with drag/drop, full-stack quick transfer and partial-stack quantity popup.

Workstations may craft using authorized nearby chests within a logistics radius.

## Crafting safety

All item mutation goes through one `InventoryTransactionCoordinator`.

UI never directly owns or mutates authoritative quantities.

Craft timer only schedules a unit attempt. At completion:

`timer -> resolve allowed inventory scope -> revalidate revisions/resources -> atomic consume -> create output -> insert into valid destination or world drop -> queue decrement`

Queue resources are not reserved globally in advance. Later jobs sharing ingredients shrink as real resources are consumed. Once quantity is clamped down, newly acquired resources do not magically regrow the queue; the player queues more explicitly.

Saving stores queue entries/remaining counts but not partial timer progress. Loading restarts the current unit timer.

## World drops

Loose dropped items prefer a generic small bag/package inventory rather than one physics node per stack.

Crafted output that cannot fit a valid inventory becomes a world drop bag rather than disappearing.

## Mobs

Base dispositions:

- Passive;
- Neutral;
- Aggressive.

Conditions are data-driven.

Examples:

- passive flee on threat;
- defensive passive retaliates only when attacked;
- neutral territorial/proximity behavior;
- aggressive on sight;
- night-only aggression;
- pack aggression only above member threshold.

See `docs/design/MOBS_CORPSES_AND_LOOT.md`.

## Corpses and harvesting

Mobs generally become temporary corpses rather than instantly spawning loose loot.

Two loot channels exist:

- delicate/interact inventory loot (for example feathers or creature-specific items);
- tool-based corpse harvest yields (meat/hide etc.) with tool-dependent efficiency.

Easy passive animals may lose unclaimed delicate loot if the body is harvested first. Bosses/important aggressive enemies/player death use persistent death-bag fallback for protected unclaimed inventory.

## Combat

Combat is weapon-defined and Cult-of-the-Lamb-like in readability.

- tap Attack = normal combo;
- hold Attack = directional HeavyAim; player pauses/limits movement and joystick points attack direction; release executes heavy attack;
- weapon Skill button;
- boss-derived equipped Ultimate button;
- Dodge/Roll with explicit i-frames;
- selected weapon sets support Guard/Parry.

Guard is frontal and slows movement. Rear/out-of-arc attacks bypass/break it. Well-timed frontal guard can parry for zero damage and brief enemy stun/stagger.

See `docs/design/PLAYER_COMBAT.md`.

## Elements

Core families include fire, water, earth and plant/nature. Rare families include pure light, pure darkness and blood/sanguine.

Weapon/skill effects and element reactions are data-driven.

## Caves

Caves are separate procedural floor worlds.

Ordinary floors are ephemeral per `CaveRun`: during one run backtracking can preserve temporary state, but returning to surface allows unanchored floors to reset/reroll.

A rare special cave anchor totem can make a floor persistent. Anchoring progresses consecutively through floors and unlocks elevator destinations; the player cannot anchor floor 1 and jump straight to floor 10 persistence.

Chapter 1 cave biome direction includes:

- Standard Cave — dark with sparse weak luminous crystals/mushrooms and mixed ecology;
- Darkness — effectively no natural light, aggressive creatures dominate, torches/lighting required;
- Enchanted/Luminous Forest — bright bioluminescent trees/crystals/mushrooms with more neutral/passive ecology plus selected dangerous mobs.

See `docs/design/CAVES_AND_ANCHOR_PROGRESSION.md`.

## NPCs

NPC depth remains local-first: personality, schedules, skills/jobs, memory and multidimensional relationships.

Appearance can be randomized locally or later drawn from a cached community appearance pool; recruited NPCs may be customized by the player.

Names begin with large local first-name/surname pools behind a generator interface so a future syllabic generator can plug in without rewriting NPC identity.

## Village future / tribes

Architecture should not block future multiplayer tribes.

Structures and containers use an ownership abstraction compatible with player/village today and tribe ownership later. Multiplayer/raids/PvP are not Chapter 1 implementation scope.

## Visual direction

Target is a dense, readable cartoon/pixel-art hybrid.

- stylized smooth terrain;
- pixel/cartoon character sprites;
- restrained mobile lighting;
- soft readable shadows rather than expensive realism;
- foliage density achieved through instancing/LOD;
- interaction outline/highlight where context requires it;
- VFX communicate attacks, harvesting, build validity and world interaction clearly.

## Content tooling

Producer-facing systems should remain data-driven through Black Island Tools wherever practical: items, recipes, structures, weapons/movesets, crops, NPCs, mobs, biomes, quests/cutscenes and validation.

## Implementation order

Current hands-on priority:

1. world/voxel/streaming/water foundation;
2. player movement/camera/LPC presentation;
3. biome props/vegetation/farming surface reactions;
4. NPC/mob baseline;
5. item drops/corpses/containers;
6. remaining Chapter 1 loops layered on top.

The active remaining decisions/checks live in `docs/design/OPEN_DESIGN_CHECKLIST.md`.
