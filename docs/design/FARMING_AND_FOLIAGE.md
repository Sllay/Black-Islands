# Farming & Foliage — Design/Technical Spec

Status: Accepted direction; balance constants can be tuned.

## Core split

Black Island separates three concepts:

1. **terrain material** — grass, dirt, sand, rock, path, etc.;
2. **foliage presentation** — grass blades, flowers, bushes and decorative vegetation generated from biome rules;
3. **FarmPlot state** — persistent gameplay object anchored to the world/build grid.

Do not store full crop/fertilizer/growth state inside generic terrain voxels.

## Hoe behavior

The hoe is a semantic terrain/farming tool.

### On grass/tillable ground

A valid hoe action:

1. targets one 1 m farming/build cell;
2. verifies the underlying terrain surface is tillable and sufficiently supported/flat;
3. suppresses/cuts local grass/foliage;
4. paints/removes the visible grass surface toward dirt where needed;
5. creates a `FarmPlotState` anchored to that cell/surface.

The terrain is not physically dug away. This action is fast and does not use the destructive terrain-mining duration.

### On invalid material

Stone, deep water, protected structure footprint or unsupported air cannot create a FarmPlot unless a future rule explicitly allows it.

## Shovel/path behavior

Road/path creation remains terrain material painting, not a FarmPlot.

Example:

`GRASS/DIRT -> PATH_DIRT`

Path painting suppresses local grass/foliage and uses smooth material blending with neighboring terrain.

## FarmPlot data

Conceptual authoritative state:

```text
FarmPlotState
- plot_id
- anchor_cell
- surface_reference / world position
- state
- seed_id optional
- planted_at_game_time
- growth_progress
- growth_stage
- moisture_state
- moisture_until
- dry_since optional
- decay_elapsed_active_time
- fertilizer_id optional
- fertilizer_multiplier
- harvest_ready
- visual_variant_seed
- revision
```

The plant visual is presentation derived from `FarmPlotState`; it is not the authoritative crop object.

## Plot states

Suggested semantic states:

```text
TILLED_DRY
TILLED_WET
SEEDED_DRY
SEEDED_WET
GROWING
HARVEST_READY
DECAYING
```

Implementation may combine flags instead of a single enum, but invalid combinations must be prevented centrally.

## Moisture

Normal watering keeps the plot meaningfully watered for approximately one full in-game day.

Strong rain may extend moisture protection to roughly three in-game days.

Exact weather intensity thresholds are data-driven.

Watering:

- resets/extends moisture expiry;
- pauses/resets dry-decay countdown where applicable;
- triggers wet visual state;
- can use water taken from valid river/lake/ocean/fresh-water sources according to item rules.

## Growth

Crop growth is day-oriented but visually continuous.

Each crop definition stores a required growth duration in game-time/days. The logical crop may need N days, while the plant visual interpolates/progresses gradually during those days instead of popping instantly at sleep transition.

Growth can require the plot to be watered according to crop rules.

`CropDefinition` should include at least:

- stable seed/crop ID;
- total growth time;
- visual stages;
- harvest outputs;
- minimum valid terrain/biome conditions;
- water requirements;
- fertilizer response;
- regrow-after-harvest behavior if any;
- season/weather rules if later enabled.

## Fertilizer

Fertilizer belongs to `FarmPlotState`, not the terrain voxel.

Initial multiplier design supports tiers around:

`1x / 2x / 3x / 4x`

Actual progression/balance values remain content data.

Fertilizer may modify effective growth rate, yield or future properties, but Chapter 1 should keep the rule set small.

## Plot decay

### Empty dry plot

A tilled plot with no seed and no moisture decays after approximately 30 minutes of active real gameplay time.

When decay completes:

- `FarmPlotState` is removed;
- no "tilled dirt item" is dropped;
- underlying terrain remains valid dirt/ground;
- grass regrowth becomes eligible according to foliage rules.

### Seeded but abandoned dry plot

A seeded plot that remains unwatered may also enter a long dry-decay timer around 30 active gameplay minutes.

If that plot is destroyed/decays under the configured rule:

- the seed may be returned as a world drop according to crop definition;
- the FarmPlot is removed;
- terrain stays physically intact unless another action changed it.

Watering resets/pauses this decay.

Timers must use a well-defined gameplay clock so pause menus/loading do not accidentally consume them.

## Underlying terrain destruction

Each FarmPlot validates its support surface after terrain edits.

If the terrain underneath is removed enough that the plot no longer has a valid supporting/tillable surface:

`terrain edit -> FarmPlot invalidated -> crop/seed recovery rule -> plot removed`

A planted plot can drop its seed according to definition. The plot itself never drops as an item.

## Grass and foliage suppression

Grass/foliage cannot clip through structures or cultivated/path ground.

Local suppression reasons include:

- foundation footprint;
- path/road;
- FarmPlot;
- destructive terrain edit;
- water coverage;
- prop/building exclusion volume.

Suppression is stored as local world state/masks, not by permanently deleting the procedural biome rule.

## Grass regrowth

When a suppression reason disappears and terrain becomes eligible again, vegetation can return.

Examples:

- demolish foundation -> underlying eligible terrain may regrow grass;
- FarmPlot decays -> dirt becomes eligible;
- path removed/repainted to natural ground -> eligibility returns.

Initial natural dirt-to-grass return target: randomized approximately 3-6 in-game days when:

- biome supports grass;
- cell is not occupied/suppressed;
- material and moisture rules permit;
- no FarmPlot/path/structure blocks it.

Regrowth should be deterministic from cell/spawn seed plus eligible time, not a frame-by-frame random chance.

## Biome-generated grass

Dense decorative grass should use deterministic instancing rather than one node per blade.

Recommended representation:

- deterministic spawn field per biome/chunk;
- MultiMesh/VoxelInstancer-style batched rendering;
- suppression mask queried during generation/refresh;
- local patch refresh after edits instead of rebuilding the whole chunk.

Each persistent harvestable prop may have a stable spawn ID, while disposable grass blades do not need individual save records.

## Foundation interaction

Placing a foundation:

1. placement validates terrain/build support;
2. on successful transaction, structure occupancy commits;
3. foliage suppression mask is updated under/around the footprint;
4. visible grass disappears using local refresh/fade;
5. if the foundation is later destroyed/demolished, suppression is released;
6. natural regrowth timer starts if the underlying terrain remains eligible.

## Rain

Weather sends area-level events rather than touching every plot every frame.

A rain event can batch-query FarmPlots within affected active regions and extend moisture state.

Heavy rain may grant a larger moisture duration than manual watering.

## Performance rules

- no Process callback per FarmPlot;
- FarmPlots are updated by batched scheduler/time events;
- no Node per grass blade;
- no global foliage rescan after one foundation/hoe action;
- farm visuals may pool/reuse stage meshes/sprites;
- unloaded plots advance through authoritative game time on reload instead of simulating every missing frame.
