#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
bash scripts/validate_p02.sh
godot_p03_bin="$PWD/.tools/bin/godot"
for scene in PlayerC01Smoke PlayerC02Smoke PlayerC03Smoke PlayerSaveSmoke PlayerWorldSmoke; do
  log=".tools/logs/p03-${scene}.log"
  if ! timeout 180 "$godot_p03_bin" --headless --max-fps 60 --path game "res://tests/integration/$scene.tscn" >"$log" 2>&1; then
    tail -n 35 "$log" >&2
    exit 1
  fi
  if rg -n 'SCRIPT ERROR|Parse Error|(^|[[:space:]])ERROR:|^WARNING:' "$log"; then
    exit 1
  fi
  rg -q 'PASS' "$log"
  echo "PASS $scene"
done
echo 'PASS P03 headless gate; MCP/rendered/mobile evidence is separate'
