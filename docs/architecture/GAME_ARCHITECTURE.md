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
- World surface and world-cell grid
- Streaming/persistence
- Player/camera/input
- Inventory/items/equipment
- Combat/elements/status effects
- Crafting
- Farming
- Modular construction
- NPC jobs/skills/schedules/relationships/memory
- Dialogue/social events
- Mines
- Progression/skill tree
- UI/UX
- Optional networking
- Optional external AI providers

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
- `MineBiomeDefinition`

Runtime instances reference stable IDs and versioned definitions where persistence requires it.

## Signals/events

Use explicit domain events for cross-system communication. Avoid creating a global signal soup where every system knows every other system.

## Determinism/persistence

World generation is seed-driven. Save files store the seed plus mutations/persistent state instead of serializing every visual Node.
