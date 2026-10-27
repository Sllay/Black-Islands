# LPC Pipeline Architecture

Status: Accepted architecture direction based on study of the current Universal LPC Spritesheet Character Generator repository.

## Purpose

Black Island does not treat Universal LPC as merely a folder of PNG sprites. It consumes LPC as an upstream structured content ecosystem and compiles it into a stable Black Island catalog suitable for Godot/mobile runtime.

The runtime must not depend directly on the LPC web UI implementation.

## Upstream sources of truth

Primary upstream inputs:

- `sheet_definitions/` — item/layer/body/animation/recolor metadata;
- `palette_definitions/` — palette/material metadata;
- `spritesheets/` — source art;
- `CREDITS.csv` plus definition-level credit metadata;
- repository `LICENSE` and per-asset license metadata;
- aliases/metadata generation logic used by the LPC project;
- custom animation definitions;
- README/architecture documentation for compatibility behavior.

`sheet_definitions/` and `palette_definitions/` are treated as semantic sources of truth. File paths alone are not stable asset identity.

## Black Island ingest architecture

```text
Universal LPC upstream snapshot
        ↓
LPCSnapshotFetcher
        ↓
LPCCompiler
├── SheetDefinitionParser
├── PaletteDefinitionParser
├── AliasCompiler
├── PathResolver
├── LayerCompiler
├── AnimationRegistryCompiler
├── CustomAnimationCompiler
├── CreditCompiler
└── LicenseResolver
        ↓
Validation
├── asset existence
├── frame/layout validity
├── body compatibility
├── animation compatibility
├── palette validity
├── dependency/path-template validity
└── license policy
        ↓
Black Island LPC Catalog
```

## Stable identity and migration

Do not use upstream directory path as Black Island's only persistent ID.

Black Island stores stable catalog IDs plus upstream identity/migration data such as:

- source item ID;
- source path(s);
- aliases/renames;
- first-seen upstream commit;
- last-seen upstream commit;
- catalog version.

When LPC moves/renames an asset, old Black Island saves/community appearances must resolve through aliases/migrations rather than silently breaking.

## Verified compatibility matrix

Do not trust an upstream `animations` list as proof that every expected file/layer exists for every body type.

The compiler verifies actual resolved assets and emits compatibility data similar to:

```text
asset_id
  male
    walk: supported
    run: supported
    sit: supported
  pregnant
    walk: supported
    run: missing
  child
    walk: supported
    combat: missing
```

Runtime randomization/customization uses verified compatibility, not optimistic metadata alone.

## Body types

The LPC ecosystem currently includes body variants such as male, female, muscular, pregnant, teen and child. Coverage differs by asset/animation.

Black Island stores body type as appearance state and re-resolves clothing/animation compatibility when body state changes. Pregnancy or other body-state transitions must not assume normal clothing has equivalent frames.

Fallback chain is explicit:

`requested asset -> compatible same-family variant -> configured safe fallback -> hide optional layer only if semantically safe`

Never silently hide required body/clothing layers and leave a broken character.

## Layers and z-order

LPC assets can contain multiple layers with z-position ordering and custom-animation-specific layers.

Black Island preserves layer order during compilation/composition. It must support behind-body/front-body weapon parts and other multi-layer assets.

Runtime ordinary characters should not keep one `Sprite3D` per LPC layer. Layers are composed/cached into runtime textures/clips whenever practical.

## Path dependencies

Some LPC definitions use path templates influenced by other selections. Black Island compiler/runtime resolver must preserve semantic dependencies rather than assuming one selection maps to one fixed image path.

Upstream path behavior is compiled into catalog dependency rules so faces/heads/accessories continue resolving correctly.

## Recolor/palette system

Black Island preserves LPC semantic recolor channels rather than reducing everything to one RGB tint.

Assets may expose multiple recolor channels/materials such as:

- body/skin;
- hair;
- cloth;
- metal;
- wood/handle;
- eyes;
- accessory sub-parts.

Palette keys should remain semantic/versioned where possible rather than storing only raw RGB. Multiple recolor channels on one item must be supported.

`matchBodyColor`-like behavior is preserved so compatible body-colored layers follow the selected body tone automatically.

## Custom and oversized animations

Do not assume fixed 64x64 frames or one canonical sheet layout.

The compiler imports standard and custom animation definitions, including different frame sizes/sequences and custom clips derived from base animations.

Black Island emits a runtime animation registry/clip format that can represent:

- semantic action mapping;
- source LPC animation;
- direction rows;
- frame sequence;
- frame size/pivot;
- supported body types;
- required layers/equipment;
- oversized weapon/tool clips.

Gameplay uses semantic actions; the LPC resolver selects the compatible upstream clip.

## Credits and licenses

Black Island maintains a dedicated `LPCCreditRegistry`/license registry.

Credit sources include full upstream credits plus asset-level metadata and resolved files. The game may expose:

1. full credits for the installed/accepted LPC catalog;
2. credits for assets enabled by Black Island;
3. optional credits for assets actually used in a save/character set.

License metadata is validated during ingest. Missing/unknown license information is **not** assumed safe.

Suggested ingest statuses:

```text
technical_status: supported | partial | unsupported
legal_status: accepted | review | quarantined
```

An asset may be technically valid but remain unavailable to runtime until license policy approves it.

## Live catalog updates

Black Island may check for LPC catalog updates periodically (target concept: approximately every 12 hours while online/open, with first eligible check after connectivity returns).

Clients should not crawl the entire upstream GitHub history directly.

Preferred architecture:

`LPC upstream -> Black Island sync/build pipeline -> validated versioned catalog/delta pack -> game client`

Client state tracks at least:

- installed Black Island LPC catalog version;
- corresponding upstream commit/SHA;
- last successful update check.

Update is atomic:

`download to staging -> validate hashes/schema/credits/license metadata -> commit catalog version -> expose assets`

A failed update leaves the previous known-good catalog active.

Remote LPC content is data only. Runtime updater must not execute arbitrary scripts/native binaries/code from a remote catalog.

## Delta/update manifest

A catalog release can describe:

- added assets;
- changed assets;
- removed/deprecated assets;
- alias changes;
- palette changes;
- definition changes;
- credit/license changes;
- required minimum Black Island catalog/runtime schema;
- file hashes/sizes.

New upstream formats unknown to the current game can be downloaded/quarantined or ignored but must not be automatically activated until compatible.

## Community appearance pool

Future online appearance sharing is separate from the LPC catalog updater.

Players share compact appearance configuration, never composed PNG sprites.

A community appearance contains catalog/schema version plus body/selections/recolors necessary to reconstruct the character locally.

Before accepting a shared appearance:

- validate schema/catalog IDs;
- migrate aliases if possible;
- reject missing/incompatible required parts;
- validate body/animation compatibility;
- apply local legal/content policy;
- deduplicate by normalized appearance hash.

The client should fetch small batches into a local appearance cache rather than blocking NPC spawn on a network request. If unavailable/offline, NPCs use local procedural appearance generation.

Player-created appearance sharing should contain no unnecessary personal/account data.

## NPC randomization philosophy

Random NPC generation is intentionally only lightly curated. Strict filters exist mainly to prevent broken characters:

- incompatible body part;
- missing required animation/layer;
- invalid dependency;
- blocked/quarantined asset.

After that, visual randomness is allowed to produce unusual combinations rather than relying on hundreds of hand-authored presets.

## Godot runtime modules

Expected logical modules include:

- `LPCCatalog`
- `LPCCatalogUpdater`
- `LPCAssetCache`
- `LPCAppearance`
- `LPCAppearanceMigrator`
- `LPCCompatibilityResolver`
- `LPCAnimationResolver`
- `LPCPaletteResolver`
- `LPCComposer`
- `LPCWardrobe`
- `LPCCreditRegistry`

Names may change; responsibilities should remain separated.

## Runtime presentation relationship

Detailed player/Sprite3D behavior is documented in `docs/design/PLAYER_LPC_AND_3D_PRESENTATION.md`.

The catalog/composer owns LPC semantics. Player/NPC gameplay systems consume semantic appearance/animation actions and must not depend on raw upstream paths.
