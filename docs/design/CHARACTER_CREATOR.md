# Character Creator — Design/Technical Spec

Status: Accepted UX direction; final visual styling remains tunable.

## Goals

Use the full validated LPC catalog without forcing the player through an unusable text list.

The creator must support:

- player creation at save start;
- recruited NPC customization;
- randomization;
- body/face/hair/clothing/accessory categories;
- semantic LPC recolor channels;
- compatibility filtering by body/catalog state;
- future community appearance pool integration.

## Screen layout

### Left side

- large live character preview;
- character name field above preview;
- Randomize button below preview;
- optional rotate/direction preview controls where helpful;
- preview can cycle LPC facing/action for validation but defaults to readable idle.

### Right side

A vertically scrollable category-tab rail.

Selecting a tab opens a content grid immediately beside the rail.

Examples of generated tabs/categories may include:

- body/base;
- skin/body color;
- head/face;
- eyes;
- eyebrows;
- nose;
- mouth/expression base where appropriate;
- ears;
- hair;
- facial hair;
- torso clothing;
- leg clothing;
- shoes;
- headwear;
- accessories;
- other LPC catalog categories that pass Black Island compatibility/policy.

Do not hard-code the UI to only this list. The catalog importer maps upstream categories into stable Black Island creator groups.

## Asset grid

Selected category shows a grid of visual thumbnails/previews.

Each tile represents a compatible catalog selection rather than a raw file path.

Rules:

- virtualize/lazy-load thumbnails for large categories;
- do not instantiate/render hundreds of full animated previews simultaneously;
- selected tile is obvious;
- unsupported/quarantined assets are absent or explicitly unavailable according to policy;
- body compatibility updates the visible grid immediately.

## Palette mode

If the active selection/category has recolor channels, show a Palette button/icon in the contextual controls.

Tapping it switches the content grid from asset choices to valid semantic color/palette choices for the active recolor channel.

Tapping again/back returns to the asset grid.

For multi-channel LPC assets, expose channels such as:

- main cloth;
- trim;
- hair tie;
- metal;
- wood handle;
- eyes;
- body/skin;
- other compiled channel labels.

The UI reads channel metadata from `LPCCatalog`; it does not assume every item has one color.

## Body-color propagation

Selections marked with compiled `matchBodyColor` behavior automatically follow body/skin tone where appropriate.

Changing body color re-resolves compatible head/ear/face/body-color-linked layers without overwriting unrelated hair/clothing colors.

## Preview composition

Creator uses the same `LPCComposer`/compatibility rules as runtime.

There must not be a separate fake creator rendering path that allows combinations the game cannot display.

Preview changes can use a high-priority temporary composition cache; repeated option browsing should not permanently retain every preview texture in the gameplay cache.

## Name

Player/NPC name is separate from appearance.

Initial NPC name source is local procedural/preset generation. Community appearance sharing should not require sharing player-written NPC names.

Name validation can restrict unsupported/control characters and apply length limits.

## Randomize

Randomize uses `LPCAppearanceResolver` with light curation.

Strict filters primarily prevent broken combinations:

- invalid body type;
- missing required layer;
- incompatible dependency;
- blocked/quarantined license/content;
- impossible mandatory animation support where relevant.

After those checks, unusual color/style combinations are allowed. The randomizer should remain genuinely random rather than selecting from hundreds of handcrafted fashion presets.

## Randomization categories

Randomization may expose later options such as:

- Full Random;
- Appearance Only;
- Clothing Only;
- Colors Only.

Chapter 1 only requires Full Random if time is tight.

## Recruit customization

When the player recruits/brings an eligible NPC into the village, customization may open through the same creator framework.

The NPC arrives with either:

- locally randomized appearance;
- compatible cached community appearance where online feature is enabled later.

Player can keep it or customize it.

NPC identity/gameplay traits are not erased by changing appearance.

## Wardrobe after creation

Later wardrobe interaction reuses category/palette UI for clothing/accessories only.

Wardrobe cannot freely rewrite immutable/identity appearance categories unless another game system allows it.

Unlock rules can hide/lock event/quest/special clothing.

## Community appearance eligibility

Future shared appearance upload stores compact selections/recolors, never rendered PNGs.

Before uploading, a customization-distance/eligibility score can require meaningful changes from the initial/random baseline so trivial untouched generations do not flood the pool.

Normalized appearance hash prevents duplicates.

## Performance

- thumbnail atlas/cache with hard memory limit;
- virtualized grid;
- async/background-safe image/data preparation where possible;
- only main-thread/GPU resource creation where required by Godot;
- debounce rapid option changes before expensive full composition if needed;
- creator cache separated from long-lived NPC texture cache.

## Required tests

- every visible tile resolves to a technically/legal compatible asset;
- changing body type removes/falls back incompatible clothing safely;
- multi-channel item can recolor channels independently;
- body-color-linked layers follow skin change;
- randomize never creates missing mandatory body/layer state;
- repeated rapid browsing does not leak textures indefinitely;
- recruited NPC creator changes only appearance/name fields intended by design;
- saved appearance survives LPC catalog alias migration.
