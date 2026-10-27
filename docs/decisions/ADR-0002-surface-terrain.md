# ADR-0002 — Surface Terrain Strategy

Status: Accepted for validation in Foundation

## Decision

Do not build a bespoke voxel engine for the Chapter 1 surface.

Use a smooth terrain system (preferred candidate: Terrain3D) for presentation and terrain height/material data, combined with a Black Island-owned logical cell/stud layer for gameplay semantics.

Mines remain separate floor worlds.

## Why

This preserves smooth Roblox-like terrain goals while avoiding the cost/risk of implementing volumetric terrain where it is not required.

## Revisit if

Mobile validation shows the chosen terrain dependency cannot meet memory/rendering/runtime-edit requirements.
