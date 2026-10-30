#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/tooling/versions.env
[[ "$(.tools/bin/godot --version)" == "$GODOT_VERSION".* ]]
checkpoint="${1:-all}"
case "$checkpoint" in
 c01) scenes=(Rc0R2C01Smoke) ;;
 c02) scenes=(Rc0R2C02Smoke) ;;
 c03) scenes=(Rc0R2C03Smoke) ;;
 c04) scenes=(Rc0R2C04Smoke) ;;
 all) scenes=(Rc0R2C01Smoke Rc0R2C02Smoke Rc0R2C03Smoke Rc0R2C04Smoke Rc0C01Smoke Rc0C02Smoke Rc0C03Smoke PlayerC03Smoke) ;;
 *) echo 'Usage: validate_rc0_r2.sh [c01|c02|c03|c04|all]' >&2; exit 2 ;;
esac
mkdir -p .tools/logs
for scene in "${scenes[@]}"; do
 log=".tools/logs/rc0-r2-$scene.log"
 if ! timeout 90 .tools/bin/godot --headless --max-fps 60 --path game "res://tests/integration/$scene.tscn" --quit-after 3600 >"$log" 2>&1; then
  tail -n 35 "$log" >&2
  exit 1
 fi
 if rg -n 'SCRIPT ERROR|Parse Error|(^|[[:space:]])ERROR:|^WARNING:' "$log"; then exit 1; fi
 rg -q 'PASS failures=0' "$log"
 echo "PASS $scene"
done
git diff --check
echo "PASS RC0-R2 $checkpoint focused gate; renderer/device evidence separate"
