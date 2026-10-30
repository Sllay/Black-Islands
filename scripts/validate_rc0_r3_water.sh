#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/tooling/versions.env
[[ "$(.tools/bin/godot --version)" == "$GODOT_VERSION".* ]]
case "${1:-all}" in
 a) scenes=(Rc0R3WaterA) ;;
 b) scenes=(Rc0R3WaterB) ;;
 c) scenes=(Rc0R3WaterC) ;;
 all) scenes=(Rc0R3WaterA Rc0R3WaterB Rc0R3WaterC) ;;
 *) echo 'Usage: validate_rc0_r3_water.sh [a|b|c|all]' >&2; exit 2 ;;
esac
mkdir -p .tools/logs
for scene in "${scenes[@]}"; do
 log=".tools/logs/r3-$scene.log"
 if ! timeout 90 .tools/bin/godot --headless --max-fps 60 --path game "res://tests/integration/$scene.tscn" >"$log" 2>&1; then
  tail -n 30 "$log"; exit 1
 fi
 if rg -n 'SCRIPT ERROR|(^|[[:space:]])ERROR:|^WARNING:' "$log"; then exit 1; fi
 rg -q 'PASS failures=0' "$log"
 echo "PASS $scene"
done
git diff --check
