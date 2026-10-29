#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
bash scripts/validate_p03.sh
godot_p04_bin="$PWD/.tools/bin/godot"
for scene in SurfaceC01Smoke SurfaceC02Smoke SurfaceC03Smoke SurfaceIntegratedSmoke; do
  log=".tools/logs/p04-${scene}.log"
  if ! timeout 240 "$godot_p04_bin" --headless --max-fps 60 --path game "res://tests/integration/$scene.tscn" >"$log" 2>&1; then
    tail -n 35 "$log" >&2
    exit 1
  fi
  if rg -n 'SCRIPT ERROR|Parse Error|(^|[[:space:]])ERROR:|^WARNING:' "$log"; then
    exit 1
  fi
  rg -q 'PASS' "$log"
  echo "PASS $scene"
done
echo 'PASS P04 headless gate; rendered/mobile evidence is separate'
