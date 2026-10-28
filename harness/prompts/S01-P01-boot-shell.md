# Codex Prompt — S01-P01 Boot / Save / Mobile Shell

You are implementing Season 1 Part 1 of Black Island. Follow `AGENTS.md` exactly. Work only on an implementation branch based on the validated P00/base state; never on `main`.

## Read only what is needed
1. `AGENTS.md`
2. `harness/context/S01-P01.md`
3. `docs/architecture/REPOSITORY_MAP.md`
4. `docs/architecture/GAME_ARCHITECTURE.md`
5. `docs/architecture/SAVE_AND_MIGRATION.md`
6. relevant boot/UI files

Do not preload world/combat/LPC docs unless a direct dependency appears.

## Goal
Produce the first real playable Black Island shell in Godot 4.7.2: project boots, save-slot flow works, one save enters Main, production HUD exists, mobile-landscape/safe-area behavior is sane, and debug tooling is separate.

## Required implementation
### Boot flow
Create a minimal production flow equivalent to:
`Boot -> SaveSelect -> Main`

No fake script-only harness. Running the project must reach scenes/UI.

### Save shell
- exactly 4 visible save slots;
- slot metadata schema/version ready for future migration;
- creating/selecting a slot enters Main;
- do not generate the final island yet;
- use stable save IDs/paths, not Node instance IDs;
- writes must follow the atomic-save direction in `SAVE_AND_MIGRATION.md` where practical.

### Mobile/display foundation
- landscape-first;
- responsive anchors/containers rather than hard-coded one-phone pixel coordinates;
- safe-area-aware root layout;
- logical resolution/base scale suitable for current design;
- test at more than one desktop window/aspect simulation if device testing is unavailable.

### Production HUD shell
Create the real HUD structure, even if values are placeholders:
- top-left Health, Stamina, Mana region;
- bottom-left movement-control region/native joystick placeholder/path;
- bottom-center 8-slot hotbar + inventory button;
- bottom-right action/combat-control region.

Do not fully implement inventory/combat yet.

### Input map
Create semantic input actions for later systems, e.g. movement, interact, attack, dodge, inventory, build mode. Use Godot input actions; do not hard-wire physical keys inside gameplay code.

### Debug/test scene
Create/maintain a dedicated `SeasonTest`/debug scene reachable without contaminating normal production UI. Debug controls must be collapsible/disabled in production flow.

### Smoke validation
Add the smallest maintainable smoke validation possible for:
- project parse/boot;
- Boot scene exists;
- Main can be reached;
- save-slot UI instantiates;
- no missing-script/resource errors in the tested path.

## Out of scope
- voxel island;
- Voxel Tools integration except dependency sanity needed to keep project booting;
- LPC rendering;
- final player controller;
- farming, inventory logic, combat logic, NPC AI;
- online services.

## Engineering rules
- typed/modular GDScript where practical;
- no giant `Main.gd` god object;
- separate save/profile service from UI;
- do not use autoloads as a dumping ground;
- UI displays state; it does not own save truth;
- do not introduce secrets.

## Checkpoints
C01: project settings + Boot/Main + input/display foundation.
C02: four-slot save shell + production HUD shell.
C03: debug/test scene + smoke checks + cleanup/handoff.

Commit/push after each validated checkpoint if practical, and definitely before long manual testing.

## Acceptance criteria
1. Godot 4.7.2 opens/imports the project cleanly as far as environment permits.
2. Run project -> Boot/SaveSelect -> choose/create a slot -> real Main shell.
3. Four save placeholders/slots are visible and deterministic.
4. HUD layout survives at least two landscape aspect/resolution simulations.
5. Input map exists semantically.
6. Debug scene exists separately and does not permanently pollute production HUD.
7. No secrets/local absolute paths/generated junk committed.
8. Validation commands/results recorded in `harness/build/S01-P01.md`.
9. Final checkpoint committed and pushed.

## Final handoff
Return: branch + commit SHA, playable path, files changed, tests/checks with pass/fail, screenshots/artifacts if produced, known UI/device limitations, and exact next task for S01-P02. Do not claim world generation exists yet.