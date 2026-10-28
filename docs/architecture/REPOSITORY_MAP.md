# Repository Map — Authoritative

`game/` is the Godot project. Everything else supports development and must not be imported as game content.

```text
Black-Islands/
├── README.md
├── AGENTS.md
├── GOALS.md
├── PLANS.md
├── .gitignore
│
├── docs/
│   ├── GDD.md
│   ├── architecture/
│   │   ├── REPOSITORY_MAP.md
│   │   ├── TECH_STACK.md
│   │   ├── GAME_ARCHITECTURE.md
│   │   ├── VOXEL_WORLD_IMPLEMENTATION.md
│   │   ├── WORLD_STREAMING.md
│   │   ├── WATER_AND_HYDROLOGY.md
│   │   ├── LPC_PIPELINE.md
│   │   ├── SAVE_AND_MIGRATION.md
│   │   ├── NPC_AI.md
│   │   └── CONTENT_TOOLS.md
│   ├── decisions/
│   │   ├── ADR-0001-repository-layout.md
│   │   ├── ADR-0002-surface-terrain.md          # superseded historical decision
│   │   ├── ADR-0003-local-first-npc-ai.md
│   │   ├── ADR-0004-smooth-voxel-world-and-build-grid.md
│   │   ├── ADR-0005-ephemeral-caves-with-persistent-anchors.md
│   │   └── ADR-0006-authoritative-inventory-transactions.md
│   └── design/
│       ├── PLAYER_LPC_AND_3D_PRESENTATION.md
│       ├── PLAYER_COMBAT.md
│       ├── COMBAT_STATS_AND_LEVEL_SCALING.md
│       ├── WEAPON_FAMILIES_AND_COMBOS.md
│       ├── CHARACTER_CREATOR.md
│       ├── BUILDING_AND_STRUCTURAL_SUPPORT.md
│       ├── STRUCTURE_TIERS_AND_LARGE_BUILDS.md
│       ├── FARMING_AND_FOLIAGE.md
│       ├── HARVESTING_AND_RESOURCES.md
│       ├── BIOMES_AND_PROP_GENERATION.md
│       ├── SURFACE_BIOME_CONTENT_TABLES.md
│       ├── WEATHER_DAY_NIGHT_AND_FIRE.md
│       ├── WORLD_ECOLOGY_AND_OFFSCREEN_SIMULATION.md
│       ├── INVENTORY_AND_CRAFTING.md
│       ├── MOBS_CORPSES_AND_LOOT.md
│       ├── INITIAL_MOBS_AND_RESOURCES.md
│       ├── CAVES_AND_ANCHOR_PROGRESSION.md
│       ├── CAVE_BIOMES_AND_GENERATION.md
│       ├── NPC_NAMES_AND_JOBS.md
│       ├── VISUAL_RENDERING_DIRECTION.md
│       └── OPEN_DESIGN_CHECKLIST.md
│
├── agents/
│   ├── README.md
│   └── SUBAGENTS.md
│
├── harness/
│   ├── README.md
│   ├── build/
│   ├── context/
│   └── review/
│
├── research/
│   ├── README.md
│   ├── WATER_SYSTEM_REFERENCES.md
│   └── ARK_HARVESTING_REFERENCES.md
│
├── scripts/
│
└── game/                       # GODOT PROJECT ROOT
    ├── project.godot
    ├── addons/
    │   └── black_island_tools/
    ├── assets/
    │   ├── audio/
    │   ├── characters/
    │   ├── environment/
    │   ├── items/
    │   ├── ui/
    │   └── vfx/
    ├── autoload/
    ├── data/
    │   ├── definitions/
    │   ├── generated/
    │   └── localization/
    ├── resources/
    │   ├── combat/
    │   ├── items/
    │   ├── npc/
    │   ├── recipes/
    │   ├── progression/
    │   └── world/
    ├── scenes/
    │   ├── boot/
    │   ├── main/
    │   ├── player/
    │   ├── npc/
    │   ├── enemies/
    │   ├── world/
    │   ├── mines/
    │   ├── structures/
    │   ├── ui/
    │   └── debug/
    ├── scripts/
    │   ├── core/
    │   ├── combat/
    │   ├── inventory/
    │   ├── crafting/
    │   ├── building/
    │   ├── farming/
    │   ├── world/
    │   ├── mines/
    │   ├── npc/
    │   ├── dialogue/
    │   ├── ai/
    │   ├── network/
    │   ├── save/
    │   └── ui/
    ├── shaders/
    └── tests/
        ├── integration/
        └── fixtures/
```

## Boundary rule

If Godot needs to import, execute or load it, it belongs somewhere under `game/`. If it exists only for humans, Codex orchestration, planning, research or build history, it stays outside `game/`.

## Documentation authority rule

Focused specs override older high-level summaries when both exist. Architectural reversals supersede old ADRs rather than silently erasing history.

Current terrain authority is ADR-0004; ADR-0002 is superseded.

Current cave persistence authority is ADR-0005.

Current inventory mutation authority is ADR-0006.
