# ADR-0005 — Ephemeral Cave Runs + Persistent Anchored Floors

Status: Accepted

## Decision

Ordinary cave floors are procedural run-scoped worlds, not permanently persistent save maps.

During one CaveRun, floor state may remain available for backtracking through session/hot-cache data. Returning to the surface/ending the run allows unanchored floors to be discarded and regenerated on a later run.

A rare progression item (`CaveAnchorTotem` technical placeholder) can convert an eligible floor into persistent anchored state.

Anchoring progresses consecutively through floor depth and powers the cave elevator network.

## Why

This provides:

- renewable procedural underground exploration;
- renewable ore/resource layouts without global respawn hacks;
- stronger replay value;
- lower permanent save growth for ordinary floors;
- meaningful rare investment when a player wants to preserve a strategic floor/base;
- a natural elevator progression loop.

## Invariants

1. Surface world persistence is independent from cave run lifecycle.
2. An unanchored floor is not guaranteed to survive a completed/abandoned run.
3. Backtracking during the same active run should preserve temporary state when technically practical.
4. Anchored floors persist authoritative terrain/structure/world data even when their Scene unloads.
5. A persistent anchor cannot skip the required progression chain.
6. Elevator destinations are derived from valid anchored progression, not arbitrary floor numbers.
7. Regenerating ordinary caves must never overwrite an anchored floor.

## Consequence

The older assumption that every `MineFloorData` remains permanently authoritative after leaving the cave is superseded.

Detailed lifecycle lives in `docs/design/CAVES_AND_ANCHOR_PROGRESSION.md`.
