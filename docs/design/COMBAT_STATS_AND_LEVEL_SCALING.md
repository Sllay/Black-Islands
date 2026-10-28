# Combat Stats & Level Scaling — Design/Technical Spec

Status: accepted baseline formulas; balance values remain tunable.

## Baseline health anchors

Initial design anchors:

- Player baseline Max HP: `100`.
- Ordinary level-1 mob baseline: approximately `100` where its species definition does not override it.
- Boss baseline: commonly around `500`, with individual bosses free to be substantially higher/lower.

Species/weapon/content definitions remain authoritative. These are not hard global caps.

## Level scaling

Mob level modifies baseline stats through curves rather than hard-coded special cases.

Conceptual:

```text
final_max_hp = base_max_hp * hp_level_curve(level)
final_damage = base_damage * damage_level_curve(level)
final_defense = base_defense + defense_level_curve(level)
```

A useful first test curve for ordinary enemies can target roughly:

```text
Level 1 mob: 100 HP
Level 5 mob: ~125 HP
```

For a simple early prototype this corresponds to about `+6.25% of base HP per level after level 1` over that range. The final curve should become a data resource so high-level scaling can flatten/steepen without code changes.

Do not use the same curve blindly for bosses, passive animals and every enemy family.

## Defense rating

The design discussion included two incompatible numeric examples:

- 100 Defense should produce about 50% damage reduction;
- another example implied 50 Defense could also produce 50% damage reduction.

One formula cannot satisfy both simultaneously. For a stable RPG stat with diminishing returns, Black Island uses the first anchor as the baseline technical direction:

```text
damage_reduction = defense / (defense + 100)
damage_taken = raw_damage * (1 - damage_reduction)
```

Equivalent form:

```text
damage_taken = raw_damage * 100 / (100 + defense)
```

Examples:

| Defense | Reduction | 100 raw damage becomes |
| ---: | ---: | ---: |
| 0 | 0% | 100 |
| 25 | 20% | 80 |
| 50 | 33.3% | 66.7 |
| 100 | 50% | 50 |
| 200 | 66.7% | 33.3 |
| 300 | 75% | 25 |

Benefits:

- integer Defense can grow indefinitely without reaching 100% immunity;
- every additional point still helps but has diminishing returns;
- player and mobs can share one rule;
- UI can show integer Defense while combat internally computes a float multiplier.

If future playtests strongly require `50 Defense = 50% reduction`, that is a deliberate balance-rule change and should replace this formula explicitly rather than layering exceptions.

## Damage pipeline

Conceptual order:

```text
Attack base damage
-> attack/weapon/skill modifiers
-> attacker stat modifiers
-> elemental/reaction modifiers
-> target vulnerability/resistance tags
-> Defense mitigation
-> guard/block/parry rules where applicable
-> final HP damage
```

Exact ordering for elemental resistance vs Defense should remain deterministic and tested; do not let individual attacks reimplement it.

## Guard is not Defense

Guard/block modifies an incoming attack through combat state before/around the ordinary damage pipeline. It is not simply a temporary +Defense value.

This allows:

- frontal-only blocking;
- guard break;
- weapon-specific block percentage;
- perfect parry with zero damage;
- rear attacks bypassing guard.

After the block result, any remaining damage can still pass through normal Defense mitigation.

## Bosses

Bosses use their own stat profiles/curves.

A boss with 500 Max HP is an initial content anchor, not a rule that every boss must use 500.

Boss difficulty can come from:

- HP;
- Defense;
- attack patterns;
- stagger resistance;
- mobility;
- phase changes;
- adds/environment mechanics;
- elemental interactions.

Avoid solving every boss simply by multiplying HP.

## Required tests

- 100 Defense halves ordinary incoming damage under baseline formula;
- Defense never produces >=100% reduction by stat stacking alone;
- level curve produces configured Level 1/5 health targets;
- player and mob Defense use the same central damage resolver;
- parry zero-damage behavior cannot be undone by later Defense calculations;
- save/load preserves level/stats without recomputing from a changed transient Node.
