# Black Island — Agent Contract

This file is the root contract for Codex and every delegated agent.

## 1. Repository boundary

- The Godot project root is **`game/`**.
- `game/project.godot` is the only project descriptor.
- `docs/`, `agents/`, `harness/`, `research/` and root automation are **not** Godot runtime content.
- Do not move documentation into `game/`.

## 2. Product rule

A phase is not complete because scripts exist. Every phase must finish with a playable/testable increment reachable from the real game or the dedicated test scene.

## 3. Engine and platform

- Target engine: Godot 4.7.2.
- Mobile-first, landscape fullscreen.
- Desktop exists primarily for development/testing unless a phase says otherwise.
- Do not change engine version, renderer strategy or a pinned dependency without an ADR.

## 4. Progressive disclosure

Do not preload the whole repository into context.

Read in this order only as needed:
1. `AGENTS.md`
2. current phase file under `harness/context/`
3. relevant architecture/design document
4. relevant ADRs
5. implementation files

Do not reread the full GDD for narrow implementation tasks.

## 5. Subagents

Subagents are not the default.

Use them only for independent research, isolated implementation, independent testing/review or clearly separable components.

Rules:
- normal maximum: 2–3 concurrent subagents;
- delegation depth: 1;
- two agents must not edit the same files concurrently;
- a subagent returns a compact handoff: result, files changed/read, tests, risks, unresolved items;
- do not paste entire subagent transcripts back into the parent context.

See `agents/SUBAGENTS.md`.

## 6. Git/checkpoints

- `main` represents validated work.
- Season work uses `season/<season-name>`.
- implementation branches use `codex/<season>-<phase>-<scope>`.
- Commit and push a validated checkpoint before long/manual/destructive test sessions.
- Prefer small recoverable checkpoints over one giant commit.
- Never rewrite `main` history.

## 7. Implementation philosophy

- Reuse mature Godot-compatible systems when they solve the actual problem.
- Research before inventing a large subsystem from scratch.
- Wrap third-party systems behind Black Island interfaces so they remain replaceable.
- Prefer typed, modular, data-driven code.
- Content creation must trend toward editor tools/resources rather than producer code edits.
- Runtime truth belongs in data/state, not in whether a Scene happens to be loaded.

## 8. Mobile performance

- SceneTree mutations stay on the main thread.
- Worker threads prepare data; the main thread applies Nodes/resources that require SceneTree access.
- Pool frequently created runtime objects.
- Avoid per-frame allocations in hot paths.
- Prefer batched rendering/instancing for large repeated populations.
- Profile on a real mobile device before calling an optimization phase complete.

## 9. AI/LLM rule

Black Island must remain a complete game with no network and no LLM.

An LLM may propose social/narrative intent. It must never directly mutate authoritative world state.

Required chain:
`LLM -> structured proposal -> local validator -> event queue -> local systems/LimboAI`.

Never commit provider API keys.

## 10. Definition of done

For each phase:
- acceptance criteria pass;
- game still boots;
- playable path exists;
- regression checks pass;
- phase build/context log is updated;
- important architectural changes get an ADR;
- validated checkpoint is committed and pushed.
