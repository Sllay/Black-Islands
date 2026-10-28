# Structure Tiers & Large Builds — Design/Technical Spec

Status: initial Chapter 1 balance baseline; values are tunable after gameplay tests.

## Structural material progression

Initial progression:

1. Thatch
2. Wood
3. Stone
4. Darkstone
5. Scrap
6. Iron

`Darkstone` is a darker underground/cave stone tier between ordinary Stone and metal construction.

`Scrap` represents rough reclaimed/impure/rusted metal construction.

`Iron` is the strongest baseline conventional structure material in this progression.

## Important invariant

Material tier does **not** increase structural support reach.

Thatch, Wood, Stone, Darkstone, Scrap and Iron obey the same support-provenance/span rules from `BUILDING_AND_STRUCTURAL_SUPPORT.md`.

Tier differences are primarily:

- HP/durability;
- damage/resistance profile;
- crafting cost/unlock;
- repair cost;
- visuals/audio;
- future raid/PvP interaction rules.

## Base HP table

The user locked Thatch around 5,000 HP. The following is the first balance curve built from that anchor:

| Material | Base structure HP | Relative |
| --- | ---: | ---: |
| Thatch | 5,000 | 1.00x |
| Wood | 8,000 | 1.60x |
| Stone | 12,000 | 2.40x |
| Darkstone | 16,000 | 3.20x |
| Scrap | 22,000 | 4.40x |
| Iron | 30,000 | 6.00x |

These numbers intentionally avoid a gigantic exponential jump that would make old weapons instantly irrelevant. Actual raid/combat damage profiles can still make higher tiers feel dramatically tougher.

## Piece HP multiplier

Rather than maintain six hand-authored HP numbers for every piece, derive ordinary modular-piece HP from:

```text
piece_max_hp = material_base_hp * piece_hp_multiplier
```

Initial candidate multipliers:

| Piece | Multiplier |
| --- | ---: |
| Foundation | 1.00 |
| Ceiling/platform/flat roof | 0.85 |
| Wall/window wall/doorframe | 0.75 |
| Pillar/post | 0.65 |
| Door | 0.55 |
| Fence/railing | 0.40 |

Special/large structures may override this completely.

Example Wood values from the starting table:

```text
Foundation: 8,000 HP
Wall:       6,000 HP
Ceiling:    6,800 HP
Pillar:     5,200 HP
Door:       4,400 HP
```

Round final values according to UI/balance conventions.

## Damage profiles

Structure material can modify which damage categories are effective without changing support reach.

Possible categories:

- physical light;
- physical heavy;
- siege/explosive;
- elemental/fire;
- lightning/environment;
- future PvP-specific damage tags.

Exact resistances remain balance content.

## Lightning

Current weather rule:

- lightning can damage structure pieces in its impact/AOE;
- strongest affected structure damage is approximately 10% of that piece's Max HP before falloff/resistance tuning;
- Chapter 1 lightning does not automatically ignite structures.

This scales naturally from Thatch through Iron without one bespoke lightning table per material.

## Small modular pieces

Ordinary survival-building pieces place immediately after:

`inventory transaction -> snap/occupancy/support validation -> item consumption -> structure creation`

Examples:

- foundation;
- wall;
- ceiling;
- pillar;
- door/window variants;
- small ramps/stairs where applicable.

## Large/civic structures

Large village structures should not instantly materialize when placed.

Examples may include:

- large settlement walls/gates;
- civic buildings;
- major workshops;
- large defensive structures;
- future tribe-scale infrastructure.

Placement creates a `ConstructionSiteState`/blueprint ghost.

## ConstructionSiteState

Conceptual state:

```text
ConstructionSiteState
- structure_definition_id
- owner_scope
- transform/build footprint
- resources_paid
- total_work_units
- completed_work_units
- assigned_workers
- state/revision
```

### Resource payment

Baseline direction from design:

- required resources are consumed transactionally when the construction site is successfully committed/placed;
- the site then represents already-paid material waiting for labor;
- interruption/destruction/refund policy is data-driven and must never duplicate the paid resources.

### Work progression

The site completes by accumulating `work_units`.

Sources of work:

- player interaction/construction action;
- Builder NPCs;
- other eligible NPC job helpers;
- future tribe players.

More workers increase construction speed.

Do not run one dedicated timer node per construction worker/site. Use world/simulation scheduling and aggregate work rates.

## Worker scaling

Initial architecture allows:

```text
site_work_rate = player_work + sum(valid_worker_rates)
```

Content can add diminishing returns/caps later if large NPC crowds trivialize construction.

NPC skill/Builder profession may modify `worker_rate`, not the structure's resource cost after placement unless an explicit perk says so.

## Completion transaction

On reaching total work:

1. revalidate site footprint/ownership;
2. atomically transition `CONSTRUCTION_SITE -> COMPLETED_STRUCTURE`;
3. register BuildGrid occupancy/support graph;
4. remove blueprint presentation;
5. instantiate/stream completed presentation;
6. persist completed structure state.

Never create both blueprint and completed structure as authoritative owners simultaneously.

## Required tests

- material tier changes HP but not structural support span;
- one piece's Max HP derives deterministically from material + multiplier;
- lightning percentage damage scales against piece Max HP;
- large-site resource payment happens exactly once;
- player and NPC work contribute to one authoritative progress value;
- save/load cannot duplicate paid resources or completed structure;
- two workers finishing the same site in one frame cannot create two structures;
- destroyed/cancelled construction site follows one explicit refund policy.
