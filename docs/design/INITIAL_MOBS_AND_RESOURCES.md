# Initial Mobs & Resource Content — Design Spec

Status: initial Chapter 1 content baseline; stats/spawn rates require playtesting.

## Surface passive fauna

### Cow

Disposition: Passive / defensive only if future variant requires it.

Resources:

- Delicate interact loot: Milk.
- Harvest with Knife: Heavy Hide high, Meat low-medium.
- Harvest with Axe/Sword: Meat high, Heavy Hide low.

### Pig

Disposition: Passive or defensive-on-hit depending on final AI profile.

Resources:

- Meat.
- Heavy Hide.

No mandatory delicate-loot channel for baseline.

### Chicken

Disposition: Passive / flee.

Resources:

- Delicate interact loot: Feathers.
- Destructive harvest: Meat.

If the corpse is fully harvested before delicate Feathers are collected, the configured simple-fauna rule may discard those Feathers.

### Rabbit

Disposition: Passive / flee.

Resources:

- Meat.
- Light Hide.

## Fish

Fish-school visuals can include several tropical-looking species/variants while sharing one common gameplay drop (`Fish Meat`) unless a future recipe needs species-specific fish.

Good visual families include:

- Angelfish;
- Butterflyfish;
- Parrotfish;
- Blue Tang / surgeonfish-like;
- Clownfish-like reef fish.

These names can be localization/display variants without requiring five distinct meat items.

School movement uses the Boids architecture in `WORLD_ECOLOGY_AND_OFFSCREEN_SIMULATION.md`.

## Ambient birds

Bird flocks are initially decorative ecology rather than fully physical mobs.

They use cheap Boids/MultiMesh-style presentation and do not need save persistence or loot unless a later species is promoted into gameplay fauna.

## Skeleton

Surface role:

- primarily/night active;
- dormant/sleeping body state during day;
- spirit/ghost theme explains nighttime activation;
- persistent/logical entity can remain in regional simulation without full AI scene while distant.

Baseline resource:

- Bones.

Spawn population must use regional/global caps rather than accumulate forever.

## Zombie

Surface role:

- migratory aggressive mob;
- originates from cave/world threat sources;
- moves toward high population concentration/village heat;
- prefers/activates strongly at night;
- suffers sunlight/day damage and seeks dark/sheltered regions as dawn approaches;
- participates in raids.

Baseline resource/reward possibilities:

- Rotten Flesh;
- XP;
- chance of equipment/tool/weapon/armor/accessory loot depending on zombie definition/level;
- persistent death bag rules for valuable enemy inventory where configured.

Offscreen migration uses region-level simulation rather than full CharacterBody3D movement.

## Intro raid

The new-game opening starts during an existing zombie assault on the ruined village.

This is narrative/tutorial combat rather than proof that the world had no previous attacks.

Later first systemic raid can begin around a small 5–10-zombie encounter as an initial tuning point, then scale with progression.

## Disposition composition

Initial world ecology uses:

- Passive: Cow, Pig, Chicken, Rabbit, many fish.
- Neutral/conditional: future territorial wildlife and selected cave creatures.
- Aggressive: Skeleton, Zombie and biome-specific hostiles.

Definitions can add conditions such as:

- night-only aggression;
- pack threshold;
- territory;
- retaliate when hit;
- flee when alone.

## Mob levels

All combat mobs can have level-driven stat curves.

Level is stored in entity state and influences HP/damage/Defense using `COMBAT_STATS_AND_LEVEL_SCALING.md` plus species-specific curves.

Do not generate higher level by simply multiplying all stats by one global number.

## Loot ownership

All inventory/delicate loot and harvested-resource creation flows through authoritative corpse/harvest/inventory transactions.

No enemy script directly calls `player_inventory.add_item()` from a death callback.

## Required tests

- Chicken corpse can expose Feathers separately from Meat harvesting;
- Knife vs Axe produces intended Cow resource ratio;
- Rabbit uses Light Hide, Cow/Pig use Heavy Hide;
- fish visual species can share Fish Meat definition;
- skeleton does not duplicate when switching day/night states;
- zombie migration record survives unload/reload;
- zombie valuable inventory converts once into persistent death bag if policy triggers;
- spawn caps prevent long sessions accumulating unlimited skeletons.
