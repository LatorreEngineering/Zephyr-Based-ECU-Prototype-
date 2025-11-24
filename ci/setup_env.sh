#!/usr/bin/env bash
set -euo pipefail

# Stable workspace root independent of repo name
WS_ROOT="/home/runner/work/ws"
mkdir -p "$WS_ROOT"

PROJECT_ROOT="$GITHUB_WORKSPACE"
WORKSPACE_DIR="$WS_ROOT/zephyr-workspace"

PATCH="$PROJECT_ROOT/manifests/patch_pinned_manifest.sh"
PINNED="$PROJECT_ROOT/manifests/pinned_manifest.xml"

echo "[INFO] Workspace root: $WORKSPACE_DIR"
mkdir -p "$WORKSPACE_DIR"

# Ensure west exists
python3 -m pip install --upgrade west

# Initialize west in a clean neutral path
cd "$WORKSPACE_DIR"
west init -l "$PROJECT_ROOT"

# Fetch Zephyr
west update --narrow --fetch-opt=--depth=1

# Read Zephyr SHA
SHA=$(git -C "$WORKSPACE_DIR/zephyr" rev-parse HEAD)
echo "$SHA" > "$PROJECT_ROOT/zephyr_sha.txt"

# Patch manifest
chmod +x "$PATCH"
ZEPHYR_SHA="$SHA" "$PATCH"

# Sync workspace to pinned manifest
west config manifest.file "$PINNED"
west update --narrow --fetch-opt=--depth=1
west zephyr-export

# Create .env.ci
cat > "$PROJECT_ROOT/.env.ci" <<EOF
export ZEPHYR_BASE="$WORKSPACE_DIR/zephyr"
export WORKSPACE_DIR="$WORKSPACE_DIR"
export PROJECT_ROOT="$PROJECT_ROOT"
EOF

echo "[INFO] Setup completed successfully."

