# Game Architecture

## Layering

Black Island separates authoritative data/state from Scene representation.

```text
Definitions / versioned static data
        ↓
Authoritative Runtime State
        ↓
Domain Services / Solvers
        ↓
Scene & Presentation Adapters
        ↓
UI / VFX / Audio
```

Scenes are views/controllers over domain state. Scene unload must not silently erase state that is defined as persistent/session-authoritative.

## Major domains

- Boot/save/profile
- Smooth volumetric voxel terrain + chunk streaming
- Dynamic water/hydrology
- Biomes/props/foliage/world generation
- BuildGrid/shared edges/sockets/support provenance
- Farming/FarmPlots
- Player movement/camera/input/interaction
- LPC catalog/appearance/composition/presentation
- Inventory/items/equipment/ownership
- Inventory transaction coordinator
- Crafting/workstations/containers
- Combat/elements/status/skills/Ultimates
- Mob ecology/disposition/corpses/loot
- NPC jobs/skills/schedules/relationships/memory
- Dialogue/social events
- CaveRun/anchored cave floors/elevator progression
- Progression/skill tree
- UI/UX
- Optional networking/tribes/community appearance
- Optional external AI providers

## Authoritative boundaries

### Terrain

Voxel/SDF/material state owns terrain solidity and surface material truth.

Smooth meshes, normals and collision are generated products.

Project scale starts at 0.5 m terrain voxel spacing, 1 m BuildCell and 64 m cubical WorldChunks.

### Water

`WaterService`/compact water grid owns local water amount/flow state. Surface meshes, foam and waterfall VFX are presentation.

The ocean horizon may be visual/analytic without allocating dynamic water cells everywhere.

### Construction

`BuildGrid` + structure state own occupancy and structural topology.

Support is based on real-root provenance and allowed horizontal reach. Connectivity alone is not support; walls/floating geometry do not reset root distance.

### Farming

`FarmPlotState` owns crop, seed, moisture, fertilizer, growth and decay state.

The underlying terrain owns only its terrain material/geometry. Crop visuals are presentation derived from FarmPlot state.

### Character visuals

`CharacterAppearance` + compiled LPC catalog own selections/recolors/body/equipment visual state.

Composed Sprite3D textures/clips are cached presentation, never collision authority.

### Inventory

Each inventory/container owns slots/stacks and revision.

`InventoryTransactionCoordinator` is the only authority allowed to transfer/consume/create inventory-owned item stacks.

UI, crafting timers, corpse screens and workstations submit commands; they do not edit quantities directly.

### Crafting

`CraftService` owns queue semantics and requests unit transactions when timers become ready.

A timer is scheduling only. Recipe output cannot exist before authoritative ingredient payment succeeds.

### Mobs/corpses

Living entity state owns health/AI. `CorpseState` owns harvest/decomposition and remaining corpse loot. `DeathBagInventory`/`WorldDropBag` owns item stacks after transfer.

### Caves

`CaveRun` owns ephemeral run-scoped floor state. An anchored floor has separate persistent state and survives run reset.

Do not treat every generated cave floor as permanently saved by default.

## Domain event examples

Use explicit typed/domain events or direct service interfaces rather than a global signal soup.

Examples:

- `TerrainRegionChanged(aabb)` -> water, foliage, FarmPlot validation, navigation;
- `StructureTopologyChanged(region)` -> support solver + navigation + foliage suppression;
- `InventoryCommitted(change_set)` -> UI refresh + queue feasibility recalculation;
- `AppearanceChanged(character_id)` -> LPC cache resolution;
- `WeatherEvent(region, intensity)` -> FarmPlot moisture + water/visual consumers;
- `CorpseRemoved(corpse_id)` -> protected-loot death-bag resolution;
- `CaveAnchorActivated(floor)` -> persistent floor registry + elevator network.

## Data-driven definitions

Prefer typed Resources/serializable definitions such as:

- `ItemDefinition`
- `RecipeDefinition`
- `WeaponDefinition`
- `MovesetDefinition`
- `AttackDefinition`
- `UltimateDefinition`
- `ElementDefinition`
- `NPCDefinition`
- `MobDefinition`
- `AggressionRuleDefinition`
- `HarvestProfile`
- `RelationshipRuleDefinition`
- `StructureDefinition`
- `CropDefinition`
- `BiomeDefinition`
- `PropSpawnDefinition`
- `CaveFloorProfile`
- `WaterProfile`

Runtime references stable IDs and versioned definitions where persistence requires it.

## Persistence classes

Not every runtime state has the same lifetime.

### Permanent save state

Examples:

- surface terrain edits;
- player/village inventory;
- structures;
- NPC identity/relationships;
- FarmPlots;
- anchored cave floors;
- unlocked progression.

### Run/session state

Examples:

- unanchored cave floor mutations during current CaveRun;
- temporary encounter state;
- transient caches.

### Generated/disposable presentation

Examples:

- grass blade instances;
- generated terrain meshes;
- temporary VFX;
- distant prop impostors.

Explicit lifetime prevents accidental save bloat.

## Determinism and IDs

World generation is seed-driven. Generated persistent candidates use stable IDs derived from seed/generation version/spatial identity.

Never persist Godot Node instance IDs as long-term identity.

## Threading

Pure generation/meshing/data work may occur in workers or Voxel Tools jobs.

Active SceneTree mutation and unsafe rendering/physics operations remain main-thread/budgeted work.

Terrain, prop and water systems must avoid a sudden burst of completed jobs causing one-frame integration stalls.

## Ownership abstraction

Items, containers and structures should carry a project ownership abstraction compatible with:

- local player/village now;
- future tribe ownership;
- server/host authority later.

Chapter 1 remains offline-first.

## Focused specs

Architecture:

- `docs/architecture/VOXEL_WORLD_IMPLEMENTATION.md`
- `docs/architecture/WORLD_STREAMING.md`
- `docs/architecture/WATER_AND_HYDROLOGY.md`
- `docs/architecture/LPC_PIPELINE.md`

Design/system specs:

- `docs/design/PLAYER_LPC_AND_3D_PRESENTATION.md`
- `docs/design/PLAYER_COMBAT.md`
- `docs/design/CHARACTER_CREATOR.md`
- `docs/design/BUILDING_AND_STRUCTURAL_SUPPORT.md`
- `docs/design/FARMING_AND_FOLIAGE.md`
- `docs/design/BIOMES_AND_PROP_GENERATION.md`
- `docs/design/INVENTORY_AND_CRAFTING.md`
- `docs/design/MOBS_CORPSES_AND_LOOT.md`
- `docs/design/CAVES_AND_ANCHOR_PROGRESSION.md`
- `docs/design/OPEN_DESIGN_CHECKLIST.md`
