#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Compatibility entry point: runtime dependencies come from Git, not bootstrap.
python3 scripts/verify_runtime_dependencies.py
