# Black Island

Black Island is a mobile-first 2.5D life/farming RPG, village-management game and action RPG built with Godot 4.7.2.

## Repository contract

The repository is intentionally split between the playable Godot product and the development/orchestration layer.

- `game/` — **the Godot project root**. `game/project.godot` lives here. Only runtime/editor content that belongs to the Godot project goes here.
- `docs/` — GDD, technical architecture, design specifications and architectural decisions.
- `agents/` — Codex/subagent roles, delegation rules and handoff contracts.
- `harness/` — build plans, phase context, reviews, checkpoints and development logs.
- `research/` — evaluated external projects, algorithms and technical references.
- `scripts/` — repository-level automation that is not part of the game runtime.

## Core production rule

Every development phase must end in a playable, testable increment. Backend-only phases are not considered complete.

## Current target

- Engine: Godot 4.7.2
- Platform priority: mobile, landscape fullscreen
- Chapter: Chapter 1 vertical slice
- Production model: 3 Seasons × 4 Phases
- Surface world: smooth 3D island + logical stud/grid layer
- Characters: LPC-based 2D visuals in a 3D world
- NPC execution: local-first AI; optional LLM-assisted social direction

See `docs/architecture/REPOSITORY_MAP.md` for the authoritative repository map and `AGENTS.md` for Codex rules.
