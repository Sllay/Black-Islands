# Weapon Families & Combos — Design/Technical Spec

Status: accepted Chapter 1 weapon-family direction; exact frame timing/damage values require gameplay tuning.

## Core content rule

Moveset/combo identity belongs primarily to the **weapon family**, not to every elemental variant.

Example:

```text
Sword
├── Standard Sword
├── Fire Sword
├── Water Sword
├── Earth Sword
├── Nature Sword
├── Sanguine Sword
├── Darkness Sword
└── Light Sword
```

They can reuse the Sword combo graph while changing:

- damage/stat tuning;
- element/status tags;
- weapon Skill;
- VFX/audio;
- passive/special effect;
- heavy/finisher modifier where explicitly authored.

This prevents content explosion.

## Variant families

Initial three conceptual groups:

### Standard

Primarily physical/default form.

### Common Elemental

Core elements such as:

- Fire
- Water
- Earth
- Nature/Plant

### Rare Aspect

Rare/high-value themes:

- Sanguine/Blood
- Darkness
- Light/Holy

Rare aspect does not automatically mean higher raw DPS in every situation; rarity can come from unusual passives/reactions/Skill behavior.

## Combo notation

For docs:

- `L` = light/normal attack tap;
- `H` = charged/heavy release;
- `S` = weapon Skill;
- `D` = Dodge where combo/cancel allows it.

Moveset definitions contain actual timing windows. Input strings are design notation, not hard-coded parser strings.

## Sword

Identity:

- balanced damage/speed;
- moderate movement commitment while attacking;
- reliable arc coverage;
- medium heavy charge time;
- generalist weapon.

### Light chain

Candidate baseline:

`L -> L -> L`

Three readable slashes with controlled forward motion.

### Heavy

Forward **cone/sector** slash:

- narrow close to player;
- wider farther forward;
- medium range;
- good multi-target coverage;
- player commits/stops during charge and executes toward aimed direction.

### Combo concepts

- `L -> H`: quicker directional power slash;
- `L -> L -> H`: wider finisher with higher stagger;
- successful finisher may get stronger hitstop/element proc chance.

## Daggers

Identity:

- lower damage per individual hit;
- highest/very high attack speed;
- highest movement freedom during light attacks;
- short reach;
- strong cancel/dodge flexibility;
- fastest heavy charge among the baseline melee families.

### Light chain

Fast multi-hit chain, e.g. 4-hit baseline rather than forcing every family to use three attacks.

### Heavy

Straight-line dash/lunge:

- narrow hitbox;
- player stops during aim/charge;
- release performs rapid forward movement;
- high precision/single-target identity;
- can pass/stop according to collision rule.

### Combo concepts

- `L -> L -> H`: rapid piercing/flurry dash;
- late light -> Dodge cancel available earlier than heavy weapons;
- future backstab/bleed identities can be variants, not mandatory base mechanic.

## Club / Mace

Identity:

- moderate/low raw damage relative to Axe;
- medium-fast cadence;
- high knockback;
- high stagger/control;
- repeated hits build a short-lived `Daze/Stagger` pressure state.

### Light chain

`L -> L -> L`

Landing consecutive valid hits within a short window can trigger a brief daze/slow/stagger effect.

This is a combat status/poise rule, not animation-only feedback.

### Heavy

Compact radial/area smash/sweep:

- moderate radius;
- lower raw damage than Axe;
- strong knockback/stagger;
- useful for crowd control.

### Combo concepts

- `L -> L -> H`: stronger stun/stagger finisher;
- repeated uninterrupted lights accelerate Daze threshold.

## Axe

Identity:

- highest or near-highest raw single-hit damage among baseline melee weapons;
- slower than Club/Sword, faster than Hammer;
- meaningful movement commitment;
- broad but not enormous area;
- lower knockback emphasis than Club/Hammer.

### Light attack

Broad cleaving arc, capable of hitting multiple nearby targets.

### Heavy

Heavy circular/broad cleave:

- smaller area than Hammer's signature spin;
- very high damage;
- medium-low knockback;
- slower charge than Sword/Daggers.

### Combo concepts

- `L -> H`: quick transition into an execution-style cleave;
- `L -> L -> H`: high-damage finisher with strong poise damage.

## Hammer

Identity:

- slowest baseline melee family;
- medium/high impact damage rather than Axe's pure damage specialization;
- largest knockback;
- strongest crowd displacement;
- broadest heavy melee area.

### Light attack

Slow heavy swings with useful local area and strong hitstop.

### Heavy — signature spin

Player releases into a 360-degree spinning hammer attack:

- wide radial hit area;
- massive knockback;
- substantial stagger;
- hits surrounding targets;
- lower pure DPS efficiency than Axe so its value is control/space creation.

Multi-hit spin requires explicit per-target hit rules so one target is not accidentally damaged every physics frame.

### Combo concepts

- `L -> H`: quicker spin entry with reduced radius/damage;
- `L -> L -> H`: full-force displacement finisher.

## Bow

Identity:

- ranged precision;
- mobility/readable spacing;
- normal shot cadence;
- directional heavy aim;
- combo rewards timing rather than melee proximity.

### Normal

Tap Attack fires ordinary projectile/arrow according to fire-rate/input-buffer rules.

### Heavy

Hold Attack enters bow HeavyAim:

- player stops/strongly limits movement;
- joystick controls shot direction;
- charge increases authored projectile behavior/damage;
- release fires charged shot.

Possible baseline charged identity: higher damage + penetration/stagger rather than simply a larger arrow.

### Combo concept — rapid shots into heavy

`L -> L -> H` inside the combo window:

- instead of one normal charged arrow, execute a three-arrow burst/volley in rapid succession;
- increased impact/stagger potential;
- direction comes from heavy aim;
- projectile definition decides small spread vs same-line sequence.

This is an actual ComboGraph transition, not a hidden timer hack in Bow script.

## Skill

Every equipped weapon definition supplies one Skill.

Family gives design language; individual weapon variant supplies the actual Skill.

Examples:

- Fire Axe: burning cleave;
- Sanguine Daggers: life-steal rush;
- Light Sword: radiant wave;
- Darkness Bow: shadow projectile/mark;
- Earth Hammer: ground shockwave.

Skills can be unique without replacing the family's normal/light/heavy combo graph.

## Ultimate

Ultimate remains separate from active weapon.

Bosses can unlock/drop boss-derived Ultimate abilities.

Switching weapon:

- changes family moveset;
- changes Skill;
- does not automatically change equipped Ultimate.

## Damage/knockback identity matrix

Qualitative starting point:

| Family | Raw Damage | Speed | Mobility while attacking | Knockback | Area |
| --- | --- | --- | --- | --- | --- |
| Sword | Medium | Medium | Medium | Medium | Medium cone/arc |
| Daggers | Low per hit / high DPS potential | Very High | Very High | Low | Narrow |
| Club | Medium-Low | Medium-High | Medium | High | Medium |
| Axe | Very High | Low-Medium | Low-Medium | Medium-Low | Medium |
| Hammer | Medium-High | Low | Low | Very High | High |
| Bow | Variable | Medium | Range-dependent | Low-Medium | Projectile/volley |

Actual DPS must be normalized/tuned so 'Axe highest hit' does not automatically mean every other weapon is inferior.

## Required tests

- elemental Sword retains Sword combo graph unless variant explicitly overrides it;
- Daggers can cancel/move more freely than Hammer under data definitions;
- `L-L-H` Bow transition reliably produces its authored volley exactly once;
- Hammer spin cannot apply unintended damage once per physics frame;
- Club consecutive-hit status resets outside combo window;
- Axe has higher single-hit identity without automatically having highest effective DPS in all scenarios;
- weapon swap resets invalid combo state and replaces Skill but keeps equipped Ultimate.
