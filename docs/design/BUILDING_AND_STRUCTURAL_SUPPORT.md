# Building & Structural Support — Design/Technical Spec

Status: Accepted core direction; exact piece dimensions/content remain tunable.

## Goals

Black Island uses precise square-grid modular construction inspired by survival builders such as ARK while preventing:

- double walls;
- unsupported floating platforms;
- infinite `wall -> ceiling -> wall -> ceiling` staircases;
- one grounded point incorrectly validating an arbitrarily distant connected castle;
- chain-collapse bugs where destroying one pillar deletes a bridge that still has another valid support path.

The system should naturally support houses, towers, second floors, platforms and bridges through one rule set.

## Spatial model

Construction is aligned to a square `BuildGrid`.

Initial scale:

- one build cell = 1 m x 1 m horizontal footprint;
- terrain voxel = 0.5 m;
- structures snap on integer build coordinates/elevations.

The build model contains three occupancy domains:

- **Cell slots** — foundations, ceilings/platforms/flat roofs and large floor-bound pieces;
- **Shared edge slots** — walls, window walls, door frames, fences and similar boundaries;
- **Point/center sockets** — pillars/posts and vertical supports.

## Shared edges

Adjacent cells reference one shared boundary object.

If Foundation A east touches Foundation B west, both resolve to the same `BuildEdge`.

One wall occupying this edge blocks placement from either side. Double-thickness accidental walls are impossible by data ownership rather than collision tricks.

## Structure definitions

`StructureDefinition` should contain at least:

- stable ID;
- footprint/occupancy domain;
- provided sockets;
- accepted socket types;
- allowed rotations;
- structural role;
- support propagation rules;
- durability/HP;
- material/tier;
- placement collision rules;
- terrain contact requirements;
- visual scene/preview data;
- build cost.

### Material/tier rule

Wood, stone and later structural materials do **not** receive different support reach simply because they are stronger materials.

The main differences are:

- HP/durability;
- resistance/damage interactions;
- cost;
- appearance;
- future repair/raid properties.

A stone pillar does not magically support farther than a wood pillar under the baseline construction model.

## Real support roots

A support root is a structure/anchor that genuinely reaches accepted ground/world support.

Typical roots:

- foundation correctly seated on valid terrain;
- pillar/post whose vertical chain reaches terrain/grounded structure according to rule;
- explicit future world anchor.

Not roots:

- foundation merely placed on an elevated ceiling;
- pillar standing on top of a cantilevered ceiling without reaching ground;
- wall standing on an already cantilevered platform;
- arbitrary connected geometry.

A fake/floating support never resets structural reach.

## Baseline horizontal reach

Initial rule:

**A real support origin provides up to two ceiling/platform cells of unsupported horizontal reach in every horizontal direction, including diagonals where sockets permit.**

Conceptually:

```text
. . . . .
. C C C .
. C F C .
. C C C .
. . . . .
```

with another outward ring available up to the configured reach of 2 around the grounded support origin.

Exact footprint/socket geometry decides what actually connects; the support metric does not create geometry by itself.

## Support provenance

Connectivity is not the same as structural support.

Every supported structural node may hold one or more `SupportCandidate` records.

Conceptual candidate:

```text
SupportCandidate
- root_id
- root_grid_xz
- source/path provenance
- horizontal_dx
- horizontal_dz
- horizontal_distance
- vertical_chain_state
- propagation_direction/context
```

For the default square build system, horizontal reach can use Chebyshev/grid distance where diagonal support is explicitly allowed:

`distance = max(abs(dx), abs(dz))`

A candidate is valid only while distance from its **real root/support column** remains <= configured reach.

Most importantly: walls, elevated foundations and floating pillars **inherit** the candidate. They do not replace `root_grid_xz` with their own position.

## Anti-infinite-staircase rule

Example:

```text
Ground Foundation root at X=0
Ceiling at X=1 -> valid distance 1
Ceiling at X=2 -> valid distance 2
Wall on X=2   -> inherits root X=0, distance 2
```

Trying to place a new ceiling outward at X=3 through that wall:

`distance from real root = 3 -> INVALID`

The wall did not create new reach.

A ceiling placed from the same wall **back toward** the real root may be valid if its resulting position lies inside the already supported envelope.

This produces the intended physical intuition: vertical geometry can carry support upward, but cannot invent horizontal foundation support farther away from ground.

## Grounded pillar reset

If a pillar beneath the distant platform truly reaches valid ground:

```text
Terrain
  |
Pillar at X=2  -> new real root/support column
  |
Ceiling X=2
```

Then the new root provides its own two-cell horizontal envelope:

- X=3 -> distance 1 from pillar root;
- X=4 -> distance 2;
- X=5 -> invalid unless another genuine support root exists.

A pillar placed upward from the top of X=2 without reaching terrain does not do this.

## Vertical propagation

Walls/pillars may propagate valid root provenance upward through compatible sockets.

Example:

```text
Ground Foundation (root X=0)
  |
Wall
  |
Wall
  |
Upper floor
```

The upper floor still knows its support root/projection comes from X=0.

This permits multi-story buildings while preventing each new floor from resetting horizontal reach.

## Foundation on ceiling

A foundation piece may be allowed on top of ceiling/platform geometry for design/snap purposes.

Unless it independently contacts valid ground through an accepted support chain, it is not a new root.

It inherits all support candidates from below and cannot extend farther than those candidates permit.

## Multiple support paths

A node must not cache one permanent parent as "the thing supporting me".

It may have support from many roots.

Bridge example:

```text
Ground P1 ---- A ---- B ---- P2 Ground
```

B may be valid from both P1 and P2.

If P1 is destroyed:

1. remove P1 and affected graph edges;
2. recompute support candidates in the affected region/component;
3. B keeps the P2 candidate if a valid connected path remains;
4. only pieces with zero valid real-root candidates collapse.

This prevents the classic bug where one removed pillar destroys an otherwise-supported entire bridge.

## Structural solver

After placement/removal/damage changes topology:

1. discover/revalidate real roots in affected region;
2. propagate support candidates through compatible sockets/edges;
3. preserve each candidate's original root coordinates/provenance;
4. reject candidates outside horizontal reach/direction rules;
5. reject broken/incompatible paths;
6. retain multiple valid candidates where they exist;
7. node is supported if at least one valid candidate survives;
8. unsupported nodes enter collapse handling.

No recursive `connected_piece.destroy()` authority.

## Why no global load-capacity model

Chapter 1 intentionally does not simulate structural engineering mass/load capacity.

A pillar does not fail because too many total kilograms are connected somewhere above it. The gameplay rule is spatial support reach + valid path + world height.

This keeps building understandable and ARK-like while still preventing unsupported megastructures.

Future special content may introduce unique structural limits through explicit definitions, but do not silently add wood-vs-stone load mathematics.

## Height limit

Initial world/build ceiling is approximately 100 m above the world reference/sea-level plane.

Above the allowed construction volume:

- placement preview becomes invalid;
- reason = `WORLD_HEIGHT_LIMIT`;
- no structure can bypass the rule through snapping.

This is a world rule, not structural-material capacity.

## Core structural roles

### Foundation

- occupies a build cell;
- root only when grounded/valid;
- provides edges for walls and side structural snaps;
- can connect laterally to foundations/platforms where definitions permit.

### Ceiling / platform / flat roof

- occupies a structural cell at an elevation;
- can act as floor, roof or bridge deck;
- receives/transmits existing support candidates;
- does not reset horizontal support distance.

### Wall / door frame / window wall

- occupies one shared edge;
- transmits support vertically through compatible top/bottom sockets;
- retains original root provenance;
- may support upper floors only where their final positions remain valid under a real root candidate.

### Pillar / post

- occupies center/point socket;
- transmits support vertically;
- becomes a root only when its downward chain genuinely reaches ground/accepted root condition.

## Sockets

Candidate semantic types:

- `FOUNDATION_SIDE`
- `FOUNDATION_EDGE`
- `STRUCTURAL_CELL_SIDE`
- `WALL_BOTTOM`
- `WALL_TOP`
- `PILLAR_BOTTOM`
- `PILLAR_TOP`
- `CELL_CENTER`
- `ROOF_EDGE`
- future stair/ramp sockets.

Compatibility is data-driven; snap validity is semantic first, geometric second.

## Placement validation

`selected piece -> ray/probe -> BuildGrid/socket candidate -> occupancy -> terrain/contact -> support-candidate preview -> collision -> world-height rule -> valid/invalid ghost -> transaction/place`

Invalid reasons include:

- occupied edge/cell;
- invalid socket;
- terrain obstruction;
- missing support root/path;
- horizontal support reach exceeded;
- requires foundation/ground;
- protected collision;
- world height limit.

## Destruction and collapse

Option B is accepted: destroying load-bearing/support pieces can collapse unsupported structures.

Flow:

`piece destroyed -> update topology -> recompute affected support graph -> supported pieces remain -> unsupported subset scheduled to collapse`

Presentation can be staggered:

- crack/warning feedback where useful;
- detach/fall/break animation;
- VFX/audio;
- configured debris/resource drops;
- occupancy cleanup.

Support recomputation decides truth before presentation destroys anything.

## Foundations and foliage

Successful foundation placement suppresses grass/foliage in its footprint/clearance region. Demolition removes that suppression and natural regrowth may occur later if terrain remains eligible.

See `FARMING_AND_FOLIAGE.md`.

## Required tests

- adjacent foundations share one wall edge;
- one grounded root supports ceiling distance 1 and 2;
- third outward ceiling fails;
- diagonal reach follows configured 8-direction metric;
- wall placed at distance 2 does not reset outward support;
- inward placement from that wall remains possible when inside original envelope;
- floating pillar does not reset support;
- grounded pillar does reset support at its real column;
- foundation placed on elevated floor is not a false root;
- stacked walls propagate the same root vertically;
- bridge with two support roots survives loss of one where alternate candidate remains;
- only the genuinely unsupported bridge section collapses;
- wood and stone variants have equal support reach but different durability;
- world height limit cannot be bypassed through snaps;
- recomputation remains local/mobile-safe.
