# Open Design Checklist

This is the current list of systems/decisions that still need a dedicated design/technical pass before Black Island's Chapter 1 architecture can be considered broadly locked.

Items are grouped by priority/dependency rather than implementation order.

## P0 — blocks core world/player implementation

### 1. Voxel terrain implementation profile

Architecture is locked as volumetric voxel data + smooth visual surface, but benchmarks must choose:

- voxel world scale/resolution;
- chunk dimensions;
- smooth meshing implementation/library strategy;
- collision regeneration policy;
- LOD strategy;
- memory budgets for target phones;
- exact delta persistence/compaction format;
- terrain edit radius/shape limits by tool.

### 2. Biome + prop generation

Need a dedicated spec for both surface and cave floors:

- biome definition/data model;
- biome masks and transition zones;
- prop spawn rules per biome;
- trees, rocks, bushes, grass, flowers, debris and resource nodes;
- deterministic seed/spawn IDs;
- density/scatter/cluster algorithms;
- slope/height/water/material constraints;
- persistent vs disposable props;
- streaming/pooling/MultiMesh strategy;
- harvesting/destruction persistence;
- regeneration/regrowth rules;
- rare/special biome props and POIs.

### 3. Grass/foliage response to world edits

Need explicit rules for:

- foundation placed on grass;
- path/farm material painted over grass;
- terrain dug/raised below foliage;
- foliage suppression volume around structures;
- whether removed grass regrows after demolition;
- grass blending at build/path boundaries;
- local update rather than regenerating whole biome.

### 4. Player movement/camera feel

LPC/3D presentation is defined, but actual controller still needs:

- movement acceleration/deceleration;
- run/stamina behavior;
- slope handling;
- step height and terrain traversal;
- camera angle/distance/FOV or orthographic strategy;
- shoulder vs more Cult-of-the-Lamb-like camera decision;
- camera rotation rules;
- obstruction handling;
- build-mode top-down camera transition;
- touch gesture mapping.

### 5. Interaction/targeting model

Define priority between terrain, structures, NPCs, crops, drops and combat targets under the center probe/crosshair, including mobile aim assistance and contextual actions.

## P1 — Chapter 1 core gameplay

### 6. Inventory final UX

Core slot/stack model is defined. Still needs:

- exact slot counts;
- equipment slots;
- backpack progression;
- drag/drop/touch gestures;
- split stack UX;
- sort/filter/search;
- quick transfer;
- chest/container interactions;
- drop confirmation rules for valuable items.

### 7. Craft queue remaining edge cases

Need to lock:

- whether a queue quantity that shrank due to missing resources can automatically regrow if resources return;
- active timer behavior after queue reorder;
- station-based crafting vs player crafting;
- offline/save-load handling of partially elapsed unit timer;
- queue behavior if a recipe/definition migrates between game versions.

### 8. Structure catalog and exact support constants

Structural algorithm is defined. Need content/balance values for:

- foundation size;
- max initial free horizontal span;
- piece loads;
- root/pillar/wall capacities;
- wood/stone/reinforced tier differences;
- vertical stack limits;
- collapse timing/debris/refunds;
- build/demolish cost rules;
- ramps/stairs/doors/windows/roof pieces for Chapter 1.

### 9. Farming

Need full lifecycle spec:

- tilling targeting;
- seed placement;
- watering;
- wetness duration;
- crop stages;
- seasons/biome influence if any;
- harvest yield;
- fertilizer;
- trampling/damage;
- interaction with terrain material blending.

### 10. Resource gathering

Define trees/rocks/ore/resources:

- hit points vs per-hit progress;
- tool requirements/tiers;
- visual hit feedback;
- drops;
- stump/remnant behavior;
- regrowth/respawn;
- relationship to voxel terrain vs prop entities.

## P1 — World generation/content

### 11. Surface biome set

Choose Chapter 1 biome families, palettes and gameplay differences. Long-term island architecture must allow several major biomes plus smaller transition/special biomes.

### 12. Cave/mine biome set

The mine is treated as multi-floor cave exploration. Need biome families such as possible bioluminescent, dark/hostile, gothic or other unusual underground zones, with generation/material/lighting/prop/enemy rules.

### 13. POI generation

Need generation/validation for ruined village, cave entrance, shrines/ruins, special resource pockets and future landmarks.

### 14. Hydrology with voxel terrain

Revisit rivers/lakes under volumetric terrain:

- generation;
- shore blending;
- water volumes;
- channels made by players;
- whether water dynamically propagates or is initially mostly authored/generated volumes;
- performance constraints.

## P1 — Player/combat

### 15. Combat controller

Data model exists conceptually; still needs exact Chapter 1 implementation of:

- lock/no-lock targeting;
- dodge;
- combo input buffer;
- weapon swap timing;
- hitstop;
- knockback;
- invulnerability windows;
- enemy telegraphs;
- mobile controls.

### 16. Tool/action semantic animation map

Compile exact mappings/fallbacks between Black Island actions and the LPC catalog after the LPC importer/catalog spec is committed.

## P1 — LPC/content pipeline

### 17. LPC integration docs/repo update

Research is complete enough to document, but repository still needs the dedicated accepted LPC architecture covering:

- upstream snapshot/compiler;
- `sheet_definitions` + `palette_definitions` sources of truth;
- stable Black Island asset IDs + aliases;
- verified compatibility matrix;
- custom/oversized animations;
- multi-channel recolor;
- credits/license registry;
- live catalog updater/delta packs;
- community appearance schema/cache;
- quarantine of technically/legal unsupported assets.

### 18. Character creator UX

Need final categories, randomization strength, body options, recolor UI, locks, wardrobe behavior and community-skin eligibility score.

## P2 — Village/NPC/content expansion

### 19. Procedural NPC appearance

Only anti-break compatibility should be strict. Need exact light contextual/random weighting without over-curating away randomness.

### 20. Names

Create/generate large first-name and surname pools and define:

- masculine/feminine/neutral pools where appropriate;
- first-only/surname-only/full-name probabilities;
- uniqueness/repetition policy within one save;
- localization/future culture support.

### 21. NPC jobs and village economy

Skills/aptitudes exist conceptually, but production/resource/job loops need a dedicated simulation pass.

## P2 — Presentation

### 22. Final world art direction

Need lock for:

- cartoon/pixel-art hybrid proportions;
- terrain material style;
- outlines;
- lighting/shadows;
- sprite filtering;
- prop density;
- VFX language;
- day/night palette treatment.

### 23. Build-mode feedback

Need exact ghost colors/outline, grid visibility, invalid reason presentation, socket highlights, support visualization and demolition preview.

## P2 — Technical/platform

### 24. Save migration/versioning

Stable IDs and world deltas need formal schema/version migration rules before content volume grows.

### 25. Mobile performance budgets

Lock target budgets for:

- terrain chunks;
- draw calls;
- active NPCs;
- cached LPC textures;
- foliage instances;
- memory;
- frame time;
- background generation work.

### 26. Networking/community appearance provider

Not Chapter 1 core. Keep abstraction-friendly architecture; later decide HTTP vs WebSocket transport, moderation/privacy, batching/cache and authoritative multiplayer boundaries.

## Already substantially locked

The following should not be reopened casually without an ADR:

- `game/` is the Godot project root;
- Godot 4.7.2 target;
- surface terrain is voxel-authoritative with smooth presentation;
- construction uses separate square build grid/shared edges/sockets;
- structural support is graph/provenance/capacity based;
- unsupported structures can collapse;
- mines/caves are separate floor worlds;
- LPC characters are composed/cached and presented in 3D rather than persistent per-layer Sprite3D stacks;
- crafting is per-unit queued and transactional;
- no inventory weight system;
- game remains functional offline;
- optional external LLM is enrichment, never authoritative world brain.
