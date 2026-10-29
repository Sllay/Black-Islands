#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
python3 scripts/lpc/compile_slice.py "$@"
.tools/bin/godot --headless --path game --import -- --godot-mcp-no-bridge
.tools/bin/godot --headless --path game --script ../scripts/lpc/bake_catalog.gd
