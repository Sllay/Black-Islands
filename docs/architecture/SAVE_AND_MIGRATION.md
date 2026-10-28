# Save & Migration Architecture

Status: accepted architecture direction; binary/serialization implementation requires Codex benchmark/testing.

## Core rule

Save **authoritative state**, not current SceneTree presentation.

Never make a Godot Node instance ID, transient resource pointer or generated mesh the only representation of persistent game truth.

## Save identity

Every save contains at least:

```text
save_schema_version
world_generation_version
content_definition_version(s)
world_seed
save_id
created_at / last_saved_at metadata
```

Migrations operate from explicit version numbers.

## Atomic write strategy

Mobile-safe baseline:

1. serialize new save/chunk state to temporary file;
2. validate serialization/checksum/header;
3. flush/close;
4. rotate previous known-good backup where practical;
5. atomically replace/rename active save file;
6. never overwrite the only good copy in-place halfway through a write.

Large world/chunk files can use independent versioned records so changing one terrain chunk does not rewrite the entire island.

## Surface world

Surface generation occurs once at save creation.

Persist:

- accepted world seed/profile;
- world generation version;
- stable POI placements that must not reroll;
- terrain voxel/material deltas from generated base;
- persistent water edits/state where required;
- persistent gameplay props/resource state where rules require it;
- structures/construction sites;
- FarmPlots/crops;
- persistent mobs/NPCs;
- village/world event state.

Do not persist:

- generated terrain mesh triangles;
- collision mesh cache if safely regenerable;
- decorative grass blade transforms when deterministic from seed/biome;
- far ocean render mesh;
- visual-only birds.

## Terrain chunk persistence

Base terrain comes from deterministic generation.

Chunk save data should store compact mutations/deltas, with a path to compaction if long-running saves modify large percentages of a chunk.

Conceptual:

```text
WorldChunkSave
- chunk_coord xyz
- generation_version/base_hash
- voxel_delta_encoding
- material_delta_encoding
- local persistent prop overrides
- water persistent delta optional
```

If a chunk becomes heavily modified, implementation may switch from sparse delta to compact full/brick representation, but this is an encoding decision behind one schema.

## Structures

Persist stable structure state:

- structure instance ID;
- StructureDefinition ID/version;
- BuildGrid coordinate/elevation/rotation;
- material tier;
- current/max HP relevant state;
- owner/tribe scope;
- custom configuration;
- support topology can be recomputed from placed structure state rather than serialized as unquestionable truth.

On load:

`structures -> rebuild occupancy/shared edges -> rebuild support graph -> validate`

Do not trust a stale cached support-parent pointer from a previous version.

## Large ConstructionSites

Persist:

- paid structure definition/site ID;
- transform/footprint;
- resources-paid flag/transaction identity where needed;
- total/completed work units;
- owner;
- assigned worker references where meaningful.

Do not repay/reconsume resources merely because a site reloaded.

## Player

Persist:

- transform/safe spawn context;
- stats/progression;
- inventory/equipment/hotbar assignments;
- unlocked recipes/skills/Ultimates;
- CharacterAppearance/LPC stable catalog IDs + catalog/schema version;
- quests/relationships relevant to player;
- world ownership/tribe state later.

Do not save LPC composed textures; regenerate/cache them from appearance data.

## Inventory and containers

Persist authoritative slot stacks and container IDs.

Transaction revisions are runtime concurrency guards; persistence can restore/reset revisions to a new monotonic session baseline as long as no half-transaction can be serialized.

**Never write a save in the middle of a multi-inventory transaction.**

Save coordinator either:

- waits until active transaction commit completes; or
- snapshots from an immutable committed state.

## Craft queue

Persist:

- ordered recipe IDs;
- remaining quantities;
- queue metadata required by definitions.

Current accepted rule: **do not persist partial elapsed unit timer**.

After load, active slot starts its current unit timer from zero.

No resources were consumed for the incomplete timer, so no refund is required.

## Farming

Persist FarmPlot authoritative state:

- grid anchor;
- crop/seed ID;
- growth progress/day milestones;
- moisture reserve;
- fertilizer state;
- decay deadline/state;
- harvest-ready state;
- definition version references.

Visual crop node is recreated from state.

## World clock/weather

Persist:

- current world day/time;
- weather state;
- scheduled transition/seed/state needed for deterministic continuation;
- one-shot weather event IDs if needed to prevent replay after save/load.

Do not infer world time from lighting angle.

## Persistent mobs / NPCs

Persist meaningful `WorldMobState`/NPC state rather than current AI node stack.

Examples:

- persistent ID;
- definition + level;
- HP/status;
- logical world position/region;
- current high-level intent where continuity matters;
- inventory;
- unique/group/quest flags;
- relationship/job/schedule/memory for NPCs;
- last simulated world time.

On load, simulation tier decides whether a Scene actor is instantiated.

## Disposable ambience

Do not save:

- decorative Boids bird instances;
- disposable fish school visuals;
- ordinary temporary VFX;
- particles;
- generated grass blades.

Regenerate from environmental state.

## Corpses/death bags

Persist only when their policy/lifetime matters across save/load.

Record:

- remaining corpse harvest state/resources;
- delicate/protected inventory;
- decomposition deadline;
- death bag inventory/container identity.

Do not allow both pre-conversion corpse inventory and post-conversion death-bag inventory to load with the same stack ownership.

## CaveRun

Unanchored floors are ephemeral between completed/abandoned runs, but quitting/crashing while inside a live run should not arbitrarily duplicate/reset the player's current expedition.

Persist a **temporary active CaveRun resume state** when the player is currently underground:

- run ID/seed/version;
- current floor;
- temporary generated floor state required for safe resume/backtracking;
- player position/spawn envelope;
- run rewards/events already consumed.

When the player returns to surface and the run officially ends, unanchored temporary run records may be deleted.

## Anchored cave floors

Persist fully required authoritative state:

- anchor ID/chain;
- floor index/biome/profile/seed;
- terrain mutations;
- structures;
- containers/resources according to persistent rules;
- water changes;
- elevator stop;
- NPC/POI state.

Never reroll an anchored floor due to a new CaveRun.

## Totem of Anchoring

Persist anchor activation transaction exactly once.

The consecutive anchor chain is recomputed/validated from persistent anchor records on load.

## LPC catalog/content migration

Appearance save records use stable Black Island catalog IDs + aliases/migration data.

If upstream LPC moved/renamed an asset:

`old saved ID -> alias/migrator -> current catalog ID/fallback`

Do not save only a raw upstream PNG path.

## Definition migration

Items/recipes/structures/mobs use stable IDs.

When a definition changes:

- non-breaking tuning may load normally;
- renamed ID uses explicit alias;
- deleted content requires migration/fallback/refund policy;
- recipes in a saved queue must resolve current definition or be safely cancelled without generating unpaid output.

## Unknown/future data

Where feasible, use forward-compatible keyed records and ignore unknown optional fields rather than crashing old/new save readers.

Required fields still fail validation loudly and recover to backup instead of silently creating corrupt state.

## Save testing requirements

Codex must maintain regression fixtures for:

- save during terrain edits;
- save with active crafting queue;
- save with chest/workbench scope open;
- save while ConstructionSite is partially built;
- save during storm/lightning event;
- save with persistent mob in each simulation tier;
- save inside CaveRun;
- save with anchored cave floor;
- save with corpse converting to death bag boundary;
- migration across renamed item/LPC/structure IDs;
- corrupted/truncated active save fallback to known-good backup.
