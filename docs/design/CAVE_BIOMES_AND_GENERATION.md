# Cave Biomes & Generation — Design/Technical Spec

Status: accepted Chapter 1 direction; generator parameters require implementation tuning.

## Surface vs cave generation lifecycle

### Surface island

The surface map is generated once when the save/world is created.

After initial generation, the save uses:

```text
world seed + accepted generation profile + persistent terrain/object deltas
```

The surface must **not** reroll every time the player loads the save.

### Cave floors

Unanchored cave floors belong to a `CaveRun` and are intentionally procedural/ephemeral between runs.

See `CAVES_AND_ANCHOR_PROGRESSION.md`.

## Initial cave preload

During new-save world generation, Black Island may also generate/cache the first cave floor's entry/spawn envelope (or enough deterministic floor data to reveal it immediately) so the player's first cave entry is fast.

When the player enters Floor 1:

```text
activate Floor 1
-> begin generating/prefetching Floor 2 spawn envelope in background
```

When approaching a descent point, prioritize the next destination sectors further.

Never block initial save creation on generating every future cave floor.

## Biome selection is procedural

Floor index does not permanently map to one biome.

Example:

```text
Run A Floor 1 -> Luminous Forest
Run B Floor 1 -> Standard Cave
Run C Floor 1 -> Darkness
```

unless a progression/event rule explicitly constrains the choice.

Anchoring a floor also anchors the selected floor profile/seed, so an anchored Luminous Forest floor remains that floor rather than rerolling later.

## Chapter 1 cave biome families

### Standard Cave

Mixed underground ecology.

Visual/content language:

- normal rock/ore geology;
- sparse crystals;
- weak bioluminescent mushrooms/moss in some pockets;
- low-to-moderate ambient light sources;
- mixed passive, neutral and aggressive mobs;
- ordinary ore/resource baseline.

This is not a brightly lit cave. It simply contains enough scattered natural light cues that the player is not always in total blackness.

### Darkness

High-threat fully dark cave profile.

Direction:

- essentially no natural illumination;
- torches/player light become mechanically important;
- aggressive mob pool dominates;
- stronger encounters/resources can compensate risk;
- atmosphere focuses on silhouette, sound and player-carried light.

Darkness should not fake visibility through an overly bright ambient term.

### Luminous Forest

Final name: **Luminous Forest**.

A striking underground forest biome intended to be one of Black Island's showcase/screenshot locations.

Direction:

- underground forest rather than ordinary stone corridors;
- luminous moss;
- bioluminescent trees/plants;
- luminous mushrooms;
- glowing crystals;
- pools/water where generation allows;
- soft colored indirect-looking presentation achieved cheaply enough for mobile;
- more passive/neutral ecology than Darkness, while still allowing dangerous creatures.

The desired feeling is a hidden living surface-like ecosystem inside a cave, illuminated almost entirely by biological/mineral luminescence.

## Biome field model

Avoid one giant chain of hard-coded random if-statements.

The generator should expose environmental fields and let biome definitions score suitability.

Surface-style fields can include:

- temperature;
- humidity/moisture;
- elevation;
- distance to coast/water;
- slope;
- geology.

Cave fields can include:

- depth;
- temperature;
- humidity;
- geology/material family;
- openness/cavern scale;
- water potential;
- luminescence potential;
- danger/corruption factor;
- progression constraints.

Conceptually:

```text
BiomeScore(profile, environmental_fields, run_seed)
```

Weighted choice plus validation chooses the floor profile.

The exact noise/field implementation can use FastNoiseLite/domain-warp/other procedural tools, but noise is an input field rather than the game design itself.

## Cave topology

Biome selects generation rules rather than only swapping textures.

Examples:

- Standard Cave: mixed chambers/corridors;
- Darkness: tighter/noisier dangerous routes or large pitch-black chambers according to profile;
- Luminous Forest: larger open caverns capable of supporting trees, water and visually readable forest clusters.

## Prop/resource generation

After terrain/topology:

```text
floor volume
-> biome fields
-> walkability/open-space validation
-> ore/resource placement
-> vegetation/prop clusters
-> water candidates
-> mob ecology/spawn regions
-> POIs/descent placement
-> validation
```

Use deterministic IDs/seeds so the same active CaveRun floor can unload/reload consistently.

## Totem of Anchoring

Player-facing baseline name: **Totem of Anchoring**.

Lore function:

Cave floors are unstable/shifting between expeditions. An Anchoring Totem 'roots' a generated floor in place.

The consecutive rule has an in-world explanation: anchors form a chain. A deeper anchor depends on the preceding anchored descent chain, so the player cannot stabilize Floor 10 without having anchored progression through preceding required floors.

Technical behavior remains defined in `CAVES_AND_ANCHOR_PROGRESSION.md`.

## Required tests

- surface island loads from saved generation state and never rerolls on ordinary save load;
- first cave entry can reveal safe Floor 1 envelope without generating all floors;
- Floor 2 prefetch starts while player explores Floor 1;
- unanchored Floor 1 may choose a different biome on a later CaveRun;
- anchored Luminous Forest floor retains its exact profile/seed;
- Darkness does not receive unintended global ambient lighting that removes its gameplay identity;
- Luminous Forest generator reserves enough open volume for forest-scale props rather than spawning trees through ceilings.
