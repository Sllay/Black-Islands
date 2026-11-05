#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT_PATH:-.tools/bin/godot}"
[[ "$("$godot_bin" --version)" == 4.7.2.* ]]
python3 scripts/verify_runtime_dependencies.py
mkdir -p .tools/logs
for checkpoint in A B C; do
 log=".tools/logs/c04-gate-$checkpoint.log"
 timeout 45 "$godot_bin" --headless --path game "res://tests/integration/Rc0R3WorldCore$checkpoint.tscn" > "$log" 2>&1
 if rg -q 'SCRIPT ERROR:|^ERROR:|^WARNING:' "$log"; then cat "$log"; exit 1; fi
 rg "WORLD_CORE_$checkpoint PASS" "$log"
done
git diff --check
