# S02 — UI/UX Polish + i18n Contract

Status: BACKLOG / NOT STARTED
Purpose: preserve the Season 2 UI/localization decisions made after S01-RC0-R3 C02. This is not a Season 1 Foundation blocker as long as domain behavior remains correct and testable.

## Why this exists
The RC0-R3 C02 inventory/crafting domain is functionally complete, transaction-safe and usable, but its current production presentation is still a foundation UI. Screenshots show rough spacing/composition, including uncovered game area above the fullscreen inventory surface in some layouts. Season 2 must include a dedicated UI/UX polish pass rather than treating those rough edges as final.

## UI/UX polish goals
- Rework the inventory/crafting/container/workbench presentation without changing the domain authority created in C02.
- Inventory should intentionally own the full intended interaction surface; no accidental uncovered strips/gaps around the fullscreen panel.
- Respect safe areas/notches and landscape layouts.
- Validate at minimum 1280x720 and wide mobile-like aspect ratios such as 1920x864, plus real-device validation when available.
- Improve spacing, hierarchy, typography, panels, tabs, modal placement, item details, quantity/split modal, equipment region, recipe list and 5-slot craft queue.
- Keep mobile gestures from C02: tap, double tap, long press, drag/drop and scroll.
- Preserve player/container dual-inventory semantics, hotbar references, spoilage bars, transactional operations and crafting authority.
- Create/finish missing production UI scenes instead of letting large UI surfaces remain monolithic script-built placeholders where reusable scenes/components are appropriate.
- Polish other player-facing screens in the same pass where needed so the game stops mixing polished and foundation-level UI.
- QA/debug controls must remain separate from production presentation.

## i18n / localization foundation
Season 2 UI polish must also perform a systematic extraction/mapping of player-visible text.

### Required rules
- No new player-visible production string should be hardcoded directly into gameplay/UI logic when it can use a translation key.
- Audit existing player-visible strings across menus, saves, options, HUD, inventory, crafting, containers, interaction prompts, build feedback and other production UI.
- Assign stable semantic translation keys rather than using the Portuguese/English source sentence itself as identity.
- Use Godot localization APIs/resources (`tr()` or the appropriate localized resource workflow) at presentation boundaries.
- Keep internal IDs, item IDs, recipe IDs, save schema IDs and gameplay enums language-independent.
- Item/recipe/content definitions should reference localization keys for display names/descriptions where practical.
- Debug/QA-only strings may remain nonlocalized when clearly isolated from production UI.

### Translation catalog structure
Prepare a maintainable catalog split by domain when useful, for example:
- common
- main_menu/options
- saves/worlds/player_profiles
- hud/interactions
- inventory/containers
- crafting
- building/farming
- items/equipment
- dialogue/npc (later content can extend)

Do not require every future language to be authored in this pass; the goal is that the project becomes translation-ready and all current player-visible strings are mapped.

### Language settings seam
- Options should gain a real language selector when localization is activated.
- Persist the chosen locale in user settings, not world/player save state.
- Changing locale should refresh visible UI safely without corrupting domain state.
- Maintain font/fallback compatibility for future accented/Unicode languages.

### Validation
- Add a scan/check for obvious hardcoded production strings in known UI surfaces where practical.
- Add at least one alternate/pseudo locale to expose overflow/truncation assumptions during UI polish.
- Validate long strings, narrow buttons, tabs, modal sizing and safe-area layouts.
- Verify localization does not change save compatibility or gameplay IDs.

## Explicit boundary
This document records Season 2 work only. Do not pull these polish tasks back into S01-RC0-R3 unless a UI defect blocks a Foundation system from being exercised correctly.

Season 1 still proceeds through R3 C03 and C04 before Season 2 begins.
