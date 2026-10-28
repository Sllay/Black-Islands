# Codex Prompt — S01-P02 World Foundation

You are implementing Season 1 Part 2 of Black Island. Follow `AGENTS.md` exactly. Start only from a validated P01 state where the real project boots and enters Main.

## Read in this order
1. `AGENTS.md`
2. `harness/context/S01-P02.md`
3. `harness/build/S01-P01.md`
4. `docs/architecture/VOXEL_WORLD_IMPLEMENTATION.md`
5. `docs/architecture/WORLD_STREAMING.md`
6. `docs/architecture/WATER_AND_HYDROLOGY.md`
7. `docs/design/BIOMES_AND_PROP_GENERATION.md`
8. `docs/architecture/SAVE_AND_MIGRATION.md`
9. `docs/decisions/ADR-0004-smooth-voxel-world-and-build-grid.md`
10. `research/VOXEL_TOOLS_INTEGRATION.md`

Read only implementation files relevant to this phase after that.

## Goal
Build the first real generated Black Island world using smooth volumetric voxel terrain, streaming and deterministic save identity. The phase ends with a navigable, persistent island prototype running through the production Main flow, not a disconnected tech demo.

Before world work, perform the small P01.1 mobile-HUD correction below. This is a bounded polish gate, not a new phase and not permission to delay world implementation.

# P01.1 — Mobile HUD correction gate

The P01 shell is functionally valid but its temporary controls must be replaced with the intended mobile layout before the world prototype is built around them.

## Native movement joystick

Replace the temporary four-arrow movement grid with Godot 4.7's native `VirtualJoystick` Control node.

Requirements:
- use the engine-native `VirtualJoystick`; do not keep a hand-written D-pad and do not add a third-party joystick addon;
- bind it directly to the existing semantic `move_up`, `move_down`, `move_left`, `move_right` InputMap actions;
- keep gameplay movement consumers independent from the on-screen widget by using normal Input/InputMap actions;
- place it bottom-left inside the existing safe-area layout;
- use a mobile-appropriate circular footprint and thumb/tip size; style can remain simple placeholder art;
- choose fixed/following/dynamic behavior based on the native node's behavior after a quick runtime check, preferring the mode that feels predictable for an action game;
- preserve keyboard/gamepad development bindings;
- verify simultaneous joystick + action-button input in the available runtime. Physical multitouch remains a device gate if unavailable.

## Action cluster

Replace rectangular `Interagir`, `Esquivar`, `Contexto`, `Atacar` controls with circular mobile action buttons.

Visual/interaction hierarchy:
- `attack_primary` is the largest button and the bottom-right anchor of the cluster;
- `interact`, `dodge` and contextual action are slightly smaller and surround the attack button in a curved/arc arrangement rather than a rectangular 2x2 grid;
- keep the whole cluster inside the safe area and with comfortable thumb spacing;
- attack should remain closest to the bottom-right thumb resting position;
- the smaller actions should be reachable without crossing over the attack button;
- use icon-only placeholders for now. Emoji in a centered `Label`/button text is explicitly acceptable at this stage.

Placeholder icon mapping:
- Attack: `⚔️`
- Dodge: `💨`
- Interact: `💬`
- Context: `✦` or another simple neutral context glyph if the current font cannot render it reliably.

The contextual button must remain present in the layout so the cluster does not jump around, but may be dimmed/disabled when there is no contextual action.

Use Godot-native UI/touch controls. Avoid a custom touch-ID dispatcher unless an engine bug is proven and documented. Confirm that the chosen 4.7 button path allows the intended simultaneous touches in the available runtime.

## Resource bars

Refine the top-left Health/Stamina/Mana presentation:
- remove visible text titles (`VIDA`, `VIGOR`, `MANA`);
- preserve the descending/staircase width hierarchy: Health largest, Stamina shorter, Mana shortest;
- place a small icon at the beginning of each row/bar;
- placeholder emoji are accepted:
  - Health: `❤️`
  - Stamina: `⚡️`
  - Mana: `🔮`
- show the current value as a centered percentage inside each bar, e.g. `100%`, instead of `100 / 100`;
- percentage text should use a darker variant of the bar's own color, with enough contrast to remain readable;
- UI remains presentation only; do not create the final stats authority in P02.

The desired conceptual layout is:

```text
❤️ [=========== 100% ===========]
⚡️ [========= 100% =========]
🔮 [======= 100% =======]

                                  💬
                              💨       ✦
                                   ⚔️
```

Exact pixel coordinates are not authoritative. Use anchors/containers or a small dedicated responsive cluster control so it survives both P01 tested landscape aspect ratios.

## P01.1 validation

Before starting voxel implementation:
- run the real Main/HUD;
- capture 1280x720 and wide-landscape screenshots;
- verify native `VirtualJoystick` appears and drives the existing movement actions;
- verify action buttons remain inside safe area and do not overlap hotbar;
- verify P01 save flow and smoke tests still pass;
- keep this correction as a small first checkpoint on the P02 branch.

Do not redesign SaveSelect, Boot or inventory shell during this polish gate.

## Fixed world architecture
- terrain voxel target: 0.5 m;
- BuildCell: 1.0 m;
- project WorldChunk address space: 64 x 64 x 64 m;
- vertical chunks exist;
- near horizontal streaming baseline: 3x3 WorldChunk ring around the active area;
- WorldChunk is not required to equal one monolithic mesh/collision block;
- smooth volumetric surface, not visible Minecraft cubes;
- deterministic surface island generated once per save;
- save seed + mutations/deltas, not generated mesh/collision caches;
- BuildGrid is separate from terrain authority.

## Implementation priorities
### 1. Integrate the selected smooth-voxel path
Use the P00 pinned Voxel Tools GDExtension 1.7/v1.7x route. Wrap dependency use behind Black Island-owned world interfaces/services. Do not let gameplay code depend directly on arbitrary addon internals.

Prove:
- smooth terrain generation;
- runtime local density/material edit;
- collision update;
- chunk boundary continuity;
- vertical chunk addressing.

The P00 standalone `build_transition_mesh()` helper reproduction is a known failing diagnostic and is not itself the shipping seam API. Do not spend P01.1 trying to fix it. In P02, rendered LOD/chunk seams are a real gate: test the actual terrain path and document any issue with a minimal reproducer.

If the dependency cannot satisfy the phase on the current platform/toolchain, document the blocker and produce the smallest evidence-driven fallback/prototype; do not secretly replace the project with a custom voxel engine.

### 2. World coordinate model
Implement explicit conversion utilities for:
- world position <-> voxel coordinate;
- world position <-> WorldChunk coordinate;
- world/voxel <-> 1 m BuildGrid coordinate.

These functions must be deterministic and tested at positive/negative coordinates and boundaries.

### 3. Streaming
Implement first streaming controller with:
- 3x3 horizontal near ring;
- vertical chunks loaded only where data/surface/player needs them;
- asynchronous/background-safe generation/data preparation where supported;
- SceneTree/resource application on the main thread where required;
- unload without losing authoritative persistent state;
- hysteresis/debounce so crossing a boundary does not thrash load/unload.

Track profiling counters in debug UI: loaded chunks, pending jobs, mesh rebuilds, collision rebuilds, memory estimates if available.

### 4. Deterministic island baseline
Generate a medium island profile sufficient to validate the architecture:
- surrounding beach/coast;
- tropical plains;
- gentle elevation/hills;
- central/denser forest mask/region data;
- ocean surrounding island;
- village/spawn candidate area kept reasonably buildable;
- seed deterministic.

Do not chase final beauty/content density in this phase. Shape must be recognizably island-like and navigable.

### 5. Material foundation
Prove discrete logical materials with smooth presentation/blending where practical, including at least:
- sand/beach;
- grass;
- dirt/stone representative material.

Implement a local material paint test operation that changes only the intended logical voxel/surface region and rebuilds only affected mesh region/neighbors.

Do not implement FarmPlot yet.

### 6. BuildGrid foundation
Implement coordinate/occupancy foundation only:
- 1 m integer cell coordinates;
- shared-edge representation seam for future walls;
- world-to-cell debug highlight;
- no full building catalog/support solver yet.

### 7. Save/persistence
On save creation:
- generate/store world seed and generation version;
- surface generation is considered established for that save;
- reloading the same save reproduces the same base island;
- record at least one local terrain/material mutation as a delta and prove it survives reload;
- never serialize generated mesh/collision buffers as world truth.

### 8. Water/ocean baseline
Do not attempt full dynamic Family-Time-like hydrology yet.
Prove:
- ocean visual/interaction boundary around island;
- generated basic lake/river/water-body hook if generator produces one;
- architecture seam for future `WaterGrid` simulation;
- near/far ocean representation can use different quality paths.

### 9. World boundary/horizon
Prototype:
- distant ocean beyond playable island;
- hard fail-safe boundary far outside normal play;
- soft illusion/treadmill boundary hook without trapping normal traversal;
- optional distant decorative land silhouette if very cheap.

Do not spend phase time polishing this beyond proof.

## Performance requirements
This is a measurement phase. Record actual timings/memory where tools allow:
- initial world generation;
- chunk load/unload;
- local remesh after edit;
- collision update latency;
- loaded chunk count;
- frame-time impact while crossing chunk borders.

Do not claim mobile performance from desktop-only numbers. If physical mobile export is unavailable, clearly mark the result `desktop proxy only`.

## Out of scope
- final water simulation;
- player LPC/combat/inventory;
- final props/foliage ecology;
- farming;
- NPCs/mobs;
- caves;
- final building system.

Use a temporary debug pawn/camera only if necessary to inspect the world; P03 will implement the real player.

## Required tests
- P01.1 HUD screenshots and native joystick/action input smoke;
- P01 save flow regression;
- same seed -> same sampled terrain/material values;
- different seed -> meaningfully different island;
- voxel/chunk/build-grid coordinate boundary tests;
- edit at chunk border updates both required sides without seam;
- unload/reload preserves saved terrain delta;
- crossing chunk borders does not duplicate/loss world state;
- vertical chunk coordinate/load proof;
- project still boots through P01 production flow.

## Checkpoints
P01.1: bounded HUD correction — native `VirtualJoystick`, curved circular action cluster, compact resource bars.
C01: dependency integration + smooth voxel proof + coordinate tests.
C02: deterministic island + 3x3/vertical streaming + material paint.
C03: save delta + BuildGrid foundation + ocean/boundary + profiling/handoff.

Commit/push P01.1 before beginning the large voxel changes so it remains independently recoverable.

## Done when
The corrected mobile HUD is in place and a real save enters a generated, smooth, navigable island through Main; chunks stream; one terrain/material edit persists; BuildGrid coordinates work; performance evidence exists; no later gameplay system is faked as complete.

## Final handoff
Return branch + SHA/checkpoints, P01.1 screenshots/input result, exact voxel dependency/version used, playable path, generated-world seed used for validation, tests, profiling numbers with platform label, files changed, unresolved performance risks, and exact task for S01-P03.