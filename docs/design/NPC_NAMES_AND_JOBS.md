# NPC Names & Jobs — Design Spec

Status: accepted baseline architecture; large name dataset should be generated/validated by a dedicated Codex task.

## Name system goal

Black Island should avoid a tiny obvious name list while keeping names readable and controllable.

Initial content direction:

- around 1,000 curated `NameToken` entries is preferable to maintaining separate 500-first-name + 500-surname lists if tokens can be valid in both positions;
- some entries can still be marked given-name-only or surname-only when necessary;
- later a syllabic name generator can plug into the same provider interface without rewriting NPC/save code.

## NameToken schema

Conceptual JSON entry:

```text
NameToken
- id
- text
- can_be_given_name
- can_be_surname
- presentation_tags optional
- culture/style tags optional
- weight
```

Possible presentation tags can include masculine/feminine/neutral when useful, but the system should not force every token into one binary category.

## Name generation

`NPCNameProvider` should support implementations such as:

- `CuratedPoolNameProvider`
- future `SyllabicNameProvider`
- future localization/culture-specific provider.

Output modes:

- given name only;
- surname-style single name;
- given + surname.

Probabilities are data/configuration.

Within one save, recent-name reuse can receive a weight penalty to reduce obvious duplicates without requiring global uniqueness forever.

## Codex name-data task

A dedicated subagent can generate the initial JSON dataset, but it must run validation before acceptance:

- no profanity/slurs;
- no malformed control characters;
- no duplicate normalized tokens;
- sensible length limits;
- readable Unicode/localization policy;
- mark whether token is safe in given/surname position;
- deterministic stable IDs.

Do not let an LLM-generated list ship directly without validation/review tooling.

## Initial NPC jobs

Baseline job families:

- Farmer
- Miner
- Blacksmith
- Vendor
- Adventurer / Explorer
- Gatherer
- Builder

Future jobs can be added through definitions.

## Initial story survivors

Early story direction:

- Farmer: guaranteed survivor, seed/farming access role;
- Adventurer/Explorer: guaranteed survivor;
- Miner: rescuable/high-value early NPC who may die if the player fails/arrives too late according to story-event rules.

The Miner is useful for resource progression but the game must remain recoverable if that NPC dies.

## JobDefinition

Conceptual:

```text
JobDefinition
- stable_id
- required/related skills
- workplace tags
- task generators
- schedule preferences
- production outputs
- tool requirements
- XP/skill growth rules
```

NPC state references a stable job ID; job logic is not embedded in appearance/name data.

## Farmer

Responsibilities can include:

- seed shop/supply;
- farming guidance/tutorial;
- assigned crop work later;
- agricultural production.

## Miner

Responsibilities can include:

- stone/ore/resource work;
- mine-related progression;
- early resource assistance;
- later workstation/expedition tasks.

## Blacksmith

Responsibilities:

- weapon/tool repair/crafting progression;
- metal-tier content;
- smithy/workshop interactions;
- equipment services.

## Vendor

Responsibilities:

- generic trading/shop role;
- configurable stock/economy source;
- later tribe/village economy participation.

## Adventurer / Explorer

Responsibilities:

- exploration/POI knowledge;
- quests/scouting;
- possible combat/expedition role;
- early narrative guide.

## Gatherer

Gatherer is a flexible resource job with specializations/assigned tasks such as:

- lumber;
- fruit/forage;
- fiber/plants;
- surface material collection.

It should use the same harvesting/resource definitions as the player rather than generating arbitrary resources disconnected from world rules, although offscreen work may resolve statistically for performance.

## Builder

Builder assists large `ConstructionSiteState` projects.

Small modular structures still place immediately through the ordinary build system.

Large/civic blueprints accumulate work units. Builder NPCs contribute work rate to accelerate completion.

## Skill progression

NPC competence should improve by doing relevant work.

Examples:

- Mining skill -> Miner productivity;
- Farming skill -> Farmer efficiency;
- Construction skill -> Builder work rate;
- Smithing skill -> Blacksmith capability.

Job is assignment; skill is learned capability. They are not the same field.

## Required tests

- save stores stable name text/token references safely across updates;
- name generator cannot produce an invalid empty/full duplicate string from two tokens;
- future syllabic provider can replace pool provider without changing NPC save schema;
- Builder work contributes to one authoritative construction progress value;
- Miner death does not corrupt required save progression;
- job assignment does not overwrite NPC appearance/relationship state.
