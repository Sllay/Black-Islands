# Codex Prompt — S01-P00 Bootstrap / Execution Readiness

Use this prompt as the first Codex task before implementation.

You are the implementation lead for Black Island, a Godot 4.7.2 mobile-first project in repository `Sllay/Black-Islands`.

Your job in this task is not to build gameplay yet. Prepare and validate the reproducible implementation baseline for Season 1 using the toolchain already chosen and pinned by the project.

## Read first
1. `AGENTS.md`
2. `docs/architecture/CODEX_DEV_ENVIRONMENT.md`
3. `PLANS.md`
4. `docs/architecture/REPOSITORY_MAP.md`
5. `docs/architecture/GAME_ARCHITECTURE.md`
6. `docs/architecture/TECH_STACK.md`
7. `docs/architecture/VOXEL_WORLD_IMPLEMENTATION.md`
8. `docs/architecture/SAVE_AND_MIGRATION.md`
9. relevant ADRs only as needed

Do not preload the entire repository/GDD. The Godot project root is `game/`.

## Branch handling
- Start from updated `main`; PR #1 is already merged.
- Pull/fetch current `main` and inspect status before edits.
- Create `codex/s01-p00-bootstrap` from current `main`.
- Never implement directly on `main`.

## Toolchain is already selected — validate, do not re-decide it
Run from repository root:

```bash
bash scripts/bootstrap_codex_env.sh
```

The expected pinned baseline is defined by `scripts/tooling/versions.env` and currently includes:

- Godot 4.7.2;
- Godot MCP 0.1.2;
- Serena 2.1.0 with GDScript LSP support;
- Voxel Tools GDExtension 1.7 / `v1.7x`;
- Node.js 22+ for Godot MCP.

Do not silently use `latest`, a different Godot version, a different voxel engine or an unverified binary.

### Godot MCP
The project-local Codex MCP entry is already in `.codex/config.toml`.

- Verify the `godot` MCP is connected.
- Call `godot_status`.
- If its live editor addon is missing/outdated, use the MCP's `godot_addon_install`, reopen/launch the exact Godot 4.7.2 project and verify the live bridge.
- Use compact MCP mode as configured; use generic Godot call tools when a specialized tool is not preloaded.
- Do not enable arbitrary runtime eval unless a specific test genuinely requires it and you document why.

### Serena
The `serena` MCP is already configured project-locally and `game/.serena/project.yml` declares GDScript.

- Verify Serena activates `game/` successfully.
- Verify the Godot built-in GDScript LSP is reachable; the wrapper may launch a headless editor on TCP 6008 when no editor is already serving it.
- Once a real `.gd` file exists, prove at least one symbol-aware query/edit/diagnostic path.
- Prefer Serena symbol/reference/rename/localized editing for existing GDScript instead of repeatedly reading and rewriting whole scripts.

## Objectives

### 1. Verify repository/Godot boundary
Confirm `game/project.godot` is the only project descriptor and Godot commands target `game/`. Repair only clear bootstrap defects; avoid unnecessary reorganization.

### 2. Verify actual toolchain
Record actual versions/results for Godot, Node, Serena, Godot MCP, Voxel Tools load, Git, headless/editor invocation, Android/iOS export feasibility and test strategy.

Never claim mobile performance/export passed when the environment only proves desktop/headless behavior.

### 3. Establish reusable validation
Create/update `harness/build/S01-P00.md` with reproducible commands/results for:

- bootstrap/version verification;
- project import/parse;
- headless editor boot/smoke;
- Godot MCP status/editor bridge;
- Serena/GDScript semantic path where possible;
- Voxel Tools extension/class load;
- repository status/diff checks;
- Android/iOS feasibility separately from real device proof.

### 4. Validate the pinned Voxel Tools route
The first prototype route is already selected as Voxel Tools GDExtension 1.7. Do not spend the phase choosing a different engine.

Validate and record:

- exact pinned release/hash matches;
- extension loads under Godot 4.7.2;
- relevant smooth SDF/Transvoxel classes/APIs are available;
- known upstream warning that the GDExtension path has less testing than module builds;
- Android/iOS binary/export implications visible from the release/config;
- fallback/risk note if the extension fails a required platform later.

Write/update `research/VOXEL_TOOLS_INTEGRATION.md` with evidence and prototype recommendations. Do not build the actual island yet.

### 5. Refresh Season 1 context packets
Ensure `harness/context/` packets for S01-P01..P04 match current `PLANS.md` and `harness/prompts/`. Each packet should contain only objective, in/out scope, required references, acceptance criteria, checkpoints and risks.

Remove superseded Terrain3D/heightmap assumptions.

### 6. Do not prematurely implement systems
Out of scope: island generator, player gameplay, LPC runtime, inventory, water simulation, farming, mobs and combat.

## Subagents
Maximum 2, only for independent environment/voxel validation and/or repository/context audit. No overlapping edits.

## Required checkpoint
Run all available bootstrap validations, inspect diff/status, ensure no secrets or machine-specific absolute paths were committed, then commit and push the validated implementation branch.

## Done when
- repository/Godot boundary verified;
- pinned toolchain is installed/validated rather than guessed;
- Godot MCP is usable and live addon status is known;
- Serena is usable for GDScript semantic work or an evidenced environment limitation is recorded;
- reusable validation commands/results exist;
- Voxel Tools 1.7 GDExtension load/risk/mobile notes are documented;
- S01-P01..P04 context packets are current/concise;
- project still opens/parses as far as environment permits;
- no gameplay falsely claimed complete;
- checkpoint committed/pushed.

## Final handoff
Return compactly: branch + commit SHA, files changed, exact installed versions, validations/pass-fail, Godot MCP status, Serena status, Voxel Tools status, environment limitations, risks/blockers and exact next task for S01-P01. Do not paste long logs or subagent transcripts.
