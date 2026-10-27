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
│   │   ├── NPC_AI.md
│   │   └── CONTENT_TOOLS.md
│   ├── decisions/
│   │   ├── ADR-0001-repository-layout.md
│   │   ├── ADR-0002-surface-terrain.md
│   │   └── ADR-0003-local-first-npc-ai.md
│   └── design/                 # focused system/design specs as they mature
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
