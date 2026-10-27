# Building & Structural Support — Design/Technical Spec

Status: Accepted direction; constants require gameplay/mobile validation.

## Goals

Black Island uses precise square-grid modular construction inspired by survival builders such as ARK, while avoiding double walls, floating megastructures and chain-collapse bugs.

The system must support naturally emergent houses, second floors, platforms and bridges without creating special-case `BridgeSystem` or `HouseSystem` logic.

## Spatial model

Construction is aligned to a square `BuildGrid`. The build unit is an integer multiple of terrain voxel size.

The build model contains three occupancy domains:

- **Cell slots** — foundations, ceilings/platforms, large floor-bound pieces.
- **Shared edge slots** — walls, window walls, door frames, fences and similar boundaries.
- **Point/center sockets** — pillars, posts and other vertical supports.

### Shared edges

Adjacent cells reference the same edge object. If Foundation A's east edge touches Foundation B's west edge, both references resolve to one `BuildEdge`.

Therefore one wall on that boundary occupies the edge once. A second wall cannot be placed from the neighboring foundation side. This prevents accidental double-thickness walls by construction, not by visual collision hacks.

## Piece definitions

Structure behavior is data-driven. A `StructureDefinition` should eventually describe at least:

- stable ID;
- footprint/occupancy domain;
- provided sockets;
- accepted socket types;
- allowed rotations;
- structural role;
- mass/load contribution;
- support transmission capacity;
- horizontal support cost;
- vertical support cost/limits where applicable;
- material/tier;
- durability/HP;
- placement collision rules;
- terrain contact requirements;
- visual scene/preview data.

Avoid hard-coded chains such as `if other is Foundation` in placement code.

## Core structural roles

### Foundation

- Normally occupies one build cell.
- Can become a **support root** only when it has valid support to terrain/ground according to the placement rule.
- A foundation placed on top of an elevated ceiling/platform is **not automatically a new root**. It inherits the existing structural provenance unless another path reaches real support.
- Provides shared edge sockets for walls and side connections.

### Ceiling / platform / flat roof

- Occupies a structural cell at an elevation.
- Same nominal footprint as a foundation so it can snap laterally and form floors, roofs and bridges.
- Can carry horizontal support only within the support budget inherited from valid roots.
- Does not magically reset cantilever distance.

### Wall / door frame / window wall

- Occupies one shared edge.
- Can transmit vertical support upward.
- A wall standing on a cantilevered platform inherits that platform's support provenance; it cannot be used to create a fresh outward cantilever budget.
- Provides upper sockets for ceilings/roof/future wall stacking according to definition.

### Pillar / post

- Occupies a center/point socket.
- Can transmit vertical support.
- It becomes a new support root only if its support chain truly reaches terrain or another accepted grounded support source.
- A floating pillar attached only to an already-cantilevered platform is not a root and cannot reset support distance.

## Socket model

Sockets have semantic types. Candidate examples:

- `FOUNDATION_SIDE`
- `FOUNDATION_EDGE`
- `STRUCTURAL_CELL_SIDE`
- `WALL_BOTTOM`
- `WALL_TOP`
- `PILLAR_BOTTOM`
- `PILLAR_TOP`
- `CELL_CENTER`
- `ROOF_EDGE`
- future stair/ramp sockets

A compatibility table/definition decides what may connect. Snap validity is semantic first, geometric second.

## Structural graph

Every placed structural piece is a node in a `SupportGraph`. Compatible physical/snap relationships create edges.

**Connectivity is not support.** A connected component can contain unsupported nodes.

A node survives only if the structural solver can assign it at least one valid support path to a real support root while satisfying:

1. path/socket compatibility;
2. directional propagation rules;
3. horizontal span limits;
4. vertical/stack limits where configured;
5. path capacity/load limits;
6. root capacity limits;
7. material/tier constraints when applicable.

## Support provenance: anti-infinite-staircase rule

Support propagation carries provenance from its root. At minimum a propagated support candidate needs information equivalent to:

```text
SupportPath
- root_id
- horizontal_span_cost
- vertical_cost / stack data
- remaining_path_capacity
- propagation direction/context
- path length / quality score
```

Only a **real root** resets `horizontal_span_cost`.

Example with Chapter-1 style max free span of 2:

```text
Grounded Foundation [root, span 0]
  -> Ceiling A [span 1]
  -> Ceiling B [span 2]
  -> Ceiling C [span 3] INVALID
```

Putting a wall on Ceiling B does not reset span:

```text
Foundation(root)
  -> Ceiling A(1)
  -> Ceiling B(2)
       -> Wall(inherits root/span 2)
            -> outward Ceiling C still exceeds allowed horizontal reach
```

The wall may support pieces vertically and may support geometry back toward/inside the already-supported footprint when rules permit, but cannot create a new outward support origin.

If a pillar under Ceiling B genuinely reaches terrain:

```text
Terrain
  -> Pillar [new real root]
       -> Ceiling B [span 0/near-root]
       -> Ceiling C [span 1]
       -> Ceiling D [span 2]
```

Now the extension is valid because support has a new grounded origin.

This prevents the exploit:

`wall -> ceiling outward -> wall -> ceiling outward -> ... -> sky`.

A foundation placed on an unsupported/elevated ceiling follows the same rule: it is structural geometry, not a ground root.

## Load/capacity: anti-one-pillar-planet rule

Distance rules alone are insufficient. Each piece contributes structural load and support carriers/roots have capacity.

Conceptually:

```text
wood pillar capacity < stone pillar capacity < reinforced pillar capacity
small floor load < heavy stone floor/load-bearing machine/etc.
```

A single grounded pillar therefore cannot support an unlimited connected city even when every tile is within some topological path.

### Solver stages

After placement, removal or damage changes the graph, solve only the affected structural component/region whenever possible.

Recommended logical stages:

1. **Discover real roots** — grounded foundations, grounded pillars/posts or explicit future anchors.
2. **Propagate candidate support paths** from all roots through compatible graph edges.
3. **Reject invalid paths** exceeding span, direction, stack or material constraints.
4. **Keep multiple candidate roots/paths** for pieces where possible; do not store only one parent dependency.
5. **Resolve load/capacity** deterministically across valid candidate roots/paths.
6. Mark nodes with at least one satisfiable support assignment as supported.
7. Mark the remainder unsupported and schedule collapse.

For Chapter 1, the load allocator may begin with a deterministic bounded candidate/greedy solver if benchmarks and tests prove it stable. Architecture must allow a stronger allocation method later without changing save semantics.

## Why multiple support paths matter

Consider a bridge with pillars P1 and P2:

```text
Ground  P1 ---- A ---- B ---- P2  Ground
```

B may have valid support from both directions. If P1 is destroyed, B must not collapse merely because its originally cached parent was P1.

The solver recomputes candidate support and discovers the path through P2. Only pieces that lose **all valid support paths or capacity assignments** collapse.

This is mandatory for avoiding the classic "break one pillar and the whole connected bridge disappears" bug.

## Destruction and collapse

Option B is accepted: players/mobs may destroy load-bearing pieces and unsupported structures can fail.

Flow:

`piece destroyed -> remove graph node/edges -> recompute affected component -> identify unsupported nodes -> collapse those nodes only`

Collapse presentation may be staggered rather than deleting an entire component on one frame:

- brief structural warning/crack feedback where appropriate;
- detach unsupported piece/substructure;
- fall/break VFX and sound;
- convert to debris/resource drops according to game rules;
- update occupancy and support graph incrementally/safely.

Do not recursively decide collapse with naïve `connected_piece.destroy()` calls. The graph solver is authoritative.

## Placement validation

Conceptual placement pipeline:

`selected recipe/item -> ray/probe -> BuildGrid/sockets -> snap candidate -> occupancy -> terrain contact -> structural support preview -> collision -> valid/invalid ghost -> place`

Invalid reasons should be surfaced contextually, for example:

- occupied edge/cell;
- invalid socket;
- terrain obstruction;
- missing support;
- span exceeded;
- structural capacity exceeded;
- requires ground/foundation;
- collision with protected object.

## Terrain interaction

Foundations sample terrain solidity/height/slope underneath their footprint. Exact tolerance is tunable.

Future constrained leveling may edit nearby terrain voxels to prepare small build areas, but must obey terrain-edit limits rather than flattening mountains automatically.

When construction replaces vegetation/ground props, the prop/foliage system must receive a local occupancy/suppression update; this remains part of the pending world-prop spec.

## Required tests

At minimum automated/system tests must cover:

- adjacent foundations cannot create double walls on shared edge;
- two-ceiling cantilever succeeds and third fails under chosen constants;
- wall on second cantilever does not reset outward span;
- floating pillar does not become a root;
- grounded pillar resets support reach;
- foundation placed on elevated ceiling does not become a false root;
- bridge with two independent pillars survives removal of one where alternate support remains;
- only dependent bridge section collapses when a unique support is removed;
- capacity prevents one root from supporting unlimited load;
- removing a wall only collapses upper structure that has no alternate valid path;
- support recomputation stays local enough for mobile targets.
