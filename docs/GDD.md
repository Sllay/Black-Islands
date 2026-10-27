# Black Island — GDD (Living)

## High concept

Black Island is a mobile-first 2.5D life/farming action RPG with village management and procedural exploration. It takes structural inspiration from farming/life sims, the impact/readability of modern action roguelite combat, survival-game modular building and multi-floor cave exploration, while keeping its own world, systems and presentation.

## View and presentation

- Real 3D world with 2D LPC-derived characters presented as composed/cached `Sprite3D` billboards.
- Stylized cartoon/pixel-art hybrid presentation with strong readability.
- Primary gameplay camera remains to be finalized between shoulder/angled and a more Cult-of-the-Lamb-like readable composition.
- Optional first-person view remains possible.
- Central/contextual probe for interaction, ranged targeting, terrain tools and construction.
- Build mode uses a precise square grid; visual terrain itself remains smooth rather than blocky.

## Player visual

The player's physics/collision are fully 3D. LPC is presentation, not collision authority.

Character appearance is compiled from the LPC catalog: body type, selections, multiple recolor channels, layers/z-order, animation compatibility and equipment visuals. Ordinary gameplay should avoid one persistent `Sprite3D` per LPC layer; the preferred presentation is composed/cached animation output.

Gameplay asks for semantic actions such as `MOVE`, `MELEE_SLASH`, `CHOP`, `MINE`, `FISH` and `HURT`. The LPC resolver selects the best compatible upstream animation/fallback rather than gameplay hard-coding LPC animation names.

See `docs/architecture/LPC_PIPELINE.md` and `docs/design/PLAYER_LPC_AND_3D_PRESENTATION.md`.

## World

Each save generates a medium island from a deterministic seed. The long-term world format must allow larger islands containing multiple major/minor biomes without a rewrite.

Generation is constrained by design profiles rather than unrestricted noise. A valid island may contain 0–1 primary river depending on profile and approximately 0–2 small/medium lakes. Hydrology, village placement, buildable terrain and points of interest are validated before accepting a seed result.

The surface is authoritative volumetric voxel data rendered as a smooth terrain mesh. Voxels are gameplay/storage cells, not visible cubes. This permits precise digging/material editing while preserving organic hills, coastlines and slopes.

Logical material ownership remains discrete, but compatible material boundaries blend visually rather than meeting as obvious square seams. Terrain painting/farming may combine neighbor topology, smooth masks and controlled edge noise.

Houses/buildings are physical and entered without loading screens.

## Terrain persistence

Prefer saving:

`procedural base(seed) + terrain/material deltas + persistent entities/world state`

rather than writing every unchanged voxel to the save.

Terrain edits rebuild only affected chunks/required border neighbors.

## Intro

The player arrives mysteriously on the island near a devastated village. An introductory sequence leads to finding a poor-condition weapon, regaining control and defending the remaining villagers. Approximately three survivors establish the initial social/village loop.

## Village

The player becomes the practical leader/caretaker of the settlement. Villagers can receive jobs based on strengths, improve skills through work and participate in schedules, relationships, social events, raids and story events.

Chapter 1 targets at most roughly ten meaningful live villagers, making individual depth more valuable than crowd size.

NPC death can be persistent where the event/system explicitly permits it.

## Farming

Farming targets the authoritative terrain surface/material state. Tilling/watering need not create one scene node per soil tile.

Examples:

- `GRASS -> TILLED_DRY`
- `TILLED_DRY -> TILLED_WET`
- path painting changes the relevant surface material/state.

Material transitions remain visually smooth even though gameplay ownership is discrete.

Full crop lifecycle/regrowth/season rules still require a dedicated design pass.

## Building

Construction is modular, physical and deliberately precise. It uses a square `BuildGrid` aligned by an integer ratio to voxel resolution.

Different structures occupy different logical domains:

- foundations/ceilings/platforms use structural cells;
- walls/doors/window walls use shared edges;
- pillars/posts use point/center sockets.

Adjacent foundations share one boundary edge, preventing double walls on the same border.

Support is not simple connectivity. A structural graph tracks real support roots, support provenance, horizontal span and load/capacity. Walls/pillars/foundations placed on already-cantilevered geometry do not automatically reset support distance. Only genuine support reaching valid ground/root conditions can create a fresh support origin.

This blocks infinite `wall -> ceiling -> wall -> ceiling` sky staircases and prevents one pillar from supporting an unlimited floating structure.

Destroying a load-bearing piece triggers local graph recomputation. Only pieces that lose all valid support paths/capacity collapse; alternate pillars/walls can keep connected bridge sections alive.

See `docs/design/BUILDING_AND_STRUCTURAL_SUPPORT.md`.

## World props and biomes

Surface and cave floors will use biome-driven terrain materials, grass/foliage, trees, rocks, resources and props. Exact deterministic scatter, clustering, suppression under buildings, regrowth and streaming rules remain an open design task.

Placing foundations or painting/digging terrain must notify the local foliage/prop system so vegetation does not remain clipping through new structures or invalid ground.

## Inventory/HUD

Gameplay HUD direction:

- top-left health, stamina and mana bars with stepped visual widths;
- bottom-left movement joystick;
- bottom-center 8 hotbar slots plus inventory button;
- bottom-right attack/use and interaction controls, with contextual extra combat controls only when justified.

Inventory uses slot/stack capacity without a weight system. Slot count may expand through progression/container/backpack systems.

Current inventory screen direction places crafting on the **left** and player inventory on the **right**, while preserving essential status visibility.

Common resource stack target is 256 unless item rules override it.

## Crafting

Crafting uses a five-slot visible queue and is processed per unit.

A timer only measures when an attempted unit becomes ready; it does not directly pay/create items.

At unit completion:

`timer -> revalidate -> atomic ingredient consumption -> create output -> insert into inventory or world-drop -> decrement queue -> next timer`

Queue entries do not reserve all ingredients in advance. Later entries sharing resources can shrink as earlier crafts or other systems consume the real inventory resources. If an entry becomes impossible at zero units, it can be removed.

Cancelling an unfinished entry does not require refunding its current timer because ingredients are paid only when a unit successfully completes.

If output has already been paid for but inventory is full, the crafted output drops into the world rather than disappearing.

One remaining semantic to lock is whether a queue entry that shrank can automatically grow back toward its original requested amount if resources are later added.

See `docs/design/INVENTORY_AND_CRAFTING.md`.

## Combat

Weapons define the practical class. Switching weapon changes moveset, combos, reach, costs and available actions.

An attack is data-driven around windup/active/recovery, hitbox, movement, damage, knockback, hitstop, costs, effects and combo transitions.

Enemy contact alone is generally not an attack. Enemies telegraph, execute an attack window and recover so avoidance is readable.

## Elements

Common/core families include fire, water, earth and plant/nature. Rare/special families include pure light, pure darkness and blood/sanguine. Equipment combinations can produce synergies/conflicts through a data-driven reaction system rather than hard-coded pairwise logic spread across scripts.

## Progression

XP/levels improve baseline capability and award passive-tree points. The tree emphasizes modifiers and playstyle changes rather than replacing weapon-based active combat.

## Mines / caves

The mine is treated as multi-floor cave exploration rather than a continuous underground volume physically carved beneath the surface island. Each floor is a separate generated world/map state with its own terrain, biome, props, lighting and streaming state.

Entering the dark cave mouth transitions to a cave floor. Approaching a descent point begins preloading the next floor's spawn envelope. The rest streams after transition. Previous floor state may remain in a short hot cache for quick return.

Authoritative `MineFloorData` persists destroyed terrain/cells, containers, special NPCs, important enemies, exits, POIs and events even when the visual Scene is unloaded.

Underground biome direction includes room for bioluminescent, dark/hostile, gothic and other unusual themes, but the Chapter 1 biome list is not yet locked.

## NPCs

NPC depth comes from local deterministic systems first: personality, schedule, needs, skills/jobs, memories, relationship dimensions and social/event logic.

Relationship dimensions may include affection, trust, respect, attraction, resentment, fear and familiarity. Labels such as friend, crush, partner or enemy are derived states rather than the only stored value.

NPC visual randomization uses LPC compatibility filters mainly to prevent broken combinations; it should remain genuinely random enough to produce unusual appearances rather than relying on hundreds of hand-made presets.

## Optional LLM enrichment

The game remains complete offline. Optional user-configured AI providers may enrich a minority of social/narrative decisions.

The model proposes structured Social Intents or text variants. It cannot directly mutate the world. Local validators, event planners, Dialogue Manager and LimboAI execute or reject proposals.

## Content tooling

Producer-facing content should be creatable through Black Island Tools inside the Godot editor wherever practical: items, recipes, weapons/movesets, NPC definitions, quests/cutscenes, validation and world content.

## Open design work

The living priority list is maintained in `docs/design/OPEN_DESIGN_CHECKLIST.md`. It currently includes biome/prop generation, grass suppression/regrowth, exact voxel/chunk/mobile profile, hydrology, player/camera feel, interaction priorities, farming/resource gathering, combat feel, build constants, inventory UX edge cases and remaining content/presentation rules.
