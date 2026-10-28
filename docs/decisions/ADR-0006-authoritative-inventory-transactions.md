# ADR-0006 — Authoritative Inventory Transactions

Status: Accepted

## Decision

All item ownership mutations in Black Island pass through one authoritative inventory transaction boundary.

UI, crafting timers, corpse views, workbenches and containers may request mutations; they do not directly modify authoritative stacks.

Multi-inventory operations use revision validation and all-or-nothing commit semantics.

## Why

Black Island supports:

- crafting queues;
- player inventory;
- chests;
- workstations consuming nearby chest resources;
- corpse inventories;
- death/drop bags;
- drag transfer while other systems may mutate the same items;
- future authoritative multiplayer/tribe ownership.

Without one transaction layer, these systems create classic duplication/loss race conditions.

## Invariants

1. One stack has one authoritative owner/inventory at a time.
2. Output is never created before payment succeeds.
3. Multi-container ingredient consumption is atomic.
4. Failed validation applies no partial removals/additions.
5. Every inventory has a revision that changes after committed mutation.
6. Craft/transfer commands revalidate stale revisions before commit.
7. UI state is a view, never inventory truth.
8. Future server/host authority can replace the local coordinator without rewriting gameplay semantics.

## Craft timing

Craft timers are scheduling only.

At timer completion, the craft service starts a fresh transaction against current authoritative resource scope.

No queue-wide resource reservation is created when jobs are enqueued.

## Save behavior

Queue semantic state persists; partial active timer progress does not. The current unit restarts on load.

Detailed rules live in `docs/design/INVENTORY_AND_CRAFTING.md`.
