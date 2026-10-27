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
│   │   ├── WORLD_STREAMING.md
│   │   ├── LPC_PIPELINE.md
│   │   ├── NPC_AI.md
│   │   └── CONTENT_TOOLS.md
│   ├── decisions/
│   │   ├── ADR-0001-repository-layout.md
│   │   ├── ADR-0002-surface-terrain.md          # superseded historical decision
│   │   ├── ADR-0003-local-first-npc-ai.md
│   │   └── ADR-0004-smooth-voxel-world-and-build-grid.md
│   └── design/
│       ├── PLAYER_LPC_AND_3D_PRESENTATION.md
│       ├── BUILDING_AND_STRUCTURAL_SUPPORT.md
│       ├── INVENTORY_AND_CRAFTING.md
│       └── OPEN_DESIGN_CHECKLIST.md
│
├── agents/
│   ├── README.md
│   └── SUBAGENTS.md
│
├── harness/
│   ├── README.md
│   ├── build/                  # phase/checkpoint execution logs
│   ├── context/                # compact active-phase context packets
│   └── review/                 # test/review findings
│
├── research/
│   └── README.md               # evaluated external systems/references
│
├── scripts/                    # repo/build/release automation only
│
└── game/                       # GODOT PROJECT ROOT
    ├── project.godot
    ├── addons/
    │   └── black_island_tools/ # our producer/editor plugin (later)
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

Focused specs override older high-level summaries when both exist. Architectural changes that reverse an accepted decision should supersede the old ADR rather than silently rewriting history.

Current terrain authority is ADR-0004; ADR-0002 is historical/superseded.
