# Codex kickoff — S01-RC0-R1

Continue Black Island from the current S01-P04 foundation, but do **not** start Season 2 and do **not** start RC0-R2.

Before editing code:

1. Fetch the repository and inspect `chatgpt/s01-rc0-planning`.
2. Read in full:
   - `harness/context/S01-RC0-R1.md`
   - `harness/context/S01-RC0-R2.md` only to understand the boundary and avoid implementing R2 early
   - `docs/decisions/ADR-0004-rc0-platform-world-persistence.md`
   - existing AGENTS/GOALS/PLANS and the P00–P04 build logs only as needed
3. Create branch `codex/s01-rc0-r1-foundation-corrections` from `chatgpt/s01-rc0-planning`.
4. Preserve Godot 4.7.2, Godot MCP, Serena and Voxel Tools 1.7/v1.7x.
5. Integrate/pin LimboAI v1.8.1 for the Godot 4.7.2 baseline; verify the exact artifact used and record its SHA-256/version. Do not introduce unpinned downloads.

Implement **S01-RC0-R1 only**, in three checkpoints:

### C01 — production shell / options / world and player selection

Establish the real flow:

`MainMenu → Worlds(max 5) → Player Profiles(max 5) → Gameplay`

Main menu: Play, Multiplayer visible but disabled, Options, Quit.

Options is a full screen with tabs Audio / Graphics / Other(disabled), persistent Cancel and Save & Exit.

Audio buses: Music, Audio, Voice; sliders integer 0–100. Persist settings and use correct linear↔dB/mute behavior.

Graphics UI: Low / Medium / High exclusive buttons, render-distance quality level 2–10 default 6, Shadows toggle, VSync toggle. Keep renderer backend separate from quality preset. Backends are Forward+ desktop, Mobile, Compatibility; do not pretend they can be hot-switched safely at runtime. Expensive settings are staged and applied only on Save & Exit / safe lifecycle boundary.

World cards: fixed compressed no-HUD thumbnail, name, difficulty, accumulated real play time, world-day count, Delete/Edit/Play. Empty: `Vazio` + `Clique para criar o mundo`. Five slots.

World create: generated `Mundo_###`, generated/editable seed, LineEdits select generated text on focus, Normal selected/enabled, Difficult/Extreme visible disabled. Create metadata only; do not generate full world yet. Editing generated world locks seed.

Player cards: appearance preview, name, level, play time, Delete/Edit/Play. Five slots. Player identity must be portable and not owned by a world file.

Build an LPC catalog-driven character customization shell. Creation exposes compatible body/skin/ears/face/eyes/hair/cosmetic clothing/accessories available in the pinned catalog. Pregnancy is not a creation choice. Existing-character Edit is cosmetic-focused; immutable/body traits are not freely rewritten after creation.

Checkpoint: targeted tests + one MCP runtime proof + changed-script LSP diagnostics + commit/push. Do not run the whole historical suite.

### C02 — visual/player/camera/collision/building corrections

Fix LPC Sprite3D so it is upright, feet-anchored and yaw-billboarded only; it must never pitch/lie on the terrain.

Provide two ordinary gameplay camera modes: corrected angled 2.5D overview and third-person/shoulder. Third-person is always usable; building requires/enters the precise third-person mode rather than owning that camera exclusively.

Refactor collision layers so interaction targets are not automatically physical blockers. FarmPlot/loot bags must not block the player. Keep separate physical blocker and interaction/query concepts for chests/structures.

Remove permanent production tutorial text and permanent mob HP/name Label3D clutter. The context action button is enabled by real semantic available actions, not merely by a ray hitting something.

Correct building dimensions: foundation ~2m×2m (2×2 current logical cells), visibly thicker than ceiling; walls/ceilings derive from corrected module size; pillar remains coherent.

Support is footprint-based: foundations need sufficient terrain support; small partial loss may survive, major support loss collapses; dependent structures update locally. Chests/other placeables lose support appropriately, and a destroyed chest atomically produces one loot container preserving all contents.

Replace tiny prototype structural HP with the agreed monotonic tier order `Thatch → Wood → Stone → Darkstone → Scrap → Iron`, starting Thatch at 5,000 HP and documenting the complete table selected for this run.

Checkpoint: focused tests + one MCP proof + LSP + commit/push.

### C03 — LimboAI / locomotion seam / persistence split

Use LimboAI v1.8.1 BT/HSM for reusable intent/state orchestration. Keep domain truth project-owned. Architecture must remain:

`MobDefinition/MobDomain → LimboAI intent → MobLocomotion/navigation → MobActor presentation/physics`

Create reusable modular states/tasks rather than species controller branches. Separate locomotion/navigation from AI decision logic; do not leave direct `direction.normalized()` chasing as the long-term contract.

Split persistence:

- PlayerProfile: stable character ID, name, appearance, stats/level/progression, inventory/hotbar/equipment, future player-owned unlocks, character play time.
- WorldSave: seed/generation/profile, world clock/day, voxel deltas, structures, farms, containers/world drops, props/regrowth, mobs/NPCs and future world/village flags.

A character must not be locked to one world seed. World session may store per-player last position/session state keyed by player ID, but world data is not nested under player save.

Add explicit versioned migration infrastructure `N → N+1`; unknown future schemas remain safely rejected.

Stop serializing/hash-writing the entire world merely because player state changed. Add dirty-domain/coalesced commits while retaining checksum/temp/rename/journal-style crash safety.

Checkpoint: focused persistence/AI tests + one MCP world/player reopen proof + LSP + commit/push.

### Validation discipline

Do not burn the remaining session on a giant final gate. After each checkpoint, push immediately. Final validation should run only the new RC0-R1 gate plus the minimum regressions for subsystems actually touched. Reuse P00–P04 evidence otherwise. No extended world/foliage performance campaign in R1; that is R2.

Keep `main` preserved. End with:

- branch and exact SHAs for C01/C02/C03
- playable path
- concise PASS/FAIL table
- files/schemas changed
- migration result for old dev saves
- LimboAI artifact/version/hash
- remaining risks
- explicit statement `RC0-R2 NOT STARTED`

If a test exposes a real bug, fix it inside the relevant checkpoint before proceeding; do not hide it by weakening assertions or reducing content.