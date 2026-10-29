#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/tooling/versions.env
archive=".tools/cache/limboai-v${LIMBOAI_VERSION}-gdextension-4.6.zip"
mkdir -p .tools/cache
if [[ ! -f "$archive" ]]; then
  curl -fL --retry 3 "$LIMBOAI_URL" -o "$archive"
fi
printf '%s  %s\n' "$LIMBOAI_SHA256" "$archive" | sha256sum --check --status
unzip -oq "$archive" 'addons/limboai/*' -d game
echo "LimboAI $LIMBOAI_VERSION installed from $LIMBOAI_ARTIFACT (SHA-256 verified)"
