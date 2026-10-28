# Player LPC + 3D Presentation — Design/Technical Spec

Status: Accepted core direction; tuning requires playable profiling.

## Core presentation

Black Island is a real 3D world with 2D LPC-derived characters presented inside it.

Conceptual player root:

```text
Player (CharacterBody3D)
├── CollisionShape3D
├── PlayerMotor
├── PlayerActionController
├── InteractionTargeter
├── CombatController
├── Equipment/Inventory adapters
└── CharacterVisual3D
    ├── LPC Sprite3D / billboard presentation
    ├── shadow
    └── local VFX/equipment presentation adapters
```

The authoritative physical position is the character's feet/contact point, not the center of the sprite.

## Camera modes

First-person is not part of the core Black Island direction.

### Gameplay camera — `GAMEPLAY_ANGLED`

Primary exploration/combat camera is an elevated angled camera inspired by the readable composition of Cult of the Lamb.

Goals:

- readable enemy telegraphs;
- visible surrounding terrain/props;
- stable LPC presentation;
- strong mobile combat readability;
- enough depth/perspective to feel like a 3D world without becoming over-the-shoulder combat.

Initial implementation should test a perspective camera with a long focal length/narrower FOV against orthographic presentation. Choose based on visual feel and depth readability, not ideology.

Camera heading may be fixed or rotate only through controlled increments if later testing proves useful; gameplay must not require free FPS-style look.

### Build camera — `BUILD_THIRD_PERSON`

Entering build mode transitions smoothly from the angled gameplay composition to a closer third-person construction camera.

Goals:

- precise ray/probe targeting;
- clear square build grid;
- readable socket previews;
- easier vertical placement of walls/pillars/ceilings;
- optional limited orbit/rotation around player/build target.

Build placement remains snapped to grid/sockets even though targeting is free 3D.

Exiting build mode returns to the previous gameplay camera state.

## Camera obstruction

Trees, roofs and tall props between camera and player should not make the player disappear.

Preferred solution order:

1. camera-aware foliage/roof fade or dither for obstructing presentation;
2. small camera reposition/zoom correction where appropriate;
3. avoid destructive camera collision that causes large uncomfortable jumps.

Use object/pixel dither or project-specific cutaway treatment instead of heavy full alpha blending where possible on mobile.

## LPC composition

Do not represent every LPC body/clothing layer as a separate persistent `Sprite3D` during ordinary gameplay.

Pipeline:

`CharacterAppearance -> LPC catalog/layer resolver -> compatibility/recolor/zPos -> compose/cache -> runtime animation texture/clip -> Sprite3D`

Recompose only when appearance/equipment/required visual state changes. Reuse cache where appearance keys match.

## Billboard and direction

The Sprite3D remains camera-facing/readable.

LPC directional frame selection is based on actor/action direction transformed relative to camera orientation.

The player may physically face a world direction while the flat visual plane remains camera-facing.

`world action direction -> camera-relative direction resolver -> LPC up/down/left/right clip`

This keeps directional animation correct if camera heading changes.

## Animation abstraction

Gameplay code never hard-codes LPC upstream names.

Semantic visual actions include:

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
- `SWIM`
- `DODGE`
- `GUARD`
- `HURT`
- `DEAD`

`LPCAnimationResolver` maps semantic action to the best compatible catalog animation/fallback for current body/equipment.

## Variable/custom animation sizes

Do not assume one 64x64 frame layout.

Runtime clip metadata can contain:

```text
AnimationClip
- semantic action
- source catalog animation
- directions
- frame rectangles/sequence
- pivot/origin
- frame duration
- events
- supported body types
- required equipment/layers
```

Oversized tool/weapon animations can therefore coexist with normal movement frames without resizing the physical player.

## Animation events

The gameplay action owns mechanics. Animation markers synchronize presentation/mechanical windows.

Examples:

- `HIT_START`
- `HIT_END`
- `TOOL_IMPACT`
- `PROJECTILE_RELEASE`
- `FOOTSTEP`
- `FISH_CAST`

`TOOL_IMPACT` may call a validated gather/terrain action. `HIT_START` activates a combat hitbox defined by the attack state.

## Movement controller

Use `CharacterBody3D` with project-owned motor logic.

Controller must handle:

- acceleration/deceleration rather than binary velocity;
- ground snapping;
- configurable maximum slope;
- small step/terrain seam handling;
- airborne/fall handling;
- knockback impulses;
- water/swim state;
- temporary movement locks from heavy attacks/tool actions;
- mobile joystick input normalized independently of camera pitch.

Do not infer traversal from the rendered Sprite3D.

## Slope handling

Smooth voxel terrain means floor normals vary continuously.

Movement should:

- project desired ground motion onto valid walkable plane;
- reject/slide on slopes above configured limit;
- maintain stable grounded snap over small Transvoxel surface variation;
- use a modest step/snap tolerance so tiny mesh seams do not stop the player;
- never allow camera/build grid precision to depend on visual terrain triangle IDs.

Exact slope angle and step height are tuning constants after player prototype exists.

## Stamina

Stamina is a 0-100 player resource.

Confirmed primary uses include physical gathering/tool work such as:

- chopping trees;
- mining/resource veins;
- repeated heavy gathering actions.

Combat/weapon definitions may also consume stamina if the design for that weapon requires it, but stamina is not a hunger surrogate.

Stamina costs are requested by semantic actions; animation does not directly modify stamina.

## Player action states

Initial states include:

- Idle
- Move
- Run
- Attack
- HeavyAim
- HeavyAttack
- Skill
- Ultimate
- Dodge
- Guard/Parry where supported
- UseTool
- Interact
- Build
- Swim
- Hurt
- Dead

Systems should use composable state/action locks where possible rather than one giant unmaintainable enum.

## Appearance changes

Appearance references stable LPC catalog selections/body/recolors plus Black Island migrations.

Clothing and equipment remain distinct:

- **Clothing** — visual/social wardrobe state;
- **Equipment/armor/weapons** — gameplay items that may add/replace visual layers.

Body-state changes such as pregnancy re-resolve compatible clothing/animations using explicit fallback rules.

## Runtime cache

Appearance/clip cache key includes all visual inputs, for example:

`catalog version + body type + selections + recolors + equipment visual state + compiled animation version`

Identical appearances may share immutable visual resources.

## World interaction

Terrain/build targeting is fully 3D.

LPC visual is never collision authority.

Interaction probe resolves world targets through `InteractionTargeter`, which can query terrain, structures, props, mobs/NPCs, corpses, bags, crops and water according to action context.

## Visual direction

Target presentation is cartoon/pixel-art hybrid:

- smooth/stylized 3D world;
- pixel/cartoon LPC characters;
- strong silhouettes;
- restrained mobile lighting;
- outline primarily as contextual interaction/target feedback rather than a permanent heavy full-scene outline.
