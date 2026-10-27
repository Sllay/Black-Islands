# ADR-0002 — Surface Terrain Strategy

Status: Superseded by ADR-0004

## Original decision

The original Foundation direction avoided a volumetric voxel surface and preferred a smooth heightmap terrain system, with Terrain3D as the leading candidate, plus a Black Island-owned logical cell/stud layer for gameplay semantics.

## Why this is superseded

Further design work established that Black Island needs precise runtime terrain removal, digging, channels, local deformation, material-aware farming/path painting and predictable control over the exact volume opened by an edit. A heightmap-first surface makes those requirements substantially harder and constrains future terrain gameplay.

The accepted replacement is documented in `ADR-0004-smooth-voxel-world-and-build-grid.md`:

- volumetric voxel data is authoritative for terrain;
- the visible surface is smooth rather than blocky;
- construction uses a separate, integer-aligned build grid and structural socket graph;
- mines/caves remain separate generated floor worlds rather than one continuous underground surface volume.

This file remains as historical context so future agents do not accidentally reintroduce the abandoned heightmap-first assumption.
