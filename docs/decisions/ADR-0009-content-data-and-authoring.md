# ADR-0009 — Shared content data, bounded effects and visual adapters

Status: accepted and implemented in S01-RC0-R3 C03.

BlackIslandTools edits the same versioned JSON definitions that runtime services read. The EditorPlugin is an authoring adapter and never a runtime dependency. Existing item/recipe IDs remain stable; save identities are not paths, translated titles or array positions. Renaming an existing ID through the editor is rejected. A shared headless validator checks the complete reference graph before a selected catalog is atomically published. Cached runtime definitions refresh only on an explicit catalog revision.

Item modules contain configuration for reusable services. Effect graphs are bounded allowlisted DAG data, compiled/cached without SceneTree nodes. Content cannot name scripts or execute expressions. Payment/output/stat/domain changes use the existing revision-checked InventoryPlan publication boundary. Status/entity/VFX nodes call reviewed semantic adapter seams rather than instantiate arbitrary classes.

Weapons share reviewed moveset templates. LPC_LAYER reuses accepted upstream assets and compatibility composition. DETACHED_SPRITE uses one reusable yaw-only rig with directional offsets, curves, semantic layer and trail settings; it does not alter character collision or require a full LPC sheet per custom weapon.

Generation-2 prop tables add deterministic versioned placements without changing legacy generation-1 placement. Rarity is a label; weight controls seeded selection. Boulder variants are data, not subclasses. MineralRoot has one domain ID/HP/reserve pool and two presentation parts. Regional batching and near interaction adapters remain separate from persistent domain truth. Normal and critical extraction use actual clamped damage and finite reserves.

Player/world ownership and root save schemas remain unchanged. New spawn-table version flags are additive. Missing content after an update preserves owned item/harvest state as inert diagnostic data; it does not delete assets from saves or grant extraction. Unknown future catalog/table schemas reject safely. Final art, cave generation, arbitrary scripting and full status simulation are outside this decision.

Evidence and executed tests: `harness/build/S01-RC0-R3-C03.md`.
