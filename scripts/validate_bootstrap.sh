#!/usr/bin/env bash
set -euo pipefail

# Run after bootstrap_codex_env.sh and validate_mcp.mjs --install-addon.
# This is a Linux desktop/headless capability gate, not a mobile benchmark.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source scripts/tooling/versions.env
export PATH="$ROOT/.tools/bin:$PATH"
GODOT="$ROOT/.tools/bin/godot"
LOGS="$ROOT/.tools/logs"
mkdir -p "$LOGS"

mapfile -t descriptors < <(rg --files --hidden --no-ignore -g project.godot -g '!.tools/**' -g '!.git/**')
[[ "${#descriptors[@]}" == 1 && "${descriptors[0]}" == game/project.godot ]]
echo 'PASS repository boundary: game/project.godot is the only project descriptor'

version="$("$GODOT" --version)"
[[ "$version" == "$GODOT_VERSION".* ]]
node -e 'if (Number(process.versions.node.split(".")[0]) < 22) process.exit(1)'
serena_version="$(serena --version)"
[[ "$serena_version" == "Serena $SERENA_VERSION" || "$serena_version" == "Serena $SERENA_VERSION-"* ]]
echo "PASS versions: Godot $version; Node $(node --version); $serena_version; $(git --version)"

case "$(uname -m)" in
  x86_64|amd64) godot_arch=x86_64; godot_sha="$GODOT_LINUX_X86_64_SHA256" ;;
  aarch64|arm64) godot_arch=arm64; godot_sha="$GODOT_LINUX_ARM64_SHA256" ;;
  *) echo 'Unsupported validation architecture' >&2; exit 1 ;;
esac
printf '%s  %s\n' "$godot_sha" ".tools/cache/Godot_v${GODOT_VERSION}-stable_linux.${godot_arch}.zip" | sha256sum --check --status
printf '%s  %s\n' "$VOXEL_TOOLS_SHA256" ".tools/cache/GodotVoxelExtension-${VOXEL_TOOLS_TAG}.zip" | sha256sum --check --status
echo 'PASS pinned Godot and Voxel Tools archive SHA-256'

run_check() {
  local name="$1"
  shift
  local log="$LOGS/$name.log"
  if ! timeout 120 "$@" >"$log" 2>&1; then
    tail -n 40 "$log" >&2
    echo "FAIL $name (see .tools/logs/$name.log)" >&2
    return 1
  fi
  if rg -n 'SCRIPT ERROR|Parse Error|(^|[[:space:]])ERROR:' "$log"; then
    echo "FAIL $name: engine errors in .tools/logs/$name.log" >&2
    return 1
  fi
  echo "PASS $name"
}

# Suppress only this development addon's bridge for short-lived editor opens;
# do not replace the session file of an already-open live editor.
run_check p00-import "$GODOT" --headless --path "$ROOT/game" --import -- --godot-mcp-no-bridge
run_check p00-editor-smoke "$GODOT" --headless --editor --path "$ROOT/game" --quit-after 10 -- --godot-mcp-no-bridge
run_check p00-voxel "$GODOT" --headless --path "$ROOT/game" --script res://tests/integration/voxel_capability_probe.gd
git diff --check
echo 'PASS diff whitespace check; no gameplay or mobile-export result is implied'
