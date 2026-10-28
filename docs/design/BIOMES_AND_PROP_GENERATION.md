# Biomes & Prop Generation — Design/Technical Spec

Status: Accepted Chapter 1 direction with extensible data model.

## Goals

World generation must create a dense, authored-feeling island and cave floors while remaining deterministic, streamable and mobile-safe.

Props are biome-driven; they are not scattered by one global random function.

## Biome definition

Use data-driven `BiomeDefinition` resources/data.

Conceptual fields:

```text
id
surface_material_set
height_range
slope_range
moisture_range
coast_distance_range
noise/mask modifiers
prop_spawn_profiles
grass_profile
water_profile
lighting_profile
audio_profile
mob_spawn_profile
resource_spawn_profile
transition_compatibility
rarity/priority
```

Biome assignment is produced from world-generation fields and validated spatial rules, not chosen independently per voxel.

## Surface biome layout — Chapter 1

### Tropical coast / beach

A beach/tropical ring surrounds the island shoreline.

Characteristics:

- sand-dominant shoreline;
- smooth transition toward inland dirt/grass;
- coconut/palm-style trees and coastal vegetation;
- lower dense-forest probability near immediate shore;
- beach debris/rocks/shell-like decorative props where appropriate;
- ocean and river-mouth interaction.

### Plains / tropical interior transition

Between the beach and central forest, the island contains open playable space.

Direction:

- visually open enough for traversal/building/village expansion;
- mixture of grass, bushes, isolated trees and resource props;
- roughly half the broad interior should feel relatively level/buildable and half may contain gentle elevation/hill structures, subject to generation validation;
- "flat" means smooth low-relief terrain, not a mathematically flat plane.

### Central forest

Higher tree/underbrush density toward the interior/appropriate moisture zones.

Characteristics:

- clustered tree generation rather than uniform noise;
- clearings and traversable corridors;
- larger resource density;
- forest floor variation;
- controlled visibility so mobile camera/gameplay remains readable.

### Hills / elevation fields

Elevation is a macro terrain feature crossing compatible surface biomes rather than necessarily a separate hard biome.

Use broad ridges/mounds and erosion-like shaping instead of high-frequency noise bumps.

## Biome transitions

Avoid hard square biome lines.

Use continuous biome weights/masks over a transition band. Terrain material blending and prop density both read the weights.

A transition may gradually change:

- grass color/material;
- tree species mix;
- prop density;
- ambient VFX;
- music/ambience;
- resource spawn weights.

Gameplay identity remains deterministic even when visuals are blended.

## Prop generation pipeline

For every streamed WorldChunk/region:

`biome masks -> candidate strata -> deterministic point generation -> rule filtering -> cluster shaping -> stable spawn IDs -> presentation/persistence classification`

### Candidate distribution

Use techniques such as:

- Poisson-disk/blue-noise for minimum-distance objects;
- clustered noise for forests/bush groups;
- spline/shore-biased distribution for coastal props;
- weighted rare-point sampling for special resources;
- authored POI exclusion/attraction masks.

Do not use independent `randf()` per frame/load.

## Stable spawn IDs

Persistent/generated props derive a stable ID from data such as:

`world_seed + biome_generation_version + chunk_coord + spawn_layer + candidate_index`

This permits save deltas such as "tree #A was chopped" without storing every untouched tree.

## Prop classes

### Disposable presentation

Examples:

- grass blades;
- tiny flowers;
- small pebbles;
- noninteractive ground clutter.

These use batched instancing and are regenerated from seed + suppression state. No individual save entry.

### Harvestable persistent props

Examples:

- trees;
- large rocks;
- resource nodes;
- special plants.

These have stable spawn IDs and save mutation state only when changed/harvested.

### Unique/POI props

Ruins, shrines, cave entrances and story objects are generated through POI systems with stronger spacing/validation rules.

## Prop suppression

A local `WorldSuppressionMap`/equivalent prevents generated props appearing through:

- structures;
- paths;
- FarmPlots;
- cleared village zones;
- water;
- protected POIs;
- edited terrain incompatible with original spawn rule.

When suppression changes, regenerate/reconcile only the affected prop patches.

## Tree/resource regrowth

Regrowth policy belongs to each spawn profile.

Possible states:

`AVAILABLE -> HARVESTED -> COOLDOWN -> ELIGIBLE -> AVAILABLE`

The original stable spawn location may regrow, or the biome may later redistribute eligible spawn budget, depending on resource definition.

Chapter 1 should prefer deterministic stable regrowth for major props to simplify saves.

## Surface density target

The visual goal is intentionally "filled" and lively, closer to the readable density of Cult of the Lamb than an empty procedural sandbox.

Density must come primarily from cheap instanced layers, not thousands of full Node3D scenes.

Near-camera density can be high while distant rings aggressively reduce:

- tiny grass;
- flowers;
- clutter;
- shadow-casting props;
- animation/update frequency.

## Cave biome architecture

Cave floors use the same biome/prop definition framework but different generation rules and lighting.

### Standard Cave

Default underground biome.

- mostly dark environment;
- sparse weak luminous crystals/mushrooms/points of light;
- mixed passive/neutral/aggressive population according to floor difficulty;
- normal ore/resource progression;
- readable navigation without making the cave bright.

### Darkness

High-threat special biome.

- effectively no natural ambient/emissive guidance light;
- player is expected to bring/create illumination such as torches;
- aggressive population dominates/approaches 100% of encounter budget;
- stronger enemy/resource risk-reward profile;
- darkness itself is gameplay pressure, not only color grading.

### Enchanted Forest / Luminous Forest

Bioluminescent underground forest floor/region.

- luminous trees;
- glowing crystals;
- glowing mushrooms/moss;
- bright fantasy palette despite underground location;
- more neutral/passive ecology than Darkness;
- dangerous/strong creatures may still occur;
- prop density can be lush but must respect navigation corridors.

### Future special themes

Gothic/skull/ruin-heavy and other unusual cave themes remain extensible content, not a Chapter 1 architecture requirement.

## Cave floor biome choice

Each generated floor receives a floor profile first, then biome generation.

A floor may be:

- mostly one major biome;
- mixed standard + special subregions;
- a rare full special-biome floor.

Difficulty/floor depth modifies spawn/resource tables without hard-coding visuals into depth numbers.

## Mobs and biome integration

Biome emits spawn tags/weights, while mob definitions decide whether they are valid.

Surface baseline:

- passive and neutral fauna dominate daytime;
- some aggressive creatures appear or activate at night;
- some neutral creatures may become aggressive under time/territory/pack conditions.

Caves use biome-specific ratios.

## Streaming

Each WorldChunk owns deterministic prop candidate data but presentation is streamed by distance.

Recommended tiers:

- near: interactive prop nodes + dense MultiMesh foliage;
- mid: simplified/instanced major props, reduced grass;
- far: major silhouette props only or baked/impostor representation;
- unloaded: data/state only.

Do not instantiate interactive tree/rock scenes for far chunks.

## Mipmap/foliage rendering rules

For cutout foliage:

- mipmaps enabled;
- prefer alpha-scissor/alpha-test over full alpha blending where art allows;
- preserve alpha-test coverage in imported mipmaps;
- use alpha-to-coverage only where MSAA/profile permits;
- avoid many overlapping full-transparent quads;
- use nearest-mipmap or carefully selected filtering for the pixel/cartoon hybrid instead of disabling mipmaps;
- distance fade should prefer dither/object fade rather than expensive alpha blending when practical.

These rules specifically target distant foliage shimmer/disappearing-alpha artifacts.

## Shadows and lighting

Mobile default:

- only major nearby props cast dynamic shadows;
- small grass/flowers do not cast full realtime shadows;
- use ambient/contact/baked-looking shading cues in materials;
- distance-based shadow disable/LOD;
- cave emissive props use cheap emissive presentation and limited real lights.

A glowing mushroom does not require its own OmniLight3D.

## Required generation tests

- same seed/profile produces same stable prop IDs;
- suppression prevents grass/trees under foundations/paths/FarmPlots;
- removing suppression permits configured regrowth;
- biome transitions do not produce obvious straight lines;
- prop generator leaves valid movement/build corridors;
- chunk unload/reload does not duplicate harvested persistent props;
- cave biome floor regeneration remains deterministic for a given run seed;
- mobile stress test maintains prop draw/update budgets.
