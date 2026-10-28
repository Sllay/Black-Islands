# Player Combat — Design/Technical Spec

Status: Accepted core direction; balance/content values remain tunable.

## Combat identity

Black Island combat aims for the readability/responsiveness of Cult of the Lamb while supporting more weapon-specific depth.

Core principles:

- attacks are intentional/telegraphed;
- no default touch damage just because actors overlap;
- weapon defines practical combat class/moveset;
- normal/heavy attacks can combo;
- one weapon skill is tied to the active weapon;
- one equipped Ultimate is a rarer boss-derived power;
- dodge/roll has invulnerability window;
- selected weapon families can guard/parry.

## Mobile controls

Baseline right-side combat layout:

- large Attack button;
- Skill button above/near Attack;
- Ultimate button near Skill;
- Dodge button positioned for reliable thumb access;
- contextual Guard button appears/replaces an action only when current weapon supports guard.

Exact screen geometry is a mobile UX tuning task.

## Normal attack

Tap Attack:

- requests current weapon's next light/normal combo action;
- uses input buffering during allowed cancel/combo windows;
- attack definition determines movement, hitbox, timing, damage and effects.

Repeated taps do not directly play arbitrary animation strings; they advance a `ComboGraph`/moveset state.

## Heavy/precise attack

Hold Attack:

1. enter `HeavyAim` state after hold threshold;
2. player stops or strongly limits locomotion according to weapon;
3. movement joystick is temporarily interpreted as attack direction/aim;
4. aim indicator/telegraph shows direction/shape;
5. release Attack -> execute heavy attack toward chosen direction.

This reproduces the mobile directional heavy-attack behavior desired from Cult of the Lamb while remaining data-driven.

Heavy attacks may be:

- narrow high-damage line;
- forward dash/lunge;
- circular AOE;
- cone;
- ranged charged projectile/volley;
- weapon-specific special geometry.

## Combo graph

Normal and heavy attacks may transition into one another where a weapon allows it.

Conceptual transition conditions:

```text
Light1 -> Light2
Light2 -> Light3
Light1 + heavy input -> HeavyVariantA
Light2 + heavy input -> HeavyVariantB
HeavyA -> finisher
```

Do not hard-code combo count globally.

`MovesetDefinition` owns transitions and allowed input windows.

## Weapon families

Chapter 1 architecture supports families such as:

- sword;
- club/mace;
- axe;
- hammer;
- daggers;
- bow;
- wand/staff;
- shield-paired/resilient weapon sets;
- future weapons through definitions.

Each family can define distinct normal/heavy/skill behavior without changing `PlayerCombatController`.

## Skill

Skill is tied to the active weapon/weapon definition.

Examples:

- elemental burst;
- dash attack;
- vampiric strike;
- poison application;
- light/darkness ability;
- weapon-specific mobility/control.

Skill has its own cooldown/resource rules from data.

Swapping active weapon swaps its Skill.

## Ultimate

Ultimate is conceptually independent from ordinary weapon skill.

Bosses may have a chance to drop/unlock their Ultimate power.

The player can acquire/equip boss-derived `UltimateDefinition`s.

Ultimate design is intentionally suited to boss/high-impact encounters and can have:

- long cooldown/charge requirement;
- large telegraph/VFX;
- powerful damage/control/support effects;
- unique semantic animation presentation.

Do not bind Ultimates to one specific weapon unless a definition explicitly requires it.

## Dodge / roll

Dodge is a core defensive action.

`DodgeDefinition` controls:

- movement curve/distance;
- startup;
- invulnerability window;
- recovery;
- stamina/cooldown if configured;
- collision behavior;
- animation semantic.

I-frames are explicit state windows, not inferred from animation opacity.

## Guard

Only weapon definitions that support guard expose Guard behavior.

Guard may represent:

- weapon + shield set;
- large/resilient weapon used defensively;
- another authored defensive weapon style.

The player does not equip a completely independent shield in a separate generic offhand system for the baseline design; shield behavior is part of the weapon/moveset package.

While Guard is held:

- player can move slowly;
- facing direction is maintained/aimable;
- attacks within the frontal guard arc receive configured damage reduction/block effect;
- attacks from behind/outside the guard arc bypass or break guard according to rule.

## Guard break

If an attack hits outside the valid frontal guard region or exceeds a configured break rule:

- guard becomes unavailable for a short recovery;
- player takes normal/configured damage;
- feedback clearly indicates the break.

## Parry

A small timing window after guard activation can produce a parry.

On valid frontal parry:

- player takes zero damage from the parried attack;
- attacker receives a brief stun/stagger where allowed;
- strong hitstop/VFX/audio feedback;
- bosses may use reduced/alternate stagger rules.

Parry timing is an explicit combat window, not based on exact rendered frame equality.

## Attack definition

Conceptual `AttackDefinition`:

```text
id
semantic_animation
windup
active_duration
recovery
movement_curve
turning_rules
hitbox_shape/offset
multi_hit_rules
damage
knockback
hitstop
stagger
resource_costs
element/effects
combo_inputs/cancel_windows
aim_mode
projectile_definition optional
```

## Damage execution

Attack flow:

`input -> combat state -> windup -> animation/event sync -> active hitbox/projectile -> hit resolution -> recovery -> combo/cancel transition`

Hitbox owns hit registration; Sprite3D visual does not.

Track targets already hit by the same attack instance to prevent accidental multi-frame repeated damage unless the attack explicitly allows multihit.

## Hitstop

Hitstop is brief presentation/gameplay time scaling around confirmed impactful hits.

Rules:

- local/controlled duration;
- attacker and victim can receive different freeze weighting;
- UI/network timers should not depend on raw scaled frame count;
- mobile VFX remains light.

## Knockback/stagger

Knockback is a gameplay impulse resolved by combat/character motor.

Enemies can expose poise/stagger rules so heavy attacks feel different from light strikes.

## Elements

Weapons/attacks can carry elemental tags such as:

- fire;
- water;
- earth;
- plant/nature;
- rare light;
- rare darkness;
- rare blood/sanguine.

Element effects/reactions are resolved through project data, not scattered `if fire && plant` branches.

## Targeting

Melee uses volumes/hitboxes and aim direction, not only one center ray.

Ranged/heavy directional attacks may use aim assistance suitable for touch:

- nearest valid target bias inside aim cone;
- soft direction snapping;
- never hard teleport aim behind the player without input.

## Enemy combat expectation

Enemies use windup/active/recovery and telegraph before damaging attacks.

Aggression/AI chooses **when/why** to attack; `AttackDefinition` determines **how** the attack executes.

## LPC integration

Combat requests semantic visual actions.

Example:

`AttackDefinition.semantic_animation = MELEE_SLASH`

`LPCAnimationResolver` chooses compatible LPC clip (`1h_slash`, `slash`, custom oversized, etc.) for the active appearance/equipment.

Gameplay timing remains defined by combat data and animation events/fallback mapping.

## Required tests

- holding Attack enters HeavyAim without immediately spending/crafting damage;
- joystick direction during HeavyAim controls attack direction rather than locomotion;
- release executes exactly once;
- same attack instance cannot repeatedly damage one target unless multihit enabled;
- dodge i-frame window blocks valid incoming hit and ends deterministically;
- rear attack bypasses frontal guard;
- parry window causes zero damage + valid stagger;
- weapon swap changes skill/moveset without carrying stale combo state;
- boss Ultimate acquisition/equip does not mutate weapon definition;
- input buffering does not execute commands after Hurt/Dead invalidates them.
