# ADR-0008 — Inventory metadata, active spoilage and atomic publications

Status: C02-A implemented; UX/crafting follow in C02-B/C.

The existing InventoryState / stack UID / revision / InventoryTransactions boundary is preserved. InventoryPlan owns detached copies. Commit checks all participant revisions/identities and duplicate stack ownership before adopting every store. Prepared publications can atomically add a world bag or advance a future craft queue before any observer signal. Preflight is pure, apply is infallible/main-thread, notifications happen after all truth is committed. Save coordinators reject reentrant snapshots during a transaction.

StackPolicy centralizes compatibility and freshness. Other metadata must match; spoilage timers do not prevent merging. Destination freshness owns transferred units; the remainder keeps its original timer. Splits copy source freshness. Half splits floor the child's quantity (11→6+5). Split All makes singletons in available slots, leaving at least one unit in the original stack. Move/swap keep stable UIDs and hotbar/equipment references. Full transfer to a new stack preserves UID; merged source identities retire. Empty slots remain stable; explicit compact is blocked during a drag.

GameplayTimeSource advances only active simulation time. One InventorySimulation schedules inventories by their next deadline; no Node per stack and no full inventory scan every frame. SpoilageDefinition data lives in ItemDefinition.spoilage. Each expiration consumes one unit, emits one data-driven result, then restarts the remaining stack cycle. Bounded overdue processing preserves accrued active-time debt in snapshots rather than adding offline wall time.

Inventory snapshot schema2 explicitly accepts/migrates schema1 (missing pending outputs→empty; missing perishable metadata→fresh on adoption). Runtime anchors are not serialized; remaining seconds, stack metadata, UIDs and revisions persist. Unknown future schemas reject. PlayerProfile/WorldSave schema2 ownership remains unchanged. A perishable world container is marked dirty at checkpoint so its partially elapsed cycle is not omitted by regional dirty persistence.

Full outputs first enter compatible slots, then persistent PendingInventoryOutput stacks owned by the same inventory. With world context, WorldDropService prepares an unpublished bag and moves pending ownership in one transaction. No world mesh is created in domain code. No output is deleted when context/capacity is unavailable. Container transfers/collapse include pending outputs as well as visible slots.
