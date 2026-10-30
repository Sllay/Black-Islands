#!/usr/bin/env bash
# Actual display/backend required; never accepts automatic GL fallback as Vulkan.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
backend="${1:-gl_compatibility}"
case "$backend" in
 gl_compatibility) driver=opengl3; quality=Low ;;
 mobile) driver=vulkan; quality=Medium ;;
 forward_plus) driver=vulkan; quality=High ;;
 *) echo 'Usage: water_renderer_smoke.sh [gl_compatibility|mobile|forward_plus]' >&2; exit 2 ;;
esac
[[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || { echo 'Display required' >&2; exit 2; }
mkdir -p .tools/logs harness/evidence/rc0-r3-water
log=".tools/logs/r3-renderer-$backend.log"
if ! R3_WATER_QUALITY="$quality" R3_WATER_CAPTURE="res://../harness/evidence/rc0-r3-water/$backend-$quality.png" timeout 100 .tools/bin/godot --path game --audio-driver Dummy --rendering-method "$backend" --rendering-driver "$driver" res://tests/integration/Rc0R3WaterC.tscn >"$log" 2>&1; then
 tail -n 30 "$log"; exit 1
fi
if rg -n 'SCRIPT ERROR|(^|[[:space:]])ERROR:' "$log"; then exit 1; fi
if rg '^WARNING:' "$log" | rg -v 'Could not set V-Sync mode'; then exit 1; fi
rg -q 'R3_WATER_C PASS failures=0 rendering_method='"$backend" "$log"
echo "PASS water renderer $backend / $quality; DESKTOP PROXY ONLY"
