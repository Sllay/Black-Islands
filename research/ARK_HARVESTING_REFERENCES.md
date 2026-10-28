# ARK Harvesting References — Research Notes

Status: research reference, not a Black Island runtime contract.

## Why this exists

Black Island wants one generic harvesting model that can serve trees, rocks, ore nodes and biological corpses while preserving the useful feel of ARK-style tool specialization.

These notes separate observed/documented ARK concepts from Black Island's own design. We copy useful architecture, not undocumented implementation details or quirks.

## High-confidence ARK concepts

Sources consulted include the ARK Official Community Wiki, Epic Developer Community discussions around the ARK DevKit, and community/modder explanations.

### Harvestable health and amount are distinct controls

ARK exposes server settings comparable to:

- `HarvestHealthMultiplier` — how much harvesting health a node has/how many strikes it can withstand;
- `HarvestAmountMultiplier` — amount of material gained from harvesting;
- optional resource-harvest damage clamping behavior.

This supports the idea that destruction rate and yield rate are separate concepts.

### Damage/tool quality influence harvest

The official community wiki documents that harvesting yield is influenced by factors including tool type, tool quality and melee/damage-related stats, with caps/limits based on resource/node state.

Higher-quality tools therefore can gather faster/better without every resource target being identical.

### Tools alter the resource mix

Examples documented by the community wiki:

- hatchets favor Wood from trees and Hide/Stone in relevant targets;
- picks favor Thatch from trees, Raw Meat from corpses and Flint/Metal from rocks;
- specialized tools/creatures can have very different gathering efficiency for particular resources.

### DevKit harvest components are resource/data driven

Community discussion of the ARK DevKit describes `Harvest Resource Entries` and damage-type-specific overrides. An entry can alter resource chance/weight and min/max quantities for particular damage types.

This is an important architectural lesson: the target defines possible resources, while the incoming tool/damage profile modifies what is efficiently extracted.

### Community explanation of damage-proportional yield

A common community/modder explanation is that one harvesting strike effectively considers damage dealt relative to harvest-health/resource budget, so a stronger strike tends to take a larger share of a node's available yield. Community discussions also document over-harvest/clamping edge cases where excessive damage can produce unintuitive results depending on settings.

Black Island should preserve the intuitive part — stronger/better harvesting action gives more per hit — while explicitly clamping remaining harvest health/resource reserves so overkill cannot create resources from nowhere.

## Black Island takeaway

Do not implement harvesting as:

`hit target -> random item amount hard-coded in tree.gd`

Use separate data:

- target harvest health;
- target resource reserves/table;
- tool harvest power;
- tool quality;
- resource-specific affinity/efficiency;
- tool-tier requirements;
- rare-resource costs/weights;
- remaining target health/reserves.

The resulting Black Island design lives in `docs/design/HARVESTING_AND_RESOURCES.md`.

## Useful external references

- ARK Official Community Wiki — Renewable resources / Harvesting Mechanics.
- ARK Official Community Wiki — tools and gathering efficiency pages.
- ARK Official Community Wiki — Server configuration (`HarvestAmountMultiplier`, `HarvestHealthMultiplier`, harvest damage clamp).
- Epic Developer Community — ARK DevKit discussion: damage type / harvest component / harvest resource entries.
- Community/modder discussions on damage versus harvest-health behavior and resource caps.

Exact ARK formulas/implementation are not treated as contractual because portions are community reverse-engineering and behavior varies with game/settings/version.
