# Black Island — GDD (Living)

## High concept

Black Island is a mobile-first 2.5D life/farming action RPG with village management and procedural exploration. It takes structural inspiration from farming/life sims, the impact/readability of modern action roguelite combat, deep village management and multi-floor mine exploration, while keeping its own world, systems and presentation.

## View and presentation

- 3D world with 2D LPC-derived characters.
- Primary camera: third-person/over-shoulder.
- Optional first-person view.
- Central crosshair for interaction/ranged targeting/construction probes.
- Smooth terrain; the logical world grid is not visually voxelized.

## World

Each save generates a medium island from a deterministic seed.

Generation is constrained by design profiles rather than unrestricted noise. A valid island may contain 0–1 primary river depending on profile and approximately 0–2 small/medium lakes. Hydrology, village placement, buildable terrain and points of interest are validated before accepting a seed result.

The surface is a continuous smooth world. Houses/buildings are physical and entered without loading screens.

## Intro

The player arrives mysteriously on the island near a devastated village. An introductory sequence leads to finding a poor-condition weapon, regaining control and defending the remaining villagers. Approximately three survivors establish the initial social/village loop.

## Village

The player becomes the practical leader/caretaker of the settlement. Villagers can receive jobs based on strengths, improve skills through work and participate in schedules, relationships, social events, raids and story events.

Chapter 1 targets at most roughly ten meaningful live villagers, making individual depth more valuable than crowd size.

NPC death can be persistent where the event/system explicitly permits it.

## Farming

Farming operates on the logical surface-cell layer. Till, wet/dry and crop state are gameplay data. Terrain/material presentation reflects those states. Player terrain editing is intentionally constrained rather than full sandbox terrain destruction.

## Building

Construction is modular and physical: foundations/floors, walls, doors, windows/platforms/ceilings and later roof/gable/ramp variants. Placement uses snap/support validity rules. Structures have durability and can participate in raids/damage systems.

## Inventory/HUD

Gameplay HUD:
- top-left health, stamina and mana bars with stepped visual widths;
- bottom-left movement joystick;
- bottom-center 8 hotbar slots plus inventory button;
- bottom-right attack/use and interaction controls, with contextual extra combat controls only when justified.

Inventory opens as a near-fullscreen interface while preserving essential status visibility. The left side is inventory/hotbar; the right side is crafting recipes/details/queue.

## Crafting

Crafting is queued and transactional. Ingredient displays aggregate by item type across stacks. Actual inventory stack limit target is 256 unless overridden by item rules.

Every craft completion revalidates and atomically consumes ingredients before output is created. If output cannot enter inventory, the remainder becomes a world drop. Queue reordering/cancellation must never create a state where output exists without payment.

## Combat

Weapons define the practical class. Switching weapon changes moveset, combos, reach, costs and available actions.

An attack is data-driven around windup/active/recovery, hitbox, movement, damage, knockback, hitstop, costs, effects and combo transitions.

Enemy contact alone is generally not an attack. Enemies telegraph, execute an attack window and recover so avoidance is readable.

## Elements

Common/core families include fire, water, earth and plant/nature. Rare/special families include pure light, pure darkness and blood/sanguine. Equipment combinations can produce synergies/conflicts through a data-driven reaction system rather than hard-coded pairwise logic spread across scripts.

## Progression

XP/levels improve baseline capability and award passive-tree points. The tree emphasizes modifiers and playstyle changes rather than replacing weapon-based active combat.

## Mines

The mine is not physically carved below the surface terrain. Each floor is a separate world/map state with its own generation and streaming.

Entering the dark cave mouth transitions to a mine floor. Approaching a descent point begins preloading the next floor's spawn envelope. The rest streams after transition. Previous floor state may remain in a short hot cache for quick return.

Authoritative `MineFloorData` persists destroyed cells, containers, special NPCs, important enemies, exits, POIs and events even when the visual Scene is unloaded.

## NPCs

NPC depth comes from local deterministic systems first: personality, schedule, needs, skills/jobs, memories, relationship dimensions and social/event logic.

Relationship dimensions may include affection, trust, respect, attraction, resentment, fear and familiarity. Labels such as friend, crush, partner or enemy are derived states rather than the only stored value.

## Optional LLM enrichment

The game remains complete offline. Optional user-configured AI providers may enrich a minority of social/narrative decisions.

The model proposes structured Social Intents or text variants. It cannot directly mutate the world. Local validators, event planners, Dialogue Manager and LimboAI execute or reject proposals.

## Content tooling

Producer-facing content should be creatable through Black Island Tools inside the Godot editor wherever practical: items, recipes, weapons/movesets, NPC definitions, quests/cutscenes, validation and world content.
