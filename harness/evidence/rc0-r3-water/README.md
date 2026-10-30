# R3 C01 water evidence

All captures are engine output, not generated artwork. Desktop/llvmpipe proxy only.

| Artifact | Purpose |
|---|---|
| lake-gameplay.png | Final production Main/player, lake depth/shore/ripple presentation |
| river-gameplay.png | Final moving river, current-driven visual detail and coherent tile boundaries |
| gl_compatibility-Low.png | Actual Compatibility / Low shader smoke |
| mobile-Medium.png | Actual Mobile Vulkan / Medium shader smoke |
| forward_plus-High.png | Actual Forward+ Vulkan / High shader smoke |
| current-fall.png | Earlier controlled QA flow/drop and waterfall placeholder, before final texture-upload refinement |
| terrain-blocked.png / terrain-released.png | Earlier controlled QA barrier/release states; deterministic B tests are the behavioral proof |
| basin-medium.png / low-compatibility.png | Earlier reference stills; not the final performance/continuity evidence |
| renderer-smoke-metrics.json | Final static mesh/state-texture display smokes; isolated active/sleeping and renderer OFF/ON |
| final-validation.json | Final isolated C gate, three production-world backend smokes, exact query equality, and retained contention diagnostic |
| external-voxel-warning.json | Non-fatal pinned dependency warning, unchanged R2 paths and short reproduction |

The functional foundation passes. The literal zero-warning formal gate remains blocked only by the documented external Voxel Tools warning. Full details and reproducible commands: [build log](../../build/S01-RC0-R3-C01.md).

PHYSICAL MOBILE PERFORMANCE NOT VALIDATED
