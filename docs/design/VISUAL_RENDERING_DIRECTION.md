# Visual Rendering Direction — Technical Art Spec

Status: accepted technical-art direction; exact shader values require device profiling.

## Art target

Black Island mixes:

- cartoon 3D world/props;
- pixel-art/LPC-derived character presentation;
- cute/readable shapes;
- darker/bloody/aggressive combat accents;
- dense, lively environment inspired by the readability/contrast of Cult of the Lamb without copying its exact look.

The world should feel intentionally stylized rather than like realistic PBR assets with pixel sprites dropped on top.

## Renderer baseline

Mobile-first Godot project should validate the **Mobile** renderer first.

Godot's current Mobile renderer uses a forward single-pass/raster-oriented approach designed for mobile GPU bandwidth/tiling constraints. High-end Forward+ features are not assumed.

Avoid designing the art direction around expensive desktop-only GI/post-processing.

## Lighting model

Baseline scene lighting:

- one primary DirectionalLight3D for sun/moon role;
- restrained ambient/world lighting;
- selective local Omni/Spot lights for important sources;
- most decorative glow sources should not all cast dynamic shadows.

Lights without shadows are significantly cheaper than shadow-casting lights, so only gameplay/hero lights receive shadows where the visual gain justifies it.

## Shadows

Goal: soft readable grounding, not photorealistic shadow simulation.

Use:

- directional shadow for main sun/moon;
- modest resolution/distance suited to angled camera;
- limited shadow-casting distance;
- blob/contact-style fake shadows for some sprite characters/props when cheaper and visually cleaner;
- no expectation of PCSS directional shadows on Mobile renderer.

Character Sprite3D can use a simple ground shadow decal/mesh/texture rather than requiring complex self-shadowing from every LPC pixel.

## Toon/cartoon material language

Terrain/props should favor:

- broad value bands;
- restrained roughness/specular variation;
- simple stylized rim/fresnel only when cheap;
- palette-controlled biome materials;
- controlled saturation;
- readable silhouette over microdetail.

If a custom toon-lighting shader is used, keep it raster/mobile-safe and benchmark instruction/texture cost.

Do not force every material through one expensive mega-shader.

## Outlines

Outlines are primarily **interaction/feedback**, not necessarily a permanent full-scene post-process.

Use contextual outline/highlight for:

- WorldDropBag / DeathBag;
- interactable door;
- chest/workbench;
- NPC/interactable target;
- harvest target where useful;
- build/snap preview.

Preferred approaches:

- material/mesh duplicate outline for selected hero objects;
- emissive/edge highlight;
- lightweight local shader.

Avoid a full-screen depth/normal edge detector as a baseline requirement on mobile unless benchmarks prove it affordable and visually necessary.

## Foliage transparency

For leaves/grass that are mainly fully opaque or fully transparent, prefer **Alpha Scissor** over regular alpha blending.

Godot documents alpha testing/scissor as faster and less prone to transparency sorting issues than full alpha blending.

For antialiased cutout edges:

- Alpha Scissor/Hash where appropriate;
- Alpha To Coverage / alpha antialiasing when MSAA profile supports it;
- preserve alpha test coverage in mipmap import for cutout foliage to reduce distant disappearing/thinning artifacts.

Avoid large overlapping fields of alpha-blended grass cards.

## Mipmaps and distant vegetation

Textures used in 3D generally keep mipmaps enabled.

For cutout foliage:

- generate mipmaps;
- enable alpha test coverage preservation where appropriate;
- tune alpha-scissor threshold;
- use LOD/impostor/batched replacement rather than disabling mipmaps and accepting shimmer.

Distant fade should prefer dither/object-dither approaches when possible instead of pushing all faded vegetation through expensive transparent rendering.

## Grass

Near grass:

- MultiMesh/batched clumps;
- local wind deformation in vertex shader;
- simple cutout material;
- local suppression masks around structures/roads/farming.

Mid/far:

- lower density/LOD clumps;
- terrain color/detail carries the suggestion of grass;
- eventually remove individual blades entirely at far distance.

## Luminous Forest

The Luminous Forest must look striking without becoming a hundred shadow-casting lights.

Use layered illusion:

- emissive-looking materials for moss/crystals/plants;
- small selected local lights around hero clusters;
- unshadowed lights for much of ambience;
- fog/color grading only if mobile renderer/profile supports chosen method cheaply;
- material color/emission provides most perceived glow;
- VFX motes/particles kept bounded and distance-culled.

Screenshot appeal comes from color composition and cluster placement, not brute-force light count.

## Blood/combat contrast

Cute base presentation can contrast with:

- strong hit flash;
- stylized blood particles/decals where age/content policy permits;
- aggressive squash/stretch/hitstop;
- dark/red impact accents;
- enemy telegraphs using clear color/value language.

VFX should remain short-lived/batched and avoid persistent particle overload.

## Water presentation

Near water can use richer normals/reflection/refraction-like stylization only within the measured mobile budget.

Far ocean uses simplified material/LOD and should not pay for the same effects as near-player water.

Dynamic water simulation data and visual water mesh/shader are separate systems.

## LPC sprite filtering

LPC sprites need deliberate import/filter treatment so they remain crisp but not visually disconnected from 3D terrain.

Test profiles:

- nearest filtering for strongest pixel identity;
- nearest + controlled resolution scaling;
- selective linear filtering only if camera motion/shimmer is unacceptable.

Do not globally blur the sprite just to hide pixel edges.

Sprite billboard material should avoid unnecessary transparency features beyond the actual cutout needs.

## Post-processing

Mobile baseline should avoid depending on:

- heavy screen-space effects;
- depth of field;
- expensive glow stack;
- full-scene outline post-process;
- desktop-only GI.

Small color/tone adjustments are acceptable if measured.

## Required profiling scenes

Codex should eventually build repeatable visual benchmark scenes for:

1. dense tropical grass/forest;
2. many LPC characters;
3. Luminous Forest emissive props/lights;
4. storm/rain/lightning;
5. water shoreline;
6. build-heavy village.

Each benchmark records FPS/frame time, draw calls, memory and visible artifacts on representative devices.
