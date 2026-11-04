# Runtime dependencies in a normal clone

Use Godot 4.7.2 with project root `game/`. Voxel Tools 1.7/v1.7x and LimboAI 1.8.1 GDExtension payloads are checked into Git, including platform libraries and licenses. A complete clone needs no dependency download or Codex bootstrap to import/run the game. No Git LFS is used.

`python3 scripts/verify_runtime_dependencies.py` verifies the committed per-file manifest against the pinned official archive checksums in `scripts/tooling/versions.env`. It requires no network and never installs files. Restore missing/modified runtime payloads from Git rather than trusting an old installation stamp.

`bash scripts/validate_clean_clone.sh` makes a separate Git-only clone, isolates user data, imports with externally installed Godot 4.7.2 and checks native classes plus Boot/MainMenu. Set `GODOT_PATH` to the external executable when the development `.tools/bin/godot` is absent. The clone operation can use a local source and the subsequent test is offline.

Bootstrap is for Codex development tools. Godot MCP and Serena are optional development integrations; neither is needed by an exported game or a normal editor clone. The committed editor plugin list contains BlackIslandTools only. A developer enabling Godot MCP locally should not commit that optional activation.

Official binaries cover the primary desktop/mobile targets, but only Linux x86_64 is executed in this environment. See the C04 build log for optional-target gaps in the unmodified upstream descriptors and physical/export validation limits.
