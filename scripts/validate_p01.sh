#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT="$ROOT/.tools/bin/godot"
mkdir -p .tools/logs
[[ "$("$GODOT" --version)" == 4.7.2.* ]]

check() {
  local name="$1"
  shift
  if ! timeout 60 "$@" >".tools/logs/$name.log" 2>&1; then
    tail -n 35 ".tools/logs/$name.log" >&2
    exit 1
  fi
  if rg -n 'SCRIPT ERROR|Parse Error|(^|[[:space:]])ERROR:' ".tools/logs/$name.log"; then
    exit 1
  fi
  echo "PASS $name"
}

check p01-import "$GODOT" --headless --path game --import -- --godot-mcp-no-bridge
# A normal scene entrypoint is intentional: standalone --script does not expose
# the production autoload globals to the test controller's compiler.
check p01-smoke "$GODOT" --headless --path game res://tests/integration/P01Smoke.tscn
rg -q 'P01_SMOKE PASS failures=0' .tools/logs/p01-smoke.log
check p01-voxel-regression "$GODOT" --headless --path game --script res://tests/integration/voxel_capability_probe.gd
echo 'PASS P01 headless gate (device/visual proof is recorded separately)'
