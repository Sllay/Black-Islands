# Black Island Tools — Content Authoring Architecture

## Goal

The producer should not need to edit gameplay scripts for routine content expansion.

## Single plugin, multiple workspaces

Planned root: `game/addons/black_island_tools/`.

The plugin may expose focused tabs/workspaces for:
- Items
- Weapons/Movesets
- Recipes
- NPCs
- Enemies
- Quests
- Cutscenes
- World content
- Validation

## Separation rule

The editor UI is not the data model. It edits regular game-owned Resources/definitions. Runtime systems must continue to work if the editor plugin is disabled.

## Semantic cutscenes

Cutscenes describe intent instead of manually keyframing routine gameplay behavior.

Examples:
- MoveActor(target)
- EquipItem(item)
- AttackTarget(target)
- PlayAction(action)
- Dialogue(node)
- EnableGameplay()
- WaitSignal(signal)
- Branch(condition)

Movement automatically uses normal locomotion/animation logic. Combat actions use the actual equipped moveset.

## Extensible effects

For reusable mechanics, prefer composable `Effect`/`EffectNode` definitions such as modify stat, apply status, spawn, give/remove item, world flag, relationship mutation or event emission.

When a truly new mechanic is needed, Codex implements a new reusable effect type; future content can then use it without script edits.
