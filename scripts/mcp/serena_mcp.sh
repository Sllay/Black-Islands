#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

bash "$ROOT/scripts/bootstrap_codex_env.sh" --mcp-only >&2
export PATH="$ROOT/.tools/bin:$ROOT/.tools/node/bin:$HOME/.local/bin:$PATH"
export GODOT_PATH="$(readlink -f "$ROOT/.tools/bin/godot" 2>/dev/null || echo "$ROOT/.tools/bin/godot")"

port_open() {
  timeout 1 bash -c '</dev/tcp/127.0.0.1/6008' >/dev/null 2>&1
}

# Serena's GDScript backend connects to Godot's built-in TCP LSP on port 6008.
# If no editor is already serving it, start a lightweight headless editor for this workspace.
if ! port_open; then
  mkdir -p "$ROOT/.tools/logs"
  "$GODOT_PATH" --headless --editor --path "$ROOT/game" \
    >"$ROOT/.tools/logs/serena-godot-lsp.log" 2>&1 &
  echo $! > "$ROOT/.tools/serena-godot-lsp.pid"

  ready=false
  for _ in $(seq 1 80); do
    if port_open; then
      ready=true
      break
    fi
    sleep 0.25
  done
  if [[ "$ready" != true ]]; then
    echo "Godot GDScript LSP did not become available on 127.0.0.1:6008." >&2
    echo "See $ROOT/.tools/logs/serena-godot-lsp.log" >&2
    exit 1
  fi
fi

exec "$ROOT/.tools/bin/serena" start-mcp-server \
  --context=codex \
  --project "$ROOT/game" \
  --open-web-dashboard False
