# Codex Prompt — S01-P00 Bootstrap / Execution Readiness

Use this prompt as the first Codex task before implementation.

You are the implementation lead for Black Island, a Godot 4.7.2 mobile-first project in repository `Sllay/Black-Islands`.

Your job in this task is not to build gameplay yet. Prepare a safe, reproducible implementation baseline for Season 1.

## Read first
1. `AGENTS.md`
2. `PLANS.md`
3. `docs/architecture/REPOSITORY_MAP.md`
4. `docs/architecture/GAME_ARCHITECTURE.md`
5. `docs/architecture/TECH_STACK.md`
6. `docs/architecture/VOXEL_WORLD_IMPLEMENTATION.md`
7. `docs/architecture/SAVE_AND_MIGRATION.md`
8. relevant ADRs only as needed

Do not preload the entire repository/GDD. The Godot project root is `game/`.

## Branch handling
- Inspect current repository state first.
- If PR #1 has already merged, branch from updated `main`.
- If PR #1 is still open, base implementation on `docs/world-player-systems-lock` so current design docs exist.
- Do not merge PR #1 yourself unless explicitly instructed.
- Use an implementation branch such as `codex/s01-p00-bootstrap`.
- Never implement directly on `main`.

## Objectives
### 1. Verify repository/Godot boundary
Confirm `game/project.godot` is the only project descriptor and Godot commands target `game/`. Repair only clear bootstrap defects; avoid unnecessary reorganization.

### 2. Verify actual toolchain
Record what is truly available: Godot 4.7.2, headless/editor invocation, Git, Android/iOS export feasibility, MCP/plugin tools and test strategy. Never claim mobile export passed if the environment cannot run it.

### 3. Establish reusable validation
Create/update `harness/build/S01-P00.md` with reproducible commands for project import/parse, headless boot/smoke checks, script checks available in Godot 4.7.2, and repository status/diff checks.

### 4. Investigate voxel dependency only
Voxel Tools / `godot_voxel` is the primary smooth-voxel candidate, not an unquestioned permanent dependency.
- inspect Godot 4.7.2-compatible release/build paths;
- choose a first prototype route: GDExtension vs module/custom build;
- record exact version/commit/release candidate to pin;
- record Android/iOS implications;
- do not vendor huge/generated binaries silently;
- do not invent a custom voxel engine.
Write `research/VOXEL_TOOLS_INTEGRATION.md` if no current equivalent exists.

### 5. Refresh Season 1 context packets
Ensure `harness/context/` packets for S01-P01..P04 match current `PLANS.md`. Each packet should contain only objective, in/out scope, required references, acceptance criteria, checkpoints and risks. Remove superseded Terrain3D/heightmap assumptions.

### 6. Do not prematurely implement systems
Out of scope: island generator, player, LPC runtime, inventory, water simulation, farming, mobs and combat.

## Subagents
Maximum 2, only for independent voxel-integration research and/or repository/context audit. No overlapping edits.

## Required checkpoint
Run all available bootstrap validations, inspect diff/status, ensure no secrets/local-machine paths, commit a small validated checkpoint and push the implementation branch.

## Done when
- repository/Godot boundary verified;
- tool availability recorded accurately;
- reusable validation commands exist;
- voxel dependency recommendation/pin/mobile risks documented;
- S01-P01..P04 context packets are current/concise;
- project still opens/parses as far as environment permits;
- no gameplay falsely claimed complete;
- checkpoint committed/pushed.

## Final handoff
Return compactly: branch + commit SHA, files changed, validations/pass-fail, chosen voxel prototype strategy and why, environment limitations, risks/blockers, exact next task for S01-P01. Do not paste long logs or agent transcripts.