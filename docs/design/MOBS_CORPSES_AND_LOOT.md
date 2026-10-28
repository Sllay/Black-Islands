# Mobs, Corpses & Loot — Design/Technical Spec

Status: Accepted core direction.

## Mob disposition model

Every mob has a base disposition plus conditional behavior rules.

Base families:

- `PASSIVE`
- `NEUTRAL`
- `AGGRESSIVE`

Do not encode this as three completely separate AI implementations. Use a shared perception/utility/behavior framework with data-driven triggers.

## Passive mobs

Passive creatures do not proactively hunt the player.

Possible response modes:

- `FLEE_ON_THREAT` — runs when attacked/threatened;
- `DEFEND_ON_HIT` — ignores player until damaged, then retaliates;
- future herd/parental responses.

Examples may include livestock/wild fauna.

## Neutral mobs

Neutral creatures attack only under contextual triggers.

Possible triggers:

- player enters territory;
- player gets too close;
- player approaches offspring/nest/resource;
- player attacks first;
- time/weather/state condition.

Territorial behavior should provide readable visual/audio feedback before attack where appropriate.

Territory is data/state, not just one invisible Area3D hard-coded into each scene.

## Aggressive mobs

Aggressive mobs use data-driven aggression conditions.

Examples:

- attack on sight;
- aggressive only at night;
- flee/avoid during daytime;
- attack only when pack count >= threshold;
- avoid player when pack count < threshold;
- special biome/floor rules.

`AggressionRuleDefinition`/equivalent can combine conditions rather than requiring custom scripts for every creature.

## Execution architecture

Recommended split:

- perception service produces sensed entities/events;
- local utility/condition layer decides intent;
- LimboAI/HSM/behavior tree executes movement/combat/flee actions;
- mob definition supplies disposition, triggers, pack/territory metadata and action profiles.

## Corpse lifecycle

Most living mobs do not explode into loose item pickups at death.

Death flow:

`alive -> death animation -> CorpseState -> loot/harvest window -> decomposition/despawn -> optional death bag`

Corpse remains an interactable world entity for a configured decomposition duration.

Conceptual `CorpseState`:

```text
source_entity_definition
source_entity_id/run_id
loot_policy
harvest_profile
remaining_delicate_loot
remaining_harvest_yields
decomposition_deadline
harvest_damage/progress
persistent_bag_policy
revision
```

## Two loot channels

### Delicate inventory/interaction loot

Collected by opening/interacting with the corpse rather than striking it.

Examples:

- cow: milk/specific delicate resource where game rules allow;
- chicken: feathers;
- creature-specific organs/items;
- enemy/boss inventory rewards.

### Harvest yields

Collected by striking/processing the corpse using a valid tool.

Yield depends on tool tags/profile.

Example animal processing:

- knife: high leather/hide yield, lower meat;
- axe/sword: higher meat, low hide;
- wrong/weak tool: poor efficiency or unavailable yield.

The exact numbers are data-driven.

## Harvest profiles

`HarvestProfile` describes:

```text
resource pools
valid tool tags
yield multipliers
harvest progress/durability
visual hit response
completion behavior
```

Do not hard-code cow/chicken logic in player tool scripts.

## Simple passive-fauna risk

For some easy passive animals, unclaimed delicate loot is intentionally lost if the player fully harvests/despawns the corpse without collecting it first.

This creates the intended choice/order:

`inspect/collect delicate loot first -> harvest body`

Examples such as milk/feathers can use this nonpersistent policy.

## Persistent death-bag policy

Harder/important entities should not punish the player by permanently deleting valuable inventory because the corpse was accidentally harvested/despawned.

Persistent/death-bag policy applies to categories such as:

- bosses;
- aggressive/important enemies according to definition;
- player death;
- selected NPC deaths or special entities.

If qualifying unclaimed inventory remains when corpse is removed/harvested/decomposes:

`remaining loot -> DeathBagInventory`

The bag is named/labeled after the source entity where appropriate.

## Player death

Player death creates a death bag/container containing inventory according to final death rules.

The same generic container/transaction system is reused; do not create a separate incompatible loot inventory implementation.

## Dynamic item drop bag

Loose world item drops should prefer a generic small bag/package container rather than one physics Node per item stack.

`WorldDropBag` can contain one or many stacks.

Benefits:

- fewer scene nodes/physics objects;
- easy stack merging;
- same inventory transfer UI;
- simple save/cleanup policy;
- consistent representation for crafted overflow and dropped inventory.

Nearby compatible drop bags may merge under strict rules to reduce clutter.

## Corpse vs death bag

Corpse is biological/entity state with harvest logic.

Death bag is an inventory container.

They are not the same object.

A boss corpse can expose harvest interactions while its protected loot later moves into a death bag if unclaimed.

## Decomposition

Definitions specify decomposition duration and behavior.

On expiry:

1. resolve protected/persistent unclaimed loot into bag if policy requires;
2. resolve/discard nonpersistent delicate loot;
3. remove corpse presentation;
4. clean navigation/interaction state.

Do not run one Timer Node per unloaded corpse; use world scheduler/deadlines.

## Biome/time integration

Mob spawn/disposition can react to biome and time.

Surface direction:

- daytime favors passive/neutral ecology;
- nighttime may spawn/activate aggressive creatures;
- selected creatures switch neutral/passive behavior into aggression at night.

Cave direction:

- Standard Cave: mixed ecology;
- Darkness: aggressive encounter pool dominates;
- Enchanted/Luminous Forest: more passive/neutral presence with selected strong threats.

## Pack logic

Pack-aware creatures query a local social/group registry rather than scanning every mob each frame.

Example:

`nearby pack members >= 3 -> aggression enabled`

`nearby pack members < 3 -> avoid/flee/ignore`

Use spatial partition/query caching for mobile performance.

## Territory feedback

Territorial neutral mobs should telegraph boundaries/contextually rather than surprising the player with invisible rules.

Possible feedback:

- posture/animation change;
- warning sound;
- subtle ground/VFX marker when relevant;
- mob faces player/growls;
- temporary HUD/context cue only if needed.

Do not permanently paint large debug circles into normal gameplay.

## Required anti-duplication rules

Loot/corpse/container actions use `InventoryTransactionCoordinator`.

- opening corpse does not copy its contents into UI;
- UI displays authoritative container slots;
- harvesting and looting the same corpse in the same frame serialize through corpse/inventory revision;
- death-bag conversion atomically transfers remaining protected stacks from corpse inventory to bag inventory;
- a stack can have one authoritative owner/container at a time.

## Required tests

- simple passive corpse loses configured delicate loot if harvested first;
- boss protected loot survives accidental corpse removal through death bag;
- knife vs axe yield profiles produce different resource ratios;
- same corpse stack cannot be looted and copied into death bag simultaneously;
- decomposition conversion is atomic;
- player death bag preserves configured inventory exactly once;
- pack aggression enables/disables at thresholds;
- night-only aggression changes without respawning the same mob unless definition requires it.
