# Harvesting & Resources — Design/Technical Spec

Status: accepted architecture direction; numerical balance remains tunable in gameplay.

## Goal

One generic harvesting system serves:

- trees;
- rocks;
- ore veins;
- special plants/resources;
- animal/mob corpses;
- future destructible harvestable world objects.

Do not create separate bespoke harvesting logic for each target class.

The design takes inspiration from useful ARK harvesting concepts: target harvest-health, tool-specific resource affinity, tool quality, damage/yield separation and per-resource tables. Black Island explicitly avoids over-harvest quirks by clamping to authoritative remaining health/resource reserves.

## Core split

A harvest target owns:

```text
HarvestableState
- harvestable_definition_id
- remaining_harvest_health
- resource_reserves
- seed / deterministic roll state
- revision
- destroyed/completed state
```

A tool/action owns:

```text
HarvestToolProfile
- harvest_power
- quality_multiplier
- target_tag_multipliers
- resource_affinity
- minimum/maximum tool tier behavior
- stamina cost
- tool durability cost
- semantic impact action
```

Combat damage and harvest power are separate values. A sword may deal high combat damage without automatically becoming the best mining tool.

## Harvestable definition

Conceptual definition:

```text
HarvestableDefinition
- stable_id
- tags                # TREE, ROCK, ORE, CORPSE, etc.
- base_harvest_health
- resource_entries[]
- destruction_behavior
- regeneration/respawn profile
- hit feedback profile
- required tool rules optional
```

Each resource entry can contain:

```text
HarvestResourceEntry
- item_id
- reserve_min
- reserve_max
- base_weight
- unit_cost
- minimum_tool_tier optional
- rare flag
- final-hit rules optional
```

At spawn/generation, the target creates deterministic reserves from its definition/seed.

Example tree reserve:

```text
Wood       80..120
Fiber/etc. 25..45
Rare Sap    0..2
```

The exact values are content balance, not engine code.

## Per-hit algorithm

### 1. Resolve harvesting power

Conceptually:

```text
requested_harvest_damage =
    tool.harvest_power
  * tool_quality_power_multiplier
  * actor_harvest_modifier
  * target_tag_multiplier
```

### 2. Clamp damage to remaining harvest health

```text
actual_harvest_damage = min(requested_harvest_damage, remaining_harvest_health)
```

This prevents overkill from generating material beyond what was actually left in the target.

Then:

```text
remaining_harvest_health -= actual_harvest_damage
```

### 3. Convert removed health into extraction budget

```text
health_fraction = actual_harvest_damage / base_harvest_health
```

A base extraction budget derives from that fraction and the target's resource density/reserves.

Tool quality/efficiency can increase how much of the available reserve is successfully extracted before the target is exhausted:

```text
extraction_efficiency =
    tool.base_yield_efficiency
  * tool_quality_yield_multiplier
```

This keeps the desired feel:

- stronger/better tool -> more material per hit;
- specialized tool -> better mix/efficiency;
- target still has finite authoritative reserves;
- no free material from huge overkill damage.

### 4. Apply per-resource affinities

For every candidate resource:

```text
selection_weight =
    target.base_weight
  * tool.resource_affinity[item/tag]
```

Affinity changes what the hit favors.

Examples:

- axe on tree: Wood affinity high;
- alternate cutting/mining tool: secondary tree material affinity higher;
- knife on corpse: Heavy/Light Hide affinity high;
- sword/axe on corpse: Meat affinity higher, Hide lower;
- pickaxe on ore: ore/metal affinity high;
- wrong tool: low efficiency or zero for restricted resources.

The allocator spends extraction budget against resource `unit_cost` and never consumes more than `resource_reserves[item]`.

Use deterministic/stochastic rounding rather than always flooring fractional yield so many small hits do not systematically lose resources.

## Tool quality

Quality should not simply multiply combat damage and therefore accidentally dominate every gathering target.

Recommended separation:

```text
quality -> modest harvest-power increase
quality -> extraction-efficiency increase
quality -> durability improvement where appropriate
```

This allows a higher-quality tool to produce more useful material from the same target without requiring absurd damage numbers.

## Resource affinity examples

Initial qualitative direction:

| Target | Tool | Primary result | Secondary result |
| --- | --- | --- | --- |
| Tree | Axe | Wood high | secondary plant/fiber low |
| Rock | Pickaxe | ore/flint/stone profile | depends on node |
| Ore Vein | Pickaxe | target ore high | stone byproduct |
| Corpse | Knife | Hide high | Meat low |
| Corpse | Axe/Sword | Meat high | Hide low |
| Corpse | Wrong tool | poor extraction | possible waste |

Exact numbers live in data definitions and can vary by species/resource node.

## Corpse integration

Living HP and corpse harvest health are separate.

On death:

```text
LivingEntity
  -> CorpseState
       -> CorpseHarvestableState
```

Corpse harvest health may derive from species/body-size/max-health profile, but it is not simply the remaining combat HP (which is normally <= 0).

The corpse still retains the existing two-channel model:

1. delicate/interact loot;
2. destructive harvest reserve.

See `MOBS_CORPSES_AND_LOOT.md`.

## Leather classes

Initial resource direction:

- `Light Hide` — small animals;
- `Heavy Hide` — larger animals.

Do not represent `Light Hide = 0.1 Heavy Hide` with floating item stack quantities.

Use integer recipe equivalence instead.

Example:

```text
Recipe needs 10 Hide Units
Heavy Hide provides 1 Hide Unit each
Light Hide provides 0.5 Hide Unit each
```

For integer-safe implementation, store conversion in the smallest whole subunit:

```text
1 Heavy Hide = 2 hide_points
1 Light Hide = 1 hide_point
recipe requiring 10 Heavy-equivalent Hide = 20 hide_points
```

Therefore 20 Light Hide or 10 Heavy Hide satisfy the same requirement without fractional inventory items.

## Common biological resources

Initial direction:

- generic Meat for terrestrial animals unless a species specifically requires unique meat;
- Fish Meat for fish;
- Light Hide / Heavy Hide;
- Feathers for chicken/bird-like creatures;
- Milk/other delicate resources where appropriate;
- Bones from skeletons;
- Rotten Flesh or equivalent from zombies.

Resource specificity should be added only when it creates gameplay value, not because every species needs a unique meat icon.

## Node regeneration

Surface resource targets can use biome-driven respawn/regrowth rules.

Important separation:

```text
persistent player terrain edits != resource-node respawn
```

A destroyed procedural tree/rock can later respawn if:

- spawn point/biome remains eligible;
- no player structure suppresses it;
- terrain/material still supports it;
- respawn/regrowth deadline passes.

Anchored cave floors use explicit persistent resource rules. Unanchored cave runs naturally receive fresh resource layouts on reroll.

## Harvest transactions

A confirmed strike is authoritative before item insertion:

```text
hit confirmed
-> lock/update HarvestableState revision
-> calculate/remove reserves
-> create yielded stack payload
-> InventoryTransactionCoordinator insert
-> if insertion fails, WorldDropBag
```

Never calculate yield from UI state.

A target cannot be harvested twice from the same health/reserve revision by overlapping hit callbacks.

## Hit feedback

Each successful harvest strike may emit:

- semantic impact VFX;
- material-specific particles;
- audio;
- small hitstop/tool recoil when appropriate;
- floating yield feedback only if UX later justifies it;
- resource target damage state.

Presentation does not own the yield calculation.

## Required tests

- overkill strike cannot extract more than remaining health/reserves;
- axe and knife produce different corpse ratios;
- high-quality tool improves extraction without creating unlimited reserve;
- wrong tool can damage target yet yield poorly;
- two same-frame harvest callbacks cannot consume the same reserve twice;
- corpse delicate inventory and destructive harvest remain independent;
- Light/Heavy Hide recipes use integer conversion with no float-stack drift;
- generated node respawn respects structure/foliage suppression;
- save/load preserves partially harvested persistent targets exactly once.
