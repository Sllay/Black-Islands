# ADR-0010 — World time, weather and container presentation

Status: accepted for S01-RC0-R3 C04.

## Decision

WorldClock and WorldWeather are RefCounted domain authorities, composed by
WorldCore. WeatherPresentation reads their state; it cannot choose weather,
advance the calendar or mutate water buffers. CLEAR, RAIN and THUNDERSTORM
definitions belong to a versioned catalog. Rendering quality changes only
presentation budgets.

Active gameplay time remains the clock for inventory spoilage. World time is
scaled, pausable and world-owned. Neither clock consumes offline wall time.
WorldClock caps catch-up per tick and saves outstanding debt. Time notifications
are coarse; calendar boundary and weather events are emitted when they change.

The existing WorldSave root schema remains 2. Its additive
`global.flags.world_core` schema 1 contains clock, weather, exact RNG state and
rain debt. Legacy elapsed seconds initialize missing state deterministically.
Future or foreign-world snapshots reject safely. PlayerProfile never owns world
weather or calendar. Snapshot construction occurs on save, not every frame.

Rain feeds public FarmSystem and WorldWater interfaces around the active player,
with radius, cell and contribution limits. It neither allocates ocean grids nor
updates distant cells. Lightning is a bounded semantic event and reusable visual
flash; fire, environmental damage and final audio remain future consumers.

ContainerService owns accepted open sessions. Sessions are transient; Chest lid
presentation follows service events, never the original UI click. LooseItemDrop,
WorldDropBag, DeathBagInventory and Chest share existing inventory transactions
but have distinct replaceable visual profiles. Idle containers do not process
every frame.

Death/chest publication stages ownership transfer and destination in one
InventoryPlan. World-owned event tombstones make retries idempotent even after a
bag is looted and removed. Stack IDs, revisions and perishability metadata remain
the inventory domain's authority. Closing/retiring a container invalidates its
session and spatial index entry.

InteractionCrosshair consumes the existing targeter's feedback and camera
`aim_screen`; it performs no second raycast and ignores pointer input. Building
feedback uses a non-publishing preview of existing placement/payment rules.

## Consequences

Clock/weather are testable without scene nodes, while rendering and container
adapters stay replaceable for Season 2. Local rain is intentionally an active
region approximation, not global climate simulation. Existing atomic documents,
regional dirty saves and buffered voxel writes remain intact. Optional native
platforms still require device/export validation; desktop proxy measurements do
not establish mobile performance.
