#!/usr/bin/env bash
# A windowed test: headless/dummy or automatic GL fallback is not a backend pass.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
backend="${1:-gl_compatibility}"
case "$backend" in
 mobile|forward_plus) driver=vulkan ;;
 gl_compatibility) driver=opengl3 ;;
 *) echo 'Usage: renderer_smoke.sh [mobile|forward_plus|gl_compatibility]' >&2; exit 2 ;;
esac
[[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || { echo 'A display is required (Xvfb is supported).' >&2; exit 2; }
mkdir -p .tools/logs
log=".tools/logs/rc0-r2-renderer-$backend.log"
if ! timeout 120 .tools/bin/godot --path game --audio-driver Dummy --rendering-method "$backend" --rendering-driver "$driver" res://tests/integration/Rc0R2C04Smoke.tscn >"$log" 2>&1; then
 tail -n 30 "$log" >&2; exit 1
fi
if rg -n 'SCRIPT ERROR|(^|[[:space:]])ERROR:' "$log"; then exit 1; fi
if rg '^WARNING:' "$log" | rg -v 'Could not set V-Sync mode'; then exit 1; fi
rg -q 'RC0_R2_C04 PASS failures=0' "$log"
rg -q '"rendering_method":"'"$backend"'"' "$log"
echo "PASS actual renderer $backend; DESKTOP PROXY ONLY"
