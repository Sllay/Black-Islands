# Weather, Day/Night & Fire — Design/Technical Spec

Status: accepted Chapter 1 direction; visual tuning and probabilities remain tunable.

## Day/night cycle

Black Island uses an accelerated configurable world clock.

Initial default target:

```text
Dawn/Day/Dusk combined: 16 real minutes
Night:                 6 real minutes
Total cycle:          22 real minutes
```

A useful internal split for presentation can begin around:

```text
Dawn  1.5 min
Day   13.0 min
Dusk  1.5 min
Night  6.0 min
```

The save stores world time/day state, not a Timer Node.

World/save settings may expose day/night duration multipliers later. Systems query authoritative `WorldClock` phase/state rather than reading sky color.

## Weather states

Initial weather state machine:

- `CLEAR`
- `CLOUDY`
- `RAIN`
- `THUNDERSTORM`

Transitions are generated from deterministic/probabilistic weather scheduling so save/load does not randomly change weather merely because the scene reloaded.

Weather state affects systems through semantic events/state:

- lighting/sky/VFX/audio;
- farming moisture;
- water input where simulation supports it;
- lightning hazards;
- selected mob behavior/spawn conditions.

## Rain and farming

Rain waters eligible FarmPlots.

Baseline direction:

- ordinary watering is intended to cover roughly one in-game day;
- sufficiently strong/long rain can saturate a plot with a moisture reserve worth up to roughly three in-game days;
- moisture reserve is state/data, not a particle collision check per raindrop.

## Thunderstorms

A thunderstorm periodically schedules lightning strike opportunities.

Chapter 1 target selection intentionally favors eligible trees/world targets rather than directly sniping player structures.

Conceptual targeting:

```text
storm region
-> collect eligible strike candidates using spatial index
-> weight by exposed/tall/tree candidate rules
-> choose deterministic/random candidate from storm seed
-> validate loaded/streaming state
-> execute LightningStrikeEvent
```

If a target region is unloaded, the event can be represented logically and resolved when appropriate rather than forcing the entire region into full Scene simulation.

## Lightning strike

A direct tree strike uses percentage-based damage so the same rule scales across tree variants.

Initial tuning target:

```text
Tree direct damage:       50%..70% of Max HP
Structure direct/AOE:    around 10% of affected piece Max HP at strongest point
```

AOE falls off with distance.

This avoids maintaining bespoke lightning-damage tables for every structure material.

Player/NPC/mobs inside the impact radius can receive authored lightning/electric damage through the combat damage system.

Chapter 1 rule: structures can be damaged by lightning impact but are not automatically set on fire.

## Tree fire/char state

A lightning-struck tree can enter:

```text
NORMAL
-> BURNING (if ignition succeeds)
-> CHARRED or DESTROYED
```

If the initial strike kills/breaks the tree, normal destruction rules apply.

If it survives/burns out:

- tree has very low remaining HP;
- a simple char/burn material/shader treatment replaces the need for a dedicated charred texture;
- its `HarvestableDefinition/Profile` can swap from Wood-focused yield to Charcoal-focused yield.

The shader is presentation; the `TreeState` decides whether the harvest profile is normal or charred.

## Fire propagation baseline

Chapter 1 should keep propagation bounded/mobile-safe.

Use event-based local spread rather than one fire physics object per blade of grass.

Conceptual:

```text
BurningTarget
-> periodic nearby flammable query
-> limited spread attempts
-> weather/wetness modifier
-> spatial/event cap
```

Wet/raining vegetation suppresses ignition probability.

Full wildfire simulation is not required for the first playable world; the architecture should permit it later.

## Lightning presentation

The strike event can drive:

- bolt/beam or generated lightning visual;
- short flash/exposure effect;
- thunder delayed by distance if desired;
- ground/tree impact VFX;
- camera/audio impulse near impact;
- fire/char transition.

Do not keep an expensive continuous lightning simulation after impact.

## Mob/time integration

WorldClock/weather conditions feed aggression/spawn rules.

Examples:

- skeleton spirits activate skeleton bodies at night and return to dormancy by day;
- selected neutral creatures become aggressive at night;
- zombies prefer night migration/raids and take sunlight damage during day;
- weather-specific creatures/events can be added through conditions.

## Required tests

- save/load preserves world phase/weather schedule;
- rain updates FarmPlot moisture without per-drop physics;
- lightning tree damage is percentage-based;
- one lightning event cannot apply the same direct strike twice after save/load;
- surviving tree can transition to Charred and use charcoal harvest profile;
- structure receives percentage damage without ignition under Chapter 1 rule;
- unloaded lightning region does not force full-world Scene loading;
- day/night transitions update conditional mob behavior deterministically.
