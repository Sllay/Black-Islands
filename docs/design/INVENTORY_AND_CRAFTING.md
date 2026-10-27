# Inventory & Crafting — Design/Technical Spec

Status: Accepted core direction; one queue-restoration edge case remains open.

## Inventory model

Black Island uses a slot/stack inventory inspired by survival-game inventories, without a carry-weight system.

Core rules:

- inventory capacity is limited by slot count;
- items use stacks with per-item stack limits;
- baseline common resource stack target is 256 unless an item overrides it;
- progression, missions or equipped containers/backpacks may increase available slot count;
- hotbar is a view/assignment over usable inventory items, not a separate economy;
- equipment has its own semantic slots where appropriate.

## Inventory UI layout

Current direction:

- crafting panel on the **left**;
- player inventory on the **right**;
- essential health/stamina/mana visibility remains available while inventory is open;
- inventory grid scrolls in snapped full rows rather than showing awkward half rows;
- hotbar remains available at the bottom where the final UX layout permits.

Exact responsive dimensions remain a mobile UX task.

## Craft recipe browser

Crafting recipes are shown as slot/tile entries rather than a long text-only list. Selecting a recipe shows its output, requirements and quantity controls.

Ingredient availability is aggregated by item ID across all inventory stacks. The UI should show totals such as `Stone 380 / 512`, not force the player to reason about which stack contains each unit.

## Queue

The crafting panel has five visible queue slots at the top.

Each `CraftQueueEntry` conceptually stores at least:

```text
recipe_id
requested_remaining
active_remaining
unit_duration
elapsed_time
queue_order
```

Only the first queue entry actively advances its unit timer. Entries remain contiguous; removing an earlier entry shifts later entries forward.

A stack quantity means repeated per-unit craft operations, not one timer that magically creates the entire stack.

Example:

`10 foundations` means:

`timer -> craft 1 -> reset timer -> craft 1 -> ...`

until the entry reaches zero or becomes impossible/cancelled.

## Timer is not the transaction

The timer never directly removes ingredients or creates output.

At unit completion:

`timer completes -> InventoryTransaction.try_craft(recipe) -> revalidate ingredients -> atomically consume -> create output -> insert/drop -> emit inventory changes -> decrement queue unit -> restart timer if remaining`

This protects against duplication caused by UI reorder, resource changes or timing races.

## Output when inventory is full

Once a unit transaction has successfully consumed its ingredients, the output exists.

If inventory insertion cannot fit the result:

`successful craft -> failed inventory insert -> spawn world drop near player`

The queue continues. The game must never delete a paid-for crafted item merely because the inventory filled during the timer.

## Shared-resource queue behavior

Current accepted behavior follows the user's survival-crafting model: queue entries are not full ingredient reservations. Resources are consumed per completed unit.

Example:

- Foundation costs X stone.
- Ceiling costs the same X stone.
- Player owns enough stone for 10 units total.
- Queue contains `10 Foundation` followed by `10 Ceiling`.

When one Foundation completes and consumes X stone, current inventory can now fund only 9 Ceiling units. The Ceiling queue entry is clamped from 10 to 9. As Foundations continue consuming the shared stone, the later Ceiling entry continues shrinking. If no unit remains possible, that queue entry is removed.

Therefore queue quantity represents a request that can be reduced by real resource availability; it is not a promise/reservation of future ingredients.

### Recalculation trigger

Whenever ingredient-relevant inventory state changes, the queue manager recalculates feasibility for affected recipes, including changes caused by:

- an earlier craft consuming resources;
- player dropping/removing resources;
- player receiving resources;
- another system consuming the same resources.

For the behavior explicitly described so far, later entries are clamped against **current real inventory**, not against hypothetical reservations held by earlier queue entries.

## Cancellation

Selecting a queue entry exposes a cancel/remove action.

Cancelling an entry:

- removes its remaining requested crafts from the queue;
- shifts later entries forward;
- does not refund previously completed units because each completed unit already consumed its resources transactionally;
- does not need to refund the currently ticking incomplete unit because ingredients are not consumed until its timer successfully completes.

When slot 1 is removed, slot 2 becomes slot 1 and begins/continues according to active-timer policy.

## Resource loss example

If the player removes/drops the stone required by a queued Ceiling entry before that unit completes, the queue feasibility is recomputed. If zero Ceiling units remain possible, the entry is removed instead of allowing the timer to create an unpaid item.

## Resource addition — open semantic

The conversation established that unavailable queued quantities shrink and may be deleted as resources disappear/are consumed. One detail is intentionally not invented yet:

- if an entry shrank from 10 to 4 and the player later acquires more ingredients before it finishes, should it automatically grow back toward the original requested 10, or remain permanently clamped at 4?

Implementation must preserve enough internal information to support either policy until this is locked. A safe model is to distinguish `original_requested` from `active_remaining`, even if the UI currently shows only active quantity.

## Queue reorder

Queue reordering, if enabled, must operate only on contiguous queue entries and trigger a fresh feasibility calculation. The exact active-unit timer behavior on reorder (reset, pause/resume or preserve progress) remains a UX/balance decision and must be locked before implementation.

## Transaction invariants

1. Output cannot be created before successful ingredient consumption.
2. Ingredients for a unit are consumed atomically.
3. A failed transaction creates no output and consumes nothing.
4. Queue UI cannot be the authority for inventory ownership.
5. Inventory changes immediately invalidate/recalculate dependent queue feasibility.
6. Full inventory after payment produces a world drop rather than item loss.
7. Save/load must not duplicate an in-progress unit; serialized timer/queue state needs an explicit resume rule.

## Data-driven definitions

`RecipeDefinition` should contain stable recipe ID, output(s), ingredient requirements, unit duration, unlock/visibility rules, station requirements where relevant and tags/categories.

Crafting logic resolves definitions by stable IDs; recipe UI does not own crafting rules.
