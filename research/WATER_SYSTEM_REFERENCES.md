# Water System References — 2026-10-28

Research note, not authoritative gameplay spec. Authoritative Black Island design is `docs/architecture/WATER_AND_HYDROLOGY.md`.

## Family Time

Public development material from sgthale describes a water system that:

- flows downhill;
- accumulates into puddles, ponds, lakes and rivers;
- pushes player/creatures according to flow speed;
- supports water movement/physics effects;
- later connects flowing water to machinery/water-wheel gameplay.

A September 2026 development post described the water simulation as running at very high internal update rate (claimed 500 frames/steps per second), but the public material reviewed does **not** disclose the implementation algorithm/source code.

Therefore Black Island uses Family Time only as a behavioral/feel reference.

References:

- https://www.patreon.com/sgthale/posts/family-time-2-169281966
- public development post indexed as "Family Time Development Part 10 - More Pup Behaviors and Water Physics!"
- https://sgthale.itch.io/family-time/community

## Godot voxel/cellular references

### eric-patton/godot-effects

Repository contains a portable C# voxel-water demonstration with discrete water levels, river/waterfall classification, swimming/buoyancy and visual quality tiers.

Useful ideas:

- simulation/render separation;
- calm/river/waterfall classifier;
- one voxel-world interface seam;
- quality tiers;
- foam/mist presentation driven by classification.

Cautions:

- very young/small repository at research time;
- Godot 4.6/.NET oriented;
- not treated as mature shipping dependency without independent review/benchmark.

https://github.com/eric-patton/godot-effects

### paulrobello/voxel-world fluid documentation

Documents a sparse water grid using per-cell mass, active-cell tracking, double-buffered changes, downward priority, horizontal equalization and stability sleep.

Useful algorithmic reference for Black Island's planned sparse active-set solver.

https://github.com/paulrobello/voxel-world/blob/main/docs/PHYSICS.md

### Waterways / Waterways .NET

Godot river-generation tools with flow direction/river meshes and buoyancy support.

Useful rendering/authored-macro-flow reference, but not a full time-dependent volumetric fluid simulation.

- https://godotengine.org/asset-library/asset/805
- https://godotengine.org/asset-library/asset/2607

## Terrain dependency relationship

Zylann Voxel Tools is being evaluated for terrain/SDF/Transvoxel and streaming. It is not assumed to provide Black Island's dynamic water gameplay solver.

Water consumes terrain solidity/edits through a project-owned interface.

## Black Island conclusion

Do not simulate physically correct Navier-Stokes water.

Use a gameplay-focused sparse discrete-volume/cellular solver:

- active cells only;
- gravity first;
- horizontal equalization;
- optional bounded pressure behavior;
- sleeping stable regions;
- lower simulation tick rate + visual interpolation;
- macro river/ocean shortcuts;
- flow vector exposed to gameplay;
- waterfall classification for rendering/VFX.

This targets the visible/gameplay behavior players care about while preserving mobile performance.
