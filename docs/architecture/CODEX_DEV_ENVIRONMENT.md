# Codex Development Environment

Status: Accepted development-tooling baseline for Black Island.

## Purpose

A fresh Codex workspace cloned from `Sllay/Black-Islands` must be able to reproduce the project development environment without guessing Godot, MCP or voxel dependency versions.

The Godot project root remains `game/`. Tooling/cache files outside `game/` are development infrastructure, not runtime content.

## Pinned baseline

| Tool | Pin | Purpose |
|---|---|---|
| Godot | 4.7.2 | Engine/runtime/editor target |
| Node.js | 22.23.4 bootstrap fallback; any verified Node 22+ may satisfy Godot MCP | MCP runtime |
| Godot MCP | `@shin2344234/godot-mcp@0.1.2` | Scene/editor/runtime/LSP/DAP/test bridge |
| Serena | `serena-agent==2.1.0` | Symbol-aware GDScript retrieval/refactoring/editing |
| Voxel Tools | GDExtension 1.7, tag `v1.7x` | Smooth SDF/Transvoxel prototype/runtime dependency candidate |

Authoritative pins/checksums live in `scripts/tooling/versions.env`.

## One-command bootstrap

From repository root:

```bash
bash scripts/bootstrap_codex_env.sh
```

The bootstrap is intentionally Linux-first because Codex cloud environments are Linux. It:

1. verifies or installs Node.js 22+ locally without root;
2. installs `uv` if needed;
3. installs the pinned Serena version;
4. installs exact Godot 4.7.2 locally and verifies the release SHA-256;
5. downloads the pinned Voxel Tools GDExtension release and verifies its SHA-256;
6. installs the Voxel Tools addon contents into `game/addons/` locally;
7. runs a basic headless Godot editor validation.

`--mcp-only` skips the Voxel Tools step and is used automatically by MCP launcher wrappers so a fresh Codex session can start its tools first.

Downloaded tools and generated caches are local environment artifacts and must not be treated as game source.

### Reusable P00 validation

From the repository root, after the bootstrap:

```bash
node scripts/validate_mcp.mjs --install-addon
bash scripts/validate_bootstrap.sh
```

The Node command speaks MCP JSON-RPC over stdio to the two configured wrappers. Its first engine
operation is `godot_status`; `--install-addon` explicitly calls the pinned server's `addon.install`
operation, which installs/enables the development plugin in `game/project.godot`. The downloaded
`game/addons/godot_mcp/` directory stays ignored. A fresh checkout needs this step before the final
editor/import gate, because the development addon is not vendored in Git. Restart an already-open
editor after installing/enabling its plugin.

The validator proves a live bridge, a Serena query against the permanent voxel capability fixture,
and zero fixture diagnostics/editor errors. It exits nonzero on failure. It does not enable eval.
Use it as the single MCP operator while checking the environment; close other clients first.
Without `--install-addon`, it validates an already-prepared workspace.

`validate_bootstrap.sh` checks the repository boundary, actual versions, pinned archive hashes,
completed import, a short headless editor open and the in-memory SDF/Transvoxel capability probe.
Logs/JSON evidence stay in `.tools/logs/`. Import commands disable only the development bridge
using its supported `--godot-mcp-no-bridge` flag, so a one-shot process cannot replace a live
editor's session file. No scene/player/island or mobile performance is implied by these checks.

Serena 2.1.0 requires local trust for `game/` before applying project-specific LSP settings.
Set only this project's path in `trusted_project_path_patterns` in the local Serena configuration
(`serena config edit`); do not commit a machine's trust file. Its default GDScript backend also uses
6008, but successful defaults alone are not proof that trusted project settings were applied.

See `harness/build/S01-P00.md` and `research/VOXEL_TOOLS_INTEGRATION.md` for executed evidence,
the optional failing transition-helper reproduction, export limitations and the P01/P02 gates.

## Codex MCP configuration

Project-local configuration is committed at `.codex/config.toml`.

It exposes two MCP servers through repository-relative wrappers:

### `godot`

Launcher: `scripts/mcp/godot_mcp.sh`

Uses Godot MCP in `compact` mode to reduce tool-schema context while preserving access to the full API through its generic call tools.

Primary responsibilities:

- inspect/edit Godot scenes, nodes, signals, resources and project settings;
- launch/editor/headless runs;
- inspect runtime output/errors;
- screenshots/profiling where supported;
- GDScript diagnostics and Godot class reference;
- tests/debugger/editor bridge.

The live editor addon is not blindly vendored by bootstrap. At S01-P00, call `godot_status`; if it reports the editor addon missing/outdated, use the Godot MCP `godot_addon_install` operation, reopen/launch the project and verify the bridge. Keep the version pinned to the server version.

Do not enable arbitrary runtime eval by default.

### `serena`

Launcher: `scripts/mcp/serena_mcp.sh`

Serena is configured for `game/` through `game/.serena/project.yml` and uses Godot's built-in GDScript LSP on `127.0.0.1:6008`.

If no Godot editor is already serving LSP, the wrapper starts a headless Godot editor for the project
with explicit `--lsp-port 6008` and waits for the port before launching Serena. It also supplies the
pinned MCP addon's matching `--godot-mcp-lsp-port=6008` metadata, so the bridge reports the same port
even when the user's editor settings default to 6005. An existing listener must belong to `game/`;
do not share the port with another project's editor.

Primary responsibilities:

- find symbols without reading whole scripts;
- symbol overview and reference lookup;
- semantic rename;
- replace/insert around symbol bodies;
- focused diagnostics/navigation.

## Tool-use policy for GDScript

For existing `.gd` code, prefer this order:

1. **Serena** for locating symbols, references, semantic rename and localized symbol edits.
2. **Godot MCP** for engine-aware diagnostics, scene/resource wiring, runtime/editor inspection and testing.
3. Ordinary text editing for new files, configuration/data/docs, bulk generated content, or cases where semantic tooling is not applicable.

Do not read/rewrite an entire large GDScript file merely to change one method when Serena can target that symbol safely.

Serena depends on Godot's live GDScript LSP. If semantic tools fail, first verify Godot/LSP status rather than falling back immediately to blind whole-file edits.

## Voxel Tools policy

Voxel Tools is pinned as a first implementation route, not allowed to become the only authoritative world representation.

Black Island gameplay/save code must remain behind project-owned interfaces such as terrain query/edit/stream/persistence adapters.

The GDExtension release is preferred for the first prototype because it avoids maintaining a custom engine build. Its upstream release explicitly carries lower testing confidence than module builds, so Android/iOS/editor/export behavior must be validated in practice before it becomes a release dependency.

Never silently replace the pinned release with `latest`.

## Environment vs repository state

Do not commit:

- `.tools/` downloads/caches;
- Godot import cache;
- machine-local logs;
- machine-specific absolute MCP paths;
- secrets/API keys.

The repository commits portable launchers and pins; each workspace recreates its local tools.

## Validation rules

S01-P00 must record actual pass/fail evidence in `harness/build/S01-P00.md` for:

- Godot exact version;
- project headless import/open;
- Godot MCP server + editor bridge status;
- Serena GDScript symbolic query against a real `.gd` file once one exists;
- Voxel Tools class/addon load in Godot;
- Git clean/diff state before checkpoint;
- Android/iOS feasibility separately from actual device proof.

Desktop/headless success is never described as mobile-performance proof.
