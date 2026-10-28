#!/usr/bin/env bash
set -euo pipefail

# Black Island reproducible Codex/Linux development bootstrap.
# Installs local tooling without requiring root and without silently changing pinned versions.
# Usage:
#   bash scripts/bootstrap_codex_env.sh            # full setup, including Voxel Tools
#   bash scripts/bootstrap_codex_env.sh --mcp-only # MCP prerequisites only; skips Voxel Tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/tooling/versions.env"

MODE="${1:-full}"
if [[ "$MODE" != "full" && "$MODE" != "--mcp-only" ]]; then
  echo "Usage: $0 [--mcp-only]" >&2
  exit 2
fi

TOOLS="$ROOT/.tools"
CACHE="$TOOLS/cache"
BIN="$TOOLS/bin"
LOGS="$TOOLS/logs"
mkdir -p "$CACHE" "$BIN" "$LOGS"

# Prevent the Godot and Serena MCP wrappers from racing the same bootstrap.
if command -v flock >/dev/null 2>&1; then
  exec 9>"$TOOLS/bootstrap.lock"
  flock 9
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required host command: $1" >&2
    exit 1
  }
}

fetch() {
  local url="$1"
  local out="$2"
  if [[ -f "$out" ]]; then
    return 0
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --retry-delay 2 "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$out" "$url"
  else
    echo "curl or wget is required for bootstrap downloads." >&2
    exit 1
  fi
}

verify_sha256() {
  local file="$1"
  local expected="$2"
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  else
    echo "sha256sum or shasum is required." >&2
    exit 1
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "SHA-256 mismatch for $file" >&2
    echo "expected: $expected" >&2
    echo "actual:   $actual" >&2
    exit 1
  fi
}

platform="$(uname -s)"
arch="$(uname -m)"

# ---- Node.js 22 ------------------------------------------------------------
node_ok=false
if command -v node >/dev/null 2>&1; then
  node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [[ "$node_major" -ge 22 ]]; then
    node_ok=true
  fi
fi

if [[ "$node_ok" == false ]]; then
  if [[ "$platform" != "Linux" ]]; then
    echo "Node.js >=22 is required. Automatic local installation is currently Linux-only." >&2
    exit 1
  fi
  case "$arch" in
    x86_64|amd64) node_arch="x64" ;;
    aarch64|arm64) node_arch="arm64" ;;
    *) echo "Unsupported Linux architecture for local Node install: $arch" >&2; exit 1 ;;
  esac

  need_cmd tar
  NODE_DIR="$TOOLS/node"
  NODE_ARCHIVE="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"
  NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ARCHIVE}"
  NODE_SHASUMS="$CACHE/node-v${NODE_VERSION}-SHASUMS256.txt"
  fetch "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" "$NODE_SHASUMS"
  fetch "$NODE_URL" "$CACHE/$NODE_ARCHIVE"
  expected_node_sha="$(awk -v f="$NODE_ARCHIVE" '$2 == f {print $1}' "$NODE_SHASUMS")"
  if [[ -z "$expected_node_sha" ]]; then
    echo "Could not resolve official checksum for $NODE_ARCHIVE" >&2
    exit 1
  fi
  verify_sha256 "$CACHE/$NODE_ARCHIVE" "$expected_node_sha"
  rm -rf "$NODE_DIR"
  mkdir -p "$NODE_DIR"
  tar -xJf "$CACHE/$NODE_ARCHIVE" --strip-components=1 -C "$NODE_DIR"
  export PATH="$NODE_DIR/bin:$PATH"
fi

# Always expose a deterministic repo-local entry point for wrappers.
# Resolve existing repo-local links before replacing them on repeated runs.
# Otherwise a PATH already containing .tools/bin produces self-referencing links.
ln -sf "$(readlink -f "$(command -v node)")" "$BIN/node"
ln -sf "$(readlink -f "$(command -v npm)")" "$BIN/npm"
ln -sf "$(readlink -f "$(command -v npx)")" "$BIN/npx"
export PATH="$BIN:${TOOLS}/node/bin:${HOME}/.local/bin:$PATH"

node_major="$(node -p 'process.versions.node.split(".")[0]')"
if [[ "$node_major" -lt 22 ]]; then
  echo "Node.js 22+ verification failed: $(node --version)" >&2
  exit 1
fi

# ---- uv + Serena -----------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
  UV_INSTALL_DIR="$TOOLS/uv/bin"
  mkdir -p "$UV_INSTALL_DIR"
  installer="$CACHE/uv-install.sh"
  fetch "https://astral.sh/uv/install.sh" "$installer"
  UV_INSTALL_DIR="$UV_INSTALL_DIR" sh "$installer"
  export PATH="$UV_INSTALL_DIR:$PATH"
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv installation failed." >&2
  exit 1
fi

export UV_TOOL_DIR="$TOOLS/uv-tools"
export UV_TOOL_BIN_DIR="$BIN"
export UV_PYTHON_INSTALL_DIR="$TOOLS/uv-python"

serena_version=""
if [[ -x "$BIN/serena" ]]; then
  serena_version="$($BIN/serena --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
fi
if [[ "$serena_version" != "$SERENA_VERSION" ]]; then
  uv tool install --python 3.13 --force "${SERENA_PACKAGE}==${SERENA_VERSION}"
fi

if [[ ! -x "$BIN/serena" ]]; then
  echo "Pinned Serena executable was not installed at $BIN/serena" >&2
  exit 1
fi

# ---- Godot 4.7.2 -----------------------------------------------------------
GODOT_DIR="$TOOLS/godot/$GODOT_VERSION"
mkdir -p "$GODOT_DIR"

if [[ "$platform" == "Linux" ]]; then
  case "$arch" in
    x86_64|amd64)
      GODOT_URL="$GODOT_LINUX_X86_64_URL"
      GODOT_SHA="$GODOT_LINUX_X86_64_SHA256"
      GODOT_ARCHIVE="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
      GODOT_EXE_NAME="Godot_v${GODOT_VERSION}-stable_linux.x86_64"
      ;;
    aarch64|arm64)
      GODOT_URL="$GODOT_LINUX_ARM64_URL"
      GODOT_SHA="$GODOT_LINUX_ARM64_SHA256"
      GODOT_ARCHIVE="Godot_v${GODOT_VERSION}-stable_linux.arm64.zip"
      GODOT_EXE_NAME="Godot_v${GODOT_VERSION}-stable_linux.arm64"
      ;;
    *) echo "Unsupported Linux architecture for Godot bootstrap: $arch" >&2; exit 1 ;;
  esac

  GODOT_BIN="$GODOT_DIR/$GODOT_EXE_NAME"
  if [[ ! -x "$GODOT_BIN" ]]; then
    need_cmd unzip
    fetch "$GODOT_URL" "$CACHE/$GODOT_ARCHIVE"
    verify_sha256 "$CACHE/$GODOT_ARCHIVE" "$GODOT_SHA"
    rm -rf "$GODOT_DIR"
    mkdir -p "$GODOT_DIR"
    unzip -q -o "$CACHE/$GODOT_ARCHIVE" -d "$GODOT_DIR"
    chmod +x "$GODOT_BIN"
  fi
else
  # Codex cloud is expected to be Linux. On another host, accept only an already-installed exact Godot.
  GODOT_BIN="$(command -v godot || command -v godot4 || true)"
  if [[ -z "$GODOT_BIN" ]]; then
    echo "Automatic Godot installation is Linux-only. Install exact Godot $GODOT_VERSION and rerun." >&2
    exit 1
  fi
fi

export GODOT_PATH="$GODOT_BIN"
ln -sf "$GODOT_BIN" "$BIN/godot"

godot_version_output="$($GODOT_BIN --version 2>/dev/null || true)"
if [[ "$godot_version_output" != ${GODOT_VERSION}* ]]; then
  echo "Expected Godot $GODOT_VERSION, got: $godot_version_output" >&2
  exit 1
fi

# MCP startup only needs Node, Serena and Godot. The full bootstrap also installs the voxel runtime dependency.
if [[ "$MODE" == "--mcp-only" ]]; then
  echo "Black Island MCP prerequisites ready."
  echo "Godot: $godot_version_output"
  echo "Node:  $(node --version)"
  echo "Serena: $($BIN/serena --version 2>/dev/null || echo $SERENA_VERSION)"
  exit 0
fi

# ---- Voxel Tools GDExtension 1.7 ------------------------------------------
VOXEL_ARCHIVE="$CACHE/GodotVoxelExtension-${VOXEL_TOOLS_TAG}.zip"
VOXEL_STAMP="$TOOLS/voxel-tools-${VOXEL_TOOLS_TAG}.installed"

if [[ ! -f "$VOXEL_STAMP" ]]; then
  need_cmd unzip
  fetch "$VOXEL_TOOLS_URL" "$VOXEL_ARCHIVE"
  verify_sha256 "$VOXEL_ARCHIVE" "$VOXEL_TOOLS_SHA256"

  tmp="$TOOLS/voxel-install-tmp"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  unzip -q -o "$VOXEL_ARCHIVE" -d "$tmp"

  if [[ ! -d "$tmp/addons" ]]; then
    echo "Unexpected Voxel Tools archive layout: addons/ not found." >&2
    exit 1
  fi

  mkdir -p "$ROOT/game/addons"
  cp -a "$tmp/addons/." "$ROOT/game/addons/"
  rm -rf "$tmp"
  printf '%s\n' "$VOXEL_TOOLS_SHA256" > "$VOXEL_STAMP"
fi

# ---- Basic validation -------------------------------------------------------
if [[ ! -f "$ROOT/game/project.godot" ]]; then
  echo "game/project.godot is missing." >&2
  exit 1
fi

# --import waits for the initial import to finish; a fixed frame count can quit
# while the first scan/import is still running.
"$GODOT_BIN" --headless --path "$ROOT/game" --import -- --godot-mcp-no-bridge >"$LOGS/godot-bootstrap.log" 2>&1 || {
  echo "Godot headless editor validation failed. See $LOGS/godot-bootstrap.log" >&2
  cat "$LOGS/godot-bootstrap.log" >&2
  exit 1
}

echo "Black Island Codex environment ready."
echo "Godot:      $godot_version_output"
echo "Node:       $(node --version)"
echo "Serena:     $($BIN/serena --version 2>/dev/null || echo $SERENA_VERSION)"
echo "Godot MCP:  $GODOT_MCP_VERSION (started by Codex MCP wrapper)"
echo "VoxelTools: $VOXEL_TOOLS_VERSION / $VOXEL_TOOLS_TAG"
echo "Project:    $ROOT/game"
