# Game Architecture

## Layering

Black Island separates authoritative data/state from its current Scene representation.

```text
Definitions (Resources/static data)
        ↓
Persistent Runtime State
        ↓
Domain Systems
        ↓
Scene/Presentation Adapters
        ↓
UI / VFX / Audio
```

Scenes are views/controllers over state; unloading a Scene must not erase persistent world truth.

## Major domains

- Boot/save/profile
- Smooth volumetric voxel terrain and chunk streaming
- Biomes, props, foliage and world generation
- Square construction grid, shared edges, sockets and structural support graph
- Player/camera/input
- LPC catalog/appearance/composition/presentation
- Inventory/items/equipment
- Combat/elements/status effects
- Transactional queued crafting
- Farming
- NPC jobs/skills/schedules/relationships/memory
- Dialogue/social events
- Cave/mine floors
- Progression/skill tree
- UI/UX
- Optional networking/community appearance services
- Optional external AI providers

## Authoritative boundaries

### Terrain

Voxel data owns terrain solidity/density/material. Smooth meshes/collision are generated presentation/physics products of that data.

### Construction

`BuildGrid`/structure state owns occupancy and support semantics. Render transforms do not define whether a cell/edge/socket is occupied.

Structural validity is graph/provenance/capacity based. Connectivity alone does not imply support.

### Character visuals

`CharacterAppearance` + the compiled LPC catalog own visual selections. The `Sprite3D`/composed texture is presentation and never authoritative collision/gameplay state.

### Crafting

Inventory state and `InventoryTransaction` own item payment/output. UI timers and queue widgets are not economic authority.

## Data-driven definitions

Prefer typed Resources/serializable definitions such as:

- `ItemDefinition`
- `RecipeDefinition`
- `WeaponDefinition`
- `MovesetDefinition`
- `AttackDefinition`
- `ElementDefinition`
- `NPCDefinition`
- `RelationshipRuleDefinition`
- `StructureDefinition`
- `CropDefinition`
- `BiomeDefinition`
- `PropSpawnDefinition`
- `MineBiomeDefinition`

Runtime instances reference stable IDs and versioned definitions where persistence requires it.

## Signals/events

Use explicit domain events for cross-system communication. Avoid creating a global signal soup where every system knows every other system.

Examples of useful domain boundaries:

- terrain change -> foliage/prop local invalidation;
- structure change -> support graph recompute + navigation invalidation;
- inventory change -> affected craft queue feasibility recalculation;
- appearance/equipment change -> LPC composition cache invalidation;
- world state change -> save delta registration.

## Determinism/persistence

World generation is seed-driven. Save files store the seed plus mutations/persistent state instead of serializing every visual Node.

Persistent IDs must survive scene unloads and content migrations. LPC/community appearances, structures, terrain edits and generated world props must not rely on transient Node instance IDs.

## Focused specs

- `docs/architecture/WORLD_STREAMING.md`
- `docs/architecture/LPC_PIPELINE.md`
- `docs/design/PLAYER_LPC_AND_3D_PRESENTATION.md`
- `docs/design/BUILDING_AND_STRUCTURAL_SUPPORT.md`
- `docs/design/INVENTORY_AND_CRAFTING.md`
- `docs/design/OPEN_DESIGN_CHECKLIST.md`
