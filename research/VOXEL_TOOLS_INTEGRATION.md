# Voxel Tools integration evidence — S01-P00

Validated on 2026-10-28. The selected route remains **Zylann Voxel Tools GDExtension 1.7 / `v1.7x`**, as required by ADR-0004 and `scripts/tooling/versions.env`. No engine, dependency pin or terrain architecture was changed.

## Artifact identity

- Release: [Voxel Tools GDExtension 1.7 for Godot 4.5+](https://github.com/Zylann/godot_voxel/releases/tag/v1.7x).
- Asset: `GodotVoxelExtension.zip` (54,457,774 bytes).
- SHA-256: `600737572a5e25541ba6f503e842a3717ba19afafa5474510a6ceff995a1d2d8`.
- The locally computed SHA matched both the project pin and the [GitHub release asset digest](https://api.github.com/repos/Zylann/godot_voxel/releases/tags/v1.7x).
- All 34 archived files matched the installed contents under `game/addons/zylann.voxel/` byte-for-byte. All 14 library paths declared by `voxel.gdextension` existed.
- Entry point: `voxel_library_init`; descriptor `compatibility_minimum = "4.4.1"`. These are metadata, not proof of compatibility with every engine/platform combination. The actual tested engine was `4.7.2.stable.official.ed1daf0bf` on Linux x86_64.

Reproduce from the repository root after bootstrap:

```bash
source scripts/tooling/versions.env
printf '%s  %s\n' "$VOXEL_TOOLS_SHA256" ".tools/cache/GodotVoxelExtension-${VOXEL_TOOLS_TAG}.zip" | sha256sum --check
.tools/bin/godot --version
.tools/bin/godot --headless --path game --script res://tests/integration/voxel_capability_probe.gd
```

## Executed capability evidence

The reusable probe exits nonzero if its required capabilities fail. It is a dependency integration check, with a tiny in-memory SDF sphere and no gameplay or saved world.

| Check | Observed result |
|---|---|
| Extension registration | PASS: `VoxelBuffer`, `VoxelMesherTransvoxel`, `VoxelLodTerrain`, `VoxelGeneratorNoise`, `VoxelViewer`, `VoxelToolLodTerrain`, `VoxelStreamRegionFiles` registered |
| Editability API | PASS: `VoxelToolLodTerrain.is_area_editable` present |
| SDF storage | PASS: 32-bit float `CHANNEL_SDF` preserved negative interior and positive exterior values |
| Smooth mesh | PASS: `VoxelMesherTransvoxel.build_mesh` generated a sphere with 582 vertices and 3,480 indices; exit 0, no engine errors |
| Terrain/mesher connection | PASS: assigning the Transvoxel mesher to `VoxelLodTerrain` and setting `lod_count = 4` round-tripped |
| Standalone transition test helper | FAIL: reproducible array-format error, detailed below |
| Streamed terrain, rendered LOD seams, collision/edit latency | NOT TESTED in P00; required P02 evidence |
| Android/iOS build, install, terrain operation, sustained performance | NOT TESTED; native-device gates remain open |

The regular mesh probe loads the extension in a real headless Godot process. Import/editor-open evidence is recorded separately in `harness/build/S01-P00.md`.

### Known failure: standalone transition helper

The optional regression mode reproduces the failure without making it a hidden success:

```bash
.tools/bin/godot --headless --path game --script res://tests/integration/voxel_capability_probe.gd -- --transition-helper
```

Observed exit: **1**. A plane crossing a padded block's side faces produced no transition surfaces and emitted:

```text
Condition "p_arrays[ai].get_type() != Variant::PACKED_BYTE_ARRAY" is true. Returning: ERR_INVALID_PARAMETER
Invalid array format for surface.
Standalone Transvoxel transition helper produced no surfaces
```

Pinned source identifies a narrow defect in the testing helper: [`VoxelMesherTransvoxel::build_transition_mesh`](https://github.com/Zylann/godot_voxel/blob/v1.7x/meshers/transvoxel/voxel_mesher_transvoxel.cpp#L402) is explicitly labeled "Only exists for testing". It fills `ARRAY_CUSTOM0` with LOD data but calls `add_surface_from_arrays` without custom-array format flags. The regular mesher's `build` sets `ARRAY_CUSTOM_RGBA_FLOAT` flags, and [`VoxelMesher::build_mesh`](https://github.com/Zylann/godot_voxel/blob/v1.7x/meshers/voxel_mesher.cpp) passes `output.mesh_flags` to Godot. The native terrain path combines regular and transition geometry in that flagged output.

This source distinction explains why the sphere path passed while the standalone helper failed. It does **not** prove that actual streamed LOD seams render correctly. P02 must validate the native `VoxelLodTerrain` path with multiple LODs and the proper seam-aware shader before relying on it. Do not call the standalone helper in production or silently patch/upgrade the pinned binary. If native terrain also fails, preserve the smallest reproduction and review an explicit fix/module-build route behind the same Black Island interface.

## Mobile/export implications

The archive's `voxel.gdextension` maps the following mobile binaries:

| Target | Declared features / binaries | Evidence and remaining gate |
|---|---|---|
| Android | `android.debug.arm64`, `android.release.arm64`, `android.debug.x86_64`, `android.release.x86_64` | All four ELF shared libraries present. `file` reports Android API 24 and NDK r28b (13356709). No 32-bit ARM/x86 entries. Check project min SDK, ABI selection, packaging, native dependencies, current Android page-size requirements, device loading and performance with real exports. |
| iOS | `ios.debug`, `ios.release` → arm64 `.dylib` files | Both Mach-O arm64 libraries present. No separate simulator library mapping is provided. Actual export requires the Godot 4.7.2 iOS templates plus macOS/Xcode, device provisioning/signing and GDExtension embedding/signing validation. Binary presence does not prove simulator, App Store or device compatibility. |

The `editor` substring in a debug library's filename is the upstream build naming convention; it does not establish that an iOS editor application is supported. macOS universal frameworks in this archive are not iOS simulator libraries.

Linux `ldd` found no unresolved dependencies for the x86_64 editor library. This says nothing about Android linker behavior, iOS deployment targets, signing, GPU drivers or mobile memory budgets.

Upstream explicitly warns in the pinned release notes:

> WARNING: It hasn't gone through much testing, so it might have bugs that are not present in module builds.

Treat the extension route as the selected first integration, with its risks recorded. No mobile export/performance result is inferred from Linux/headless success. Android/iOS device validation must cover mesh/collision memory, main-thread integration cost, remesh latency, worker contention and sustained thermal behavior, per `VOXEL_WORLD_IMPLEMENTATION.md`.

## P02 integration constraints

- Keep terrain queries, edit validation, streaming and persistence behind Black Island-owned boundaries (`TerrainEditService` and terrain/stream/persistence adapters described by the architecture). Do not introduce gameplay dependencies on extension node paths, transient native objects or native serialization layouts.
- Keep untouched terrain generator-backed; persist seed, generator/profile version and versioned edits/material deltas. Mesh/collision products are disposable. Do not use a plugin object ID as a persistent identity.
- Preserve the accepted 0.5 m terrain samples, 1 m BuildGrid and 64 m WorldChunk address/persistence units. Internal data/mesh blocks remain smaller; P02 trials compare 16/32-voxel mesh blocks and sparse vertical streaming.
- Only edit loaded/editable regions. Validate `is_area_editable` before mutations and budget main-thread mesh/collision integration. Four configured LOD levels in a capability probe are not evidence that a 3×3 near ring meets frame/memory budgets.
- Use the required Transvoxel shader path for seam rendering; class/API availability alone is insufficient. See the [pinned `VoxelMesherTransvoxel` contract](https://github.com/Zylann/godot_voxel/blob/v1.7x/doc/classes/VoxelMesherTransvoxel.xml) and [pinned `VoxelLodTerrain` contract](https://github.com/Zylann/godot_voxel/blob/v1.7x/doc/classes/VoxelLodTerrain.xml).
- If the extension fails an essential platform or measured budget, evaluate the corresponding module/custom Godot 4.7.2 build behind these boundaries, with explicit reviewed dependency changes/ADR. Do not replace the terrain architecture or write a voxel engine as a bootstrap workaround.

No island generator, production terrain scene, BuildGrid implementation, player or gameplay system was created by this validation.
