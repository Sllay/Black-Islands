#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

bash "$ROOT/scripts/bootstrap_codex_env.sh" --mcp-only >&2
# shellcheck disable=SC1091
source "$ROOT/scripts/tooling/versions.env"

export PATH="$ROOT/.tools/bin:$ROOT/.tools/node/bin:$HOME/.local/bin:$PATH"
export GODOT_PATH="$(readlink -f "$ROOT/.tools/bin/godot" 2>/dev/null || echo "$ROOT/.tools/bin/godot")"

exec "$ROOT/.tools/bin/npx" -y "${GODOT_MCP_PACKAGE}@${GODOT_MCP_VERSION}" \
  --project "$ROOT/game" \
  --mode compact
