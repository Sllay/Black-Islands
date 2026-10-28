# Water & Hydrology Architecture

Status: Accepted behavior direction; implementation constants require profiling.

## Goal

Black Island water should behave as gameplay water, not only a shader plane.

Desired behavior includes:

- rivers and lakes generated with the island;
- water moving downhill;
- accumulation into puddles/basins;
- player-dug channels able to redirect local water;
- currents capable of affecting the player, NPCs, mobs and floating objects;
- waterfalls where water loses elevation;
- swimming/underwater state;
- farming tools able to refill from valid water;
- long-distance ocean presentation without simulating an ocean worth of fluid cells.

Family Time is a behavioral reference for the desired sense of flowing/accumulating water, not a code dependency.

## Do not simulate the entire ocean

Split water into three domains.

### 1. Ocean field

The ocean beyond the island is primarily an analytic/static sea-level body with shader waves and local interaction sampling.

It does not run the full cellular water simulation across the horizon.

### 2. Generated inland water

Rivers/lakes/streams are initialized from world generation and represented by water volumes/cells where gameplay may interact with them.

Stable areas may sleep and consume effectively no update work until changed.

### 3. Dynamic local water

Terrain edits, sources, drains, waterfalls and disturbed channels activate a sparse local simulation frontier.

Only active water cells are stepped.

## Water grid

Initial simulation cell target: 1 m horizontally, aligned with `BuildGrid` and therefore equal to 2x2 terrain voxels. Vertical water level may use finer quantization inside the cell.

Do not require one water Node per cell.

Conceptual `WaterCell`:

```text
amount           # quantized/fixed-point volume, e.g. 0..255
surface_level
flow_x
flow_y
flow_z
source_flags
sleep_state
stable_ticks
water_type
```

Use compact integer/fixed-point representation where possible for deterministic behavior and network/save friendliness.

## Sparse active-set simulation

Maintain:

- compact water storage by region/chunk;
- active cell queue/frontier;
- sleeping stable cells;
- pending/double-buffered flow changes.

Simulation order per tick:

1. gravity/downward transfer has highest priority;
2. horizontal equalization follows local head/level difference;
3. optional pressure/upward transfer is allowed only where required by enclosed water behavior;
4. apply pending transfers together so iteration order does not create directional bias;
5. calculate resulting flow vector/velocity;
6. mark stable cells asleep after a threshold;
7. activate neighbors when terrain/water changes.

Avoid scanning all water in all loaded chunks every tick.

## Tick rate vs render rate

Water simulation does not need to execute at visual frame rate.

Initial target:

- simulation around 10-20 Hz under normal gameplay;
- adaptive lower rate for distant/slow regions;
- visual interpolation at render frame rate;
- emergency budget cap when active cell count spikes.

A high internal update frequency may be benchmarked for tiny local regions, but Black Island must not assume desktop-style hundreds-of-Hz fluid stepping is appropriate on mobile.

## Terrain integration

Terrain is authoritative for solidity.

When `TerrainEditService` changes an AABB:

`terrain edit -> WaterService receives dirty region -> reactivate local water cells -> recompute available volume/flow -> update presentation`

Examples:

- dig a trench connecting lake to lower ground -> water begins filling it;
- close a channel with terrain/build structure -> flow changes/stops;
- remove bank -> local basin drains;
- dig under water -> downward cascade can form a waterfall.

Structures can expose `water_blocking`/permeability semantics separately from terrain solidity.

## Rivers

Generated river topology provides:

- initial water source/level;
- desired downstream route;
- minimum bed/channel geometry;
- source/sink/boundary rules.

After generation, local simulation may react to player terrain changes instead of treating the river as immutable decoration.

Large river flow should combine authored/generated macro flow with local cell simulation so every kilometer of river does not require constantly active cells.

## Lakes

Lakes initialize as stable sleeping bodies at a known level/basin.

Only shore edits, connected channels, drains/sources or nearby dynamic disturbances reactivate portions of the lake.

## Waterfalls

Waterfalls are a state/presentation classification produced by flow, not a special hand-placed gameplay object.

If significant water transfers downward through exposed air across a vertical threshold:

`flow classification = WATERFALL`

Presentation can spawn/reuse:

- vertical sheet/ribbon mesh;
- foam at lip/base;
- mist/splash particles;
- waterfall audio emitter;
- turbulence/current volume.

Do not voxel-render every falling droplet.

## Current force

The water solver exposes a sampled flow vector field.

Characters/objects query:

`sample_water(position) -> depth, flow_velocity, water_type`

Gameplay applies bounded current force according to actor properties:

- player swimming resistance;
- mob mass/swim ability;
- floating item/bag behavior;
- future boat/raft behavior.

The water solver does not directly manipulate arbitrary scene nodes.

## Swimming

Player water state is based on sampled depth relative to feet/hips/head.

Possible semantic states:

- wading;
- swimming;
- submerged;
- carried-by-current.

Movement controller consumes water depth/current as inputs. Water does not replace the player state machine.

## Visual water

Simulation and rendering are separate.

Renderer may classify cells/patches as:

- calm lake/ocean;
- river/flowing surface;
- shallow shore;
- waterfall;
- turbulent/foam.

Generate/coalesce water surface patches by region rather than drawing a cube per water cell.

Far ocean uses a low-cost dedicated surface and lower-quality material tier.

## Quality tiers

Mobile quality tiers can reduce:

- reflection/refraction complexity;
- foam density;
- waterfall particles;
- simulation radius/frequency;
- current visual detail;
- underwater post effects;
- far-water wave complexity.

Gameplay water amount/flow rules must remain functionally consistent even when visual quality is lower.

## Persistence

### Surface island

Stable generated oceans/rivers/lakes come from seed/profile.

Persist only deviations that matter:

- terrain edits affecting channels/basins;
- player-created water sources/sinks if later supported;
- stable dynamic water deviations in edited areas when required.

A water region should settle/sleep before unload where practical. If not settled, serialize compact active state for that region.

### Cave floors

Unanchored cave-run water state follows cave-run lifecycle and can be discarded with the generated floor.

Anchored/persistent cave floors store required water deviations along with their terrain state.

## Reference implementations

External projects may be studied, not blindly adopted. Candidate references include sparse/cellular voxel water examples for Godot and portable voxel-water demos. Any third-party code must pass license, mobile performance and architecture review before integration.

Black Island owns the interface:

```text
IWaterWorld
- sample(position)
- notify_terrain_changed(aabb)
- add_source(...)
- remove_source(...)
- serialize_region(...)
- activate_region(...)
```

## Performance failure modes to avoid

- scanning every water cell every frame;
- dynamic simulation for the entire ocean;
- one Node3D per water cell;
- rebuilding giant water meshes after one changed cell;
- synchronous cascade simulation until fully settled in one frame;
- using physics rigid bodies as the primary liquid solver;
- copying large fluid grids between CPU/GPU each frame.

## Chapter 1 implementation order

1. static ocean + swimming volume;
2. generated sleeping lake/river grid;
3. sparse gravity/horizontal propagation;
4. local terrain-edit response;
5. current forces;
6. waterfall classifier/presentation;
7. performance/quality tiers;
8. advanced machinery/current-powered systems later.
