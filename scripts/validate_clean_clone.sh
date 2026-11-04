#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_PATH:-$root/.tools/bin/godot}"
godot_bin="$(readlink -f "$godot_bin")"
mkdir -p "$root/.tools/logs"
checkout="$(mktemp -d "$root/.tools/clean-runtime.XXXXXX")"
git clone --quiet --no-hardlinks --single-branch --branch "$(git -C "$root" branch --show-current)" "$root" "$checkout"
test ! -e "$checkout/game/addons/godot_mcp"
test ! -e "$checkout/game/.godot"
test ! -e "$checkout/.tools"
python3 "$checkout/scripts/verify_runtime_dependencies.py"
export XDG_DATA_HOME="$checkout/.test-userdata"
export XDG_CONFIG_HOME="$checkout/.test-config"
"$godot_bin" --version
"$godot_bin" --headless --editor --path "$checkout/game" --import > "$root/.tools/logs/c04-clean-import.log" 2>&1
"$godot_bin" --headless --path "$checkout/game" --script res://tests/integration/runtime_dependency_smoke.gd > "$root/.tools/logs/c04-clean-boot.log" 2>&1
if rg -n 'SCRIPT ERROR:|^ERROR:|^WARNING:' "$root/.tools/logs/c04-clean-import.log" "$root/.tools/logs/c04-clean-boot.log"; then exit 1; fi
cat "$root/.tools/logs/c04-clean-boot.log"
echo "CLEAN_CLONE PASS: Git files only; no bootstrap, no network access used; checkout $checkout"
