#!/usr/bin/env bash
set -euo pipefail

# Paths
PROJECT_ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$PROJECT_ROOT/zephyr-workspace}"

PATCH="$PROJECT_ROOT/manifests/patch_pinned_manifest.sh"
PINNED="$PROJECT_ROOT/manifests/pinned_manifest.xml"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Ensure dependencies
command -v python3 >/dev/null || { err "python3 missing"; exit 1; }
command -v pip >/dev/null || { err "pip missing"; exit 1; }
command -v west >/dev/null || python3 -m pip install --upgrade west lxml pyelftools cantools pyyaml intelhex pyserial pytest

# Create workspace
mkdir -p "$WORKSPACE_DIR"
cd "$WORKSPACE_DIR"

# Initialize west workspace using project repo
west init -l "$PROJECT_ROOT"

# Fetch Zephyr branch (shallow)
west update --narrow --fetch-opt=--depth=1

# Extract SHA
SHA=$(git -C "$WORKSPACE_DIR/zephyr" rev-parse HEAD)
echo "$SHA" > "$PROJECT_ROOT/zephyr_sha.txt"
log "Resolved Zephyr SHA: $SHA"

# Patch pinned manifest
chmod +x "$PATCH"
ZEPHYR_SHA="$SHA" "$PATCH"

# Sync workspace to pinned manifest
west config manifest.file "$PINNED"
west update --narrow --fetch-opt=--depth=1
west zephyr-export

# Generate .env.ci
cat > "$PROJECT_ROOT/.env.ci" <<EOF
export ZEPHYR_BASE="$WORKSPACE_DIR/zephyr"
export WORKSPACE_DIR="$WORKSPACE_DIR"
export PROJECT_ROOT="$PROJECT_ROOT"
EOF

log "Setup complete"
