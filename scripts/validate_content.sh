#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
.tools/bin/godot --headless --path game --script res://scripts/content/validate_content.gd
