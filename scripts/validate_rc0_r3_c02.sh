#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tools/logs
for scene in Rc0R3InventoryA Rc0R3Craft Rc0R3InventorySave Rc0R3InventoryFuzz; do
  log=".tools/logs/c02-${scene}.log"
  timeout 90 .tools/bin/godot --headless --max-fps 60 --path game "res://tests/integration/${scene}.tscn" >"$log" 2>&1
  if rg -q 'SCRIPT ERROR:|^ERROR:|^WARNING:' "$log"; then cat "$log"; exit 1; fi
  rg 'PASS|PERF' "$log"
done
if [[ "${1:-}" == "--gestures" ]]; then
  log=.tools/logs/c02-gestures.log
  timeout 45 .tools/bin/godot --audio-driver Dummy --path game res://tests/integration/Rc0R3InventoryUX.tscn -- --auto >"$log" 2>&1
  if rg -q 'SCRIPT ERROR:|^ERROR:' "$log"; then cat "$log"; exit 1; fi
  rg 'PASS' "$log"
fi
git diff --check
