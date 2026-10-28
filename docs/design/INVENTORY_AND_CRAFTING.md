# Inventory & Crafting — Design/Technical Spec

Status: Accepted core direction.

## Inventory model

Black Island uses slot/stack inventories inspired by survival games, without carry weight.

### Player starting capacity

- 20 inventory slots total;
- interpret the intended layout as **5 columns x 4 rows = 20 slots**;
- capacity can later grow through progression, missions and backpack/container systems.

The 5x4 interpretation is intentional because 20 total slots and 4 rows cannot simultaneously mean 20 columns.

### Hotbar

- 8 slots;
- hotbar is an assignment/view over player-owned inventory stacks, not a second inventory economy;
- only eligible categories may be assigned: weapons, tools, consumables/food, build/placement items and other explicitly hotbar-usable definitions;
- selecting a weapon/tool/build item makes it the active equipped/usable item.

### Equipment

Initial semantic equipment slots:

- helmet;
- chest/torso armor;
- legs/pants armor;
- accessory 1;
- accessory 2.

Weapons are selected through the hotbar rather than a permanent weapon equipment slot.

## Stack limits

Initial defaults:

- common resources: 256;
- consumables/food: 32;
- tools: 1;
- weapons: 1;
- armor: 1;
- accessories: 1;
- crafted construction pieces: 12;
- projectile/ammunition-style stack: 999;
- special definitions may override these values.

Currency is not stored as physical inventory stacks. It belongs to a wallet/currency state and is shown near the player's primary status UI.

## Normal inventory screen

Inventory opens as a fullscreen/near-fullscreen interaction surface while core status bars remain visible.

Normal mode:

- crafting/recipes on the **left**;
- player inventory on the **right**;
- equipment slots sit adjacent to the player inventory;
- bottom gameplay hotbar remains represented/accessible according to final responsive layout.

### Recipe grid

- 5 recipe columns horizontally;
- vertical row count is content-driven and scrollable;
- scrolling snaps cleanly to rows/cards where practical;
- selected recipe opens a dynamic detail/quantity panel.

### Craft queue

- five visible queue slots horizontally at the top of crafting;
- entries remain contiguous;
- only queue slot 1 advances its current unit timer.

## Container mode

Opening a chest/container turns the inventory into a dual-inventory interaction.

Recommended adaptive layout:

- player inventory on one pane;
- opened container inventory on the other pane;
- contextual tabs allow switching the non-player pane between relevant surfaces such as `Craft` and `Container` without closing the interaction.

Exact left/right placement may flip from normal inventory mode if that produces clearer mobile drag direction; ownership labels and visual language must make the active source/destination unambiguous.

## Stack transfer UX

### Direct full-stack transfer

Double-tapping/double-clicking a stack transfers as much of that stack as possible to the opposite active inventory using automatic stacking/free-slot placement.

### Drag transfer

Dragging a stack between inventories opens a quantity popup when partial transfer is meaningful.

Popup:

- slider from 1 to 100% of available quantity;
- numeric quantity display/input;
- explicit Cancel;
- explicit Confirm.

If the user enters a value greater than the current stack quantity, clamp to the available quantity; never underflow/duplicate.

## Stable stack identity

Runtime stack records should have stable transaction identity while loaded:

```text
InventoryStack
- stack_uid
- item_id
- quantity
- instance_data optional
- revision
```

Items that cannot stack because of durability/unique metadata remain individual instances.

## Inventory ownership and revisions

Every mutable inventory/container has:

```text
inventory_id
owner/scope metadata
revision
slots
```

Every successful mutation increments its revision.

UI never owns authoritative item counts.

## InventoryTransactionCoordinator

All inventory-changing operations go through one authoritative transaction service, including:

- drag/drop;
- quick transfer;
- split/merge;
- crafting payment;
- crafting output insertion;
- corpse/container looting;
- world-drop pickup;
- equipment changes that move stacks;
- future multiplayer/tribe actions.

No UI callback directly decrements one Array and increments another.

## Atomic multi-inventory transaction

For any operation touching multiple stores:

1. resolve all participating inventories;
2. capture their current revisions;
3. compute an immutable transaction plan;
4. validate ownership/access, capacity and exact quantities;
5. acquire/logically serialize the affected inventory mutations in stable inventory-ID order;
6. re-check revisions/counts;
7. apply all removals/additions as one domain commit;
8. increment revisions;
9. emit one post-commit change set;
10. if validation fails, apply nothing.

Single-player still uses this architecture even though most commands execute on the main thread. It eliminates ordering glitches today and becomes the foundation for future authoritative multiplayer.

## Command serialization

Inventory mutations are processed through a deterministic command queue/transaction boundary.

If the player drags stone into a chest on the same frame that crafting finishes, one command commits first. The second sees the new revisions/counts and must revalidate.

There is no state where both operations can successfully spend the same stone snapshot.

## Craft resource scopes

Crafting consumes from an explicit `InventoryScope`, never from arbitrary world containers.

Possible scopes:

### Personal crafting

- player inventory only;
- plus an explicitly opened chest if the current UI/context rule allows it.

### Workstation crafting

A workstation may include:

- player inventory;
- workstation internal inventory if it has one;
- authorized nearby chests within the workstation's configured logistics radius;
- tribe/future ownership permissions.

Nearby chest discovery produces a deterministic ordered list of inventory IDs. Ingredients are aggregated across that scope.

The scope is recomputed/validated at transaction time; a chest leaving range or changing owner cannot remain an invisible ingredient source.

## Ingredient aggregation

UI shows total available amounts across the current craft scope:

`Stone 380 / 512`

It does not expose stack fragmentation as a crafting concern.

The transaction planner chooses exact source stacks deterministically, e.g. partially filled stacks/low slot index/inventory-ID order according to one documented policy.

## Queue representation

Conceptual `CraftQueueEntry`:

```text
entry_id
recipe_id
original_requested
active_remaining
unit_duration
queue_order
state
```

`elapsed_time` is runtime-only and is intentionally not persisted across save/load.

### Per-unit timing

`10 foundations` means:

`timer -> attempt craft one -> reset timer -> attempt craft one -> ...`

The timer itself never consumes ingredients or creates output.

## Unit craft transaction

At timer completion:

`timer_ready -> CraftService.request_unit(entry) -> resolve craft scope -> build transaction -> revalidate -> atomically consume ingredients -> construct output -> insert output -> commit -> decrement queue -> next timer`

The timer is only a scheduler/trigger.

## Output routing

After ingredients are successfully consumed, the crafted output must be preserved.

Insertion priority depends on context.

### Personal craft

1. player inventory;
2. current explicitly opened/authorized container if configured;
3. world drop bag near player.

### Workstation craft

1. player inventory where recipe/context allows;
2. active workstation/output container;
3. eligible nearby authorized container(s) according to deterministic output policy;
4. world drop bag near workstation/player.

Never delete a paid output because all inventories became full.

## Shared-resource queue behavior

Queue entries do not reserve all resources in advance.

Example:

- 10 Foundations queued;
- 10 Ceilings queued;
- both consume the same stone;
- player currently has enough for only 10 total units.

Each completed Foundation consumes real stone. Later Ceiling feasibility shrinks immediately against actual remaining resources.

If an entry reaches zero feasible units, remove/cancel its impossible remaining quantity according to the queue rule.

## Resource-return policy — locked

A queue quantity that was clamped downward because resources were consumed/removed does **not automatically regrow** when new resources later appear.

Example:

`Ceilings requested 10 -> clamped to 4 -> player later finds stone`

The entry remains at 4. The player may explicitly queue more.

Why:

- predictable UI;
- prevents "ghost jobs" reappearing after the user believes they were removed;
- makes save/load deterministic;
- simplifies multi-container scope changes;
- avoids queue quantities oscillating as nearby chests enter/leave station range.

`original_requested` may remain for telemetry/UI history, but only `active_remaining` is authoritative for future units.

## Cancellation

Selecting a queue entry exposes a remove/trash action.

Cancelling:

- removes unfinished requested units;
- shifts later entries forward;
- never refunds completed units;
- does not refund the currently ticking unit because no ingredients have been consumed yet.

## Queue reorder — locked safety behavior

When queue order changes:

- stop the current timer;
- reorder entries contiguously;
- recompute feasibility against current scope;
- restart the new slot-1 unit timer from full duration.

If the previously active entry remains slot 1 without changing order, its timer may continue.

Resetting on active-entry reorder avoids timing exploits and ambiguous partially-paid work; no ingredients are lost because payment happens only at completion.

## Save/load behavior — locked

Persist:

- ordered queue entry IDs;
- recipe IDs;
- `active_remaining` quantities;
- other required semantic state.

Do **not** persist the partially elapsed unit timer.

On save/load/crash recovery:

- restore queue;
- revalidate recipes/resources;
- slot 1 restarts one full unit timer.

This deliberately favors safety/predictability over preserving a few seconds of progress.

## Recipe migration

Queue serialization stores stable recipe IDs and schema version.

On load after a game update:

- resolve recipe migration/alias;
- if recipe no longer exists or is invalid, safely remove the queue entry without consuming resources;
- never attempt to craft using stale serialized ingredient arrays.

## Workbench/station tabs

Interacting with a workbench opens inventory context with tabs such as:

- Personal Craft;
- Workbench Craft;
- connected/nearby container context where useful.

Workbench recipes remain separate data definitions/unlock categories rather than hard-coded UI lists.

## Nearby chest integration

A workstation can use chests in a configured logistics radius if:

- chest is currently valid/alive;
- ownership/tribe policy permits access;
- chest is in the same world/loaded logistics domain;
- it is not locked/reserved by another authoritative action;
- inventory revision validates at craft commit.

The workstation may aggregate many nearby chests, but the transaction uses exact source inventory IDs/stacks.

## Future tribe ownership

Inventory and structures should use an ownership abstraction from the start:

```text
OwnerScope
- PLAYER
- TRIBE
- WORLD/SYSTEM
```

Chapter 1 can resolve most structures to the local player/village, while future multiplayer may make chest/structure ownership tribe-authoritative without rewriting item transactions.

## Transaction invariants

1. Output cannot exist before successful payment.
2. Payment is atomic across all ingredient source inventories.
3. Failed validation consumes nothing and creates nothing.
4. UI is never authoritative inventory state.
5. Every mutation increments revisions.
6. Transfer and craft cannot spend the same stale stack state.
7. Full inventories redirect paid output; they never delete it.
8. Queue timer is not payment.
9. Save/load restarts active timer; it does not duplicate a half-completed unit.
10. Future multiplayer server/host owns transaction commits.

## Data-driven definitions

`ItemDefinition` owns stack/category/eligibility data.

`RecipeDefinition` owns:

- stable ID;
- outputs;
- ingredient requirements;
- unit duration;
- unlock/visibility rules;
- station requirements;
- tags/categories.

UI renders these definitions; it does not encode recipes.
