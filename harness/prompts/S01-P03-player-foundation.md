# Codex Prompt — S01-P03 Player Foundation

You are implementing Season 1 Part 3 of Black Island. Follow `AGENTS.md` exactly. Start only from a validated P02 state where the real save enters the generated smooth-voxel island.

## Read in this order
1. `AGENTS.md`
2. `harness/context/S01-P03.md`
3. `docs/design/PLAYER_LPC_AND_3D_PRESENTATION.md`
4. `docs/architecture/LPC_PIPELINE.md`
5. `docs/design/PLAYER_COMBAT.md`
6. `docs/design/INVENTORY_AND_CRAFTING.md`
7. `docs/architecture/WORLD_STREAMING.md`
8. `docs/architecture/SAVE_AND_MIGRATION.md`
9. relevant implementation files only

Do not preload ecology/cave/NPC docs unless directly required.

## Goal
Replace any temporary world-inspection pawn with the first real Black Island player running on the generated island: 3D movement, angled gameplay camera, Build Mode camera, LPC-composed Sprite3D proof, targeting/interactions, inventory/hotbar shell and first combat actions.

## Fixed player presentation
- physics/controller: `CharacterBody3D` or equivalent Godot 3D body;
- physical origin/contact at feet;
- visible character: composed/cached LPC-derived `Sprite3D`/billboard presentation;
- LPC layers are not permanently represented by many Sprite3Ds per character;
- gameplay asks for semantic actions; it does not hard-code upstream LPC animation names;
- no baseline first-person mode.

## 1. PlayerMotor
Implement a modular movement controller that works on the P02 smooth terrain:
- move relative to gameplay camera;
- acceleration/deceleration;
- walk/run foundation;
- slope and floor snapping behavior;
- falling/gravity;
- step/small-height traversal where appropriate;
- no per-frame allocation-heavy code in hot paths;
- expose tunable data/resources rather than burying all constants in script.

Stamina architecture must exist, but Chapter 1 P03 only needs enough to prove run/tool/combat cost integration later. Do not build the full RPG stat system.

## 2. Cameras
Implement two real camera modes:

### Gameplay angled camera
- readable, Cult-of-the-Lamb-inspired elevated/angled composition;
- keeps player/world interactions readable;
- supports future rotation if architecture allows, but do not overbuild;
- obstruction handling baseline: do not allow terrain/props to make the player permanently invisible.

### Build third-person camera
- smooth transition from gameplay camera;
- closer/more precise 3D aiming suitable for square-grid construction;
- can ray/probe terrain and BuildGrid accurately;
- exit returns cleanly to gameplay camera.

## 3. LPC import/composition proof
Implement the smallest real vertical proof of the documented LPC architecture:
- compile/import a representative supported body/appearance from the accepted LPC source/catalog path;
- use stable catalog-facing IDs/data, not hard-coded arbitrary raw paths in player gameplay code;
- compose/cache the visible result into a runtime clip/texture presentation suitable for one Sprite3D;
- prove at least Idle + Move directional visuals and one action visual;
- include safe fallback when requested LPC clip is absent;
- do not attempt the complete live updater/community appearance service in this phase.

If full upstream compiler work is too large for the phase, implement a narrow compiler slice that follows the final schema and can be extended, rather than a throwaway manual spritesheet hack.

## 4. Semantic action bridge
Gameplay should request semantics such as:
- `IDLE`
- `MOVE`
- `RUN`
- `MELEE_SLASH`
- `HURT`

LPC resolver chooses actual compatible clip. Direction is resolved relative to movement/aim/camera, while Sprite3D remains presented correctly toward the camera.

## 5. InteractionTargeter baseline
Implement a central targeting service/probe that can distinguish at least:
- generic interactable;
- terrain surface/voxel;
- BuildGrid cell/socket debug target;
- representative combat target.

It must return one authoritative target/result rather than every gameplay system casting unrelated rays.

Keep priorities configurable/data-driven enough for P04 additions.

## 6. Inventory/hotbar/equipment shell
Implement the real runtime inventory state foundation:
- 20 slots, presented as 5 x 4 when full inventory UI exists;
- 8-slot hotbar;
- equipment slots: Helmet, Chest, Legs, Accessory 1, Accessory 2;
- stack rules from current design definitions;
- stable item IDs;
- item definitions separated from stack instances;
- no weight system;
- hotbar accepts allowed categories only (weapons/tools/consumables/build pieces as defined).

P03 needs real state and a minimal usable UI path, not the full chest/workbench/transaction ecosystem yet.

## 7. Combat baseline
Implement only enough to prove the architecture on the real player:
- normal/light attack;
- hold Attack -> HeavyAim;
- while HeavyAim, directional input controls aim rather than normal locomotion according to weapon rule;
- release -> heavy attack executes exactly once;
- dodge/roll with explicit i-frame window;
- representative melee hitbox/target dummy;
- no default overlap/contact damage;
- basic hitstop/knockback hooks can exist but final tuning is later.

Use data-driven `AttackDefinition`/moveset concepts from the design spec. Do not hard-code one sword forever into PlayerCombatController.

## 8. Defense/stat seam
Implement stat interfaces sufficient for damage calculation, including the accepted defense curve:
`damage_taken = raw_damage * 100 / (100 + Defense)`

Do not build every level/progression system in P03.

## 9. Save integration
Persist only authoritative player state currently implemented, e.g. transform/spawn context, basic inventory, equipment/hotbar assignments and appearance IDs as appropriate. Do not save composed LPC textures or transient attack/camera state.

## Out of scope
- full six-weapon content set;
- full combo library/skills/Ultimates/guard/parry content;
- character creator complete UX;
- props/foliage/farming;
- chest/workbench crafting scopes;
- mobs/NPC simulation;
- caves.

## Required tests
- player traverses smooth voxel slopes without obvious tunneling/floating in tested cases;
- camera transition gameplay <-> Build Mode is reversible;
- targeter reports terrain/build-grid/interactable/combat target correctly;
- LPC missing clip falls back without breaking player;
- identical appearance can reuse cache resource where implemented;
- heavy attack hold does not execute before release;
- release executes once;
- dodge i-frame window deterministic;
- one attack instance does not damage same target every frame unless explicitly multihit;
- inventory stack/hotbar category constraints pass;
- save/reload preserves authoritative implemented player state;
- P02 world streaming still works while player crosses chunk boundaries.

## Checkpoints
C01: PlayerMotor + gameplay/build cameras + targeter.
C02: LPC composition/action proof + inventory/hotbar state.
C03: combat baseline + save integration + regression/performance handoff.

## Definition of done
The real player enters the real P02 island, moves/cameras/targets correctly, displays through the LPC 2D-in-3D pipeline, can perform normal/heavy/dodge combat against a test target, and owns real inventory/hotbar state.

## Final handoff
Return branch + SHA, playable controls/path, LPC slice/schema implemented, tests/pass-fail, profiling notes, files changed, known input/mobile limitations, and exact next task for S01-P04.