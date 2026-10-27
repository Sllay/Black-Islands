# Player LPC + 3D Presentation — Design/Technical Spec

Status: Accepted direction; exact animation/runtime implementation still requires profiling.

## Core presentation

Black Island is a real 3D world with 2D LPC-derived characters presented inside it.

The preferred player visual root is conceptually:

```text
Player (CharacterBody3D)
├── CollisionShape3D
├── movement/action components
├── interaction/combat probes
└── CharacterVisual3D
    ├── LPC Sprite3D / billboard presentation
    ├── shadow
    └── local VFX/equipment presentation adapters
```

The authoritative physical position is the character's feet/contact point, not the visual sprite center.

## LPC composition

Do not represent every LPC body/clothing layer as a separate persistent `Sprite3D` during ordinary gameplay.

Preferred pipeline:

`CharacterAppearance -> LPC catalog/layer resolver -> body/variant/recolor/path compatibility -> zPos ordering -> compose/cache -> runtime character texture/clip -> Sprite3D`

Recompose only when appearance/equipment/required visual state changes. Reuse cached results when appearance keys match.

## Direction and camera

The Sprite3D faces/billboards toward the gameplay camera. LPC directional animation is selected from movement/action direction relative to camera/actor orientation rather than physically turning the sprite plane away from the camera.

The direction resolver must remain compatible with future camera rotation.

## Animation abstraction

Gameplay code should not hard-code upstream LPC animation names.

Use semantic visual actions such as:

- `IDLE`
- `MOVE`
- `RUN`
- `MELEE_SLASH`
- `THRUST`
- `SHOOT`
- `CHOP`
- `MINE`
- `FISH`
- `WATER`
- `SIT`
- `HURT`
- `DEAD`

The LPC animation resolver maps semantic actions to the best compatible catalog animation/body/equipment clip with fallback rules.

This isolates Black Island gameplay from upstream LPC naming changes and missing animation coverage.

## Variable/custom animation sizes

Do not assume every clip uses one 64x64 sheet layout. The LPC ecosystem includes custom/oversized animations with different frame sizes and sequences.

Black Island runtime should consume compiled animation metadata equivalent to:

```text
AnimationClip
- semantic action
- source animation/catalog animation
- directions
- frame rectangles / sequence
- frame/pivot size
- frame duration
- visual events
- supported body types
- required layers/equipment
```

## Animation events

Gameplay effects are not triggered merely because an animation ends. Clips expose semantic event markers such as:

- `HIT_START`
- `HIT_END`
- `TOOL_IMPACT`
- `PROJECTILE_RELEASE`
- `FOOTSTEP`
- `FISH_CAST`

The gameplay action owns authoritative mechanics. The visual event synchronizes the correct moment.

Examples:

`TOOL_IMPACT -> TerrainEditService / resource target action`

`HIT_START -> combat hitbox activation`

`PROJECTILE_RELEASE -> ranged attack spawn`

## Player states

Initial movement/action states may include:

- Idle
- Move
- Run
- Attack
- UseTool
- Interact
- Build
- Hurt
- Dead

Future states such as swim, fish, sit, sleep, carry and push should compose with the same semantic action layer rather than creating LPC-specific gameplay code.

## Appearance changes

Appearance is data, not a sprite filename. A character appearance references catalog selections/body/recolors and Black Island-specific metadata/migrations.

Clothing and equipment are distinct concepts:

- **Clothing** — mostly visual/social, changed through wardrobe/customization and unlock rules.
- **Equipment/armor/weapons** — gameplay items/stats that may alter visual layers and animations.

Pregnancy/body-state changes must re-resolve compatible clothing/animations rather than assuming all normal assets work. Missing assets use explicit compatibility fallback, never a silent invisible body/clothing layer.

## Runtime cache

A cache key should include all inputs that affect final visual output, for example:

`catalog version + body type + selections + recolors + equipment visual state + compiled animation set version`

Identical appearances may share immutable texture/clip resources where safe.

## Interaction with world

The character's physical body remains normal 3D gameplay geometry even though the visible character is 2D.

Terrain/build targeting uses 3D ray/probe results and authoritative terrain/build grids. The LPC sprite is presentation and must not define collision, targeting or occupancy.

## First person

Optional first-person mode may hide the local third-person billboard and use a dedicated first-person equipment/hands presentation. Other actors remain LPC Sprite3D characters.

## Visual style target

The intended scene language is readable stylized 3D/cartoon terrain and props with pixel-art/cartoon LPC characters, strong silhouettes and clear action feedback. Exact lighting, outline, shadow, sprite filtering and material treatment remain part of the pending visual-art direction pass.
