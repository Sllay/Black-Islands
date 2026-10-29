#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT="$ROOT/.tools/bin/godot"
mkdir -p .tools/logs
bash scripts/validate_p01.sh

check() {
  local name="$1"
  shift
  if ! timeout 180 "$GODOT" --headless --max-fps 60 --path game "$@" >".tools/logs/$name.log" 2>&1; then
    tail -n 35 ".tools/logs/$name.log" >&2
    exit 1
  fi
  if rg -n 'SCRIPT ERROR|Parse Error|(^|[[:space:]])ERROR:' ".tools/logs/$name.log"; then
    exit 1
  fi
  echo "PASS $name"
}

check p02-coordinates --script res://tests/integration/world_coordinate_probe.gd
check p02-foundation res://tests/integration/WorldFoundationSmoke.tscn
check p02-state res://tests/integration/WorldStateSmoke.tscn
check p02-native res://tests/integration/NativeTerrainSmoke.tscn
check p02-persistence res://tests/integration/WorldPersistenceSmoke.tscn
echo 'PASS P02 automated gate (rendered MCP/device evidence is separate)'
