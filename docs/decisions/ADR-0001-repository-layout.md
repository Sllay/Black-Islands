# ADR-0001 — Repository Layout

Status: Accepted

## Decision

The Godot project lives at `game/` and `project.godot` lives at `game/project.godot`.

Documentation, agent instructions, research, build/context logs and repository automation stay outside the Godot project root.

## Why

This prevents Godot import noise, keeps Codex/orchestration material out of the shipped project and makes the product boundary explicit.

## Consequence

Any command that invokes Godot for the project must target `game/`.
