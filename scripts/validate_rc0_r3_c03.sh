#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tools/logs
bash scripts/validate_content.sh
.tools/bin/godot --headless --path game --script res://tests/integration/rc0_r3_content_a.gd
for scene in Rc0R3ContentB Rc0R3ContentC; do
 log=".tools/logs/c03-${scene}.log"
 timeout 60 .tools/bin/godot --headless --max-fps 60 --path game "res://tests/integration/${scene}.tscn" >"$log" 2>&1
 if rg -q '^ERROR:|SCRIPT ERROR:|^WARNING:' "$log"; then cat "$log"; exit 1; fi
 rg 'PASS|FAIL' "$log"
done
git diff --check
