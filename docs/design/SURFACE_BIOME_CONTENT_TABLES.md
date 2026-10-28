# Surface Biome Content Tables — Design/Technical Spec

Status: initial Chapter 1 content baseline; density values require generation/visual tuning.

## Surface biome families

Initial island direction:

1. Beach / Tropical Coast
2. Tropical Plains
3. Tropical Hills
4. Central Forest

The island is not split into hard rectangular biome zones. Environmental fields blend them.

Useful fields:

- distance to coast;
- elevation;
- slope;
- moisture;
- local terrain material/geology;
- noise/domain-warp variation;
- POI exclusion/influence masks.

## Macro layout direction

- Beach/Tropical Coast wraps most/all of the island edge.
- Tropical Plains form much of the transition between coast and interior.
- Interior terrain mixes roughly broad flat/soft terrain with significant smooth elevated/hill regions rather than one flat plate.
- Central Forest occupies denser interior zones, influenced by moisture/terrain suitability rather than a perfect circular ring.

The requested visual feeling is approximately half calmer/flatter traversable terrain and half noticeable but smooth natural elevation across the appropriate interior regions.

## Beach / Tropical Coast

Terrain:

- sand;
- wet sand near waterline;
- occasional exposed stone;
- gentle dunes/shore shaping;
- river-mouth/lagoon transitions where generated.

Primary props:

| Prop family | Density | Notes |
| --- | --- | --- |
| Coconut/palm trees | Low-Medium | clusters, not uniform grid |
| Driftwood | Low | shoreline biased |
| Shell/debris visuals | Medium visual-only | batch/decoration |
| Beach grass | Sparse | suppressed near wet line |
| Small rocks | Low-Medium | clustered |
| Tropical shrubs | Sparse | higher near inland transition |

Gameplay resources:

- wood from palms;
- common stone;
- beach forage as later content;
- fish/water ecology nearby.

## Tropical Plains

Terrain:

- grass-dominant smooth terrain;
- dirt patches;
- low slopes;
- occasional exposed stone;
- ideal settlement/farming candidates.

Primary props:

| Prop family | Density | Notes |
| --- | --- | --- |
| Grass blades/clumps | High | MultiMesh/procedural foliage |
| Small flowers | Low-Medium | decorative clusters |
| Bushes | Medium | forage/resource candidates |
| Small trees | Low-Medium | spaced for sightline |
| Rocks | Low-Medium | resource + visual variants |
| Fallen branches/logs | Low | local detail |

Gameplay:

- best early building/farming region;
- passive fauna common;
- good village candidate area;
- roads/farm plots visibly suppress grass.

## Tropical Hills

Terrain:

- smooth elevation and ridges;
- more exposed rock;
- steeper local slopes while preserving traversable routes;
- cliff/ridge silhouettes only where generator validates them.

Primary props:

| Prop family | Density | Notes |
| --- | --- | --- |
| Grass | Medium-High | slope filtered |
| Shrubs | Medium | wind/exposure look |
| Trees | Low-Medium | avoid impossible steep placement |
| Large rocks | Medium | geological clustering |
| Ore outcrops | Low | biome/geology weighted |
| Fallen logs | Low | flatter pockets only |

Gameplay:

- stronger stone/ore opportunity;
- natural viewpoints;
- potential cave entrance/POI candidates;
- more expensive/awkward building unless player levels terrain locally.

## Central Forest

Terrain:

- grass/dirt/leaf-litter blend;
- humid interior pockets;
- rolling terrain rather than flat floor;
- occasional creek/pond interfaces if world profile generates them.

Primary props:

| Prop family | Density | Notes |
| --- | --- | --- |
| Large trees | High | clustered canopy/openings |
| Young/small trees | Medium | secondary layer |
| Bushes | High | local clusters |
| Ferns/ground plants | High visual | batched |
| Mushrooms | Low-Medium | humid/shaded weighting |
| Fallen logs | Medium | orientation/clearance validation |
| Rocks | Medium | partially overgrown variants |
| Grass | Medium | reduced under dense canopy |

Gameplay:

- strongest ordinary wood density;
- more wildlife;
- reduced long sightline;
- forage/resources;
- nocturnal threats can use forest cover.

## Prop placement pipeline

```text
Biome fields
-> prop spawn candidates
-> deterministic blue-noise/Poisson-like distribution or cluster field
-> slope/height/material/water tests
-> structure/POI exclusion
-> local cluster rules
-> stable spawn ID
-> presentation tier
```

Do not instantiate every decorative prop as a persistent Node.

## Prop classes

### Persistent gameplay props

Examples:

- harvestable tree;
- harvestable rock;
- ore/resource node;
- special forage plant;
- interactive POI object.

Own stable state/ID when persistence matters.

### Disposable visual props

Examples:

- tiny grass blades;
- small flowers;
- shell scatter;
- tiny stones/debris.

Regenerate deterministically from biome/seed and render with batching/MultiMesh where possible.

## Grass/foliage suppression

Local suppression masks come from:

- foundation/building footprint;
- roads;
- FarmPlots;
- terrain excavation;
- water coverage;
- protected POI areas.

When suppressor disappears and terrain remains biome-eligible, vegetation can regrow/reappear according to regeneration rules.

## Terrain material blending

Biome transitions and player paths should not render as hard tile seams.

Use material-weight blending, neighbor topology and controlled edge noise while preserving authoritative discrete gameplay material/cell ownership.

## Required tests

- same seed creates same persistent prop spawn IDs;
- decorative prop regeneration does not pollute save size;
- foundation suppresses grass locally rather than regenerating entire biome;
- beach palms do not spawn underwater or on invalid steep slopes;
- central forest leaves usable traversal clearings;
- terrain/biome transition does not create visible square seams;
- future larger islands can add biome definitions without changing world save coordinate format.
