# C04 evidence

Godot 4.7.2, actual Boot → MainMenu → Worlds → PlayerProfiles → Main.
Seed 424242, generation 2, `chapter1_native_960m_v2`. Captured through Godot MCP
on Compatibility/Mesa llvmpipe; these are desktop proxy observations.

| Capture | Observation |
| --- | --- |
| overview.png | Normal world gameplay, Overview camera, daylight |
| shoulder-targeting.png | Shoulder composition and real aim-screen interactable feedback |
| loose-item.png | Small parcel published through the inventory/drop transaction |
| chest-closed.png | Chest closed after accepted container closure |
| chest-open.png | Chest lid opened by accepted service state |
| world-drop-bags.png | Distinct bag/death bag presentation beside Chest |
| night.png | WorldClock-driven night presentation |
| rain.png | WorldWeather-driven local rain in gameplay |
| thunderstorm.png | Storm presentation and lightning flash hook |
| world-integrated-wide.png | Integrated gameplay at 1920×864 (logical viewport 1600×720) |

Other captures use a 1280×720 window. Chest/bag detail captures temporarily hide
the HUD and existing tree/prop **presentation** to inspect the lid and sacks under
dense placeholder canopies. Domain state, collision, terrain, grass and water
remain active. Presentation was restored afterwards. These inspection shots do
not claim that canopy occlusion has been solved; normal gameplay captures retain
the original foliage.

`results.json` contains selected structured MCP assertions, final focused test
counts, LSP and CPU samples. It excludes raw screenshots, full RPC transcripts
and machine-specific user paths. Screenshots supplement assertions.

PHYSICAL MOBILE PERFORMANCE NOT VALIDATED.
