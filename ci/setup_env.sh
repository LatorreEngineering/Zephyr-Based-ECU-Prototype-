#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Starting setup_env.sh"

# Detect project root absolutely, no assumptions:
PROJECT_ROOT="$(pwd)"
echo "[INFO] PROJECT_ROOT = $PROJECT_ROOT"

# Stable neutral workspace path
WS_ROOT="/home/runner/work/ws"
WORKSPACE_DIR="$WS_ROOT/zephyr-workspace"
mkdir -p "$WORKSPACE_DIR"

echo "[INFO] Workspace: $WORKSPACE_DIR"

# Ensure west is installed
python3 -m pip install --user --upgrade west

# --- Clean workspace to prevent reuse of wrong west states ---
if [ -d "$WORKSPACE_DIR/.west" ]; then
  echo "[INFO] Cleaning old workspace"
  rm -rf "$WORKSPACE_DIR/.west"
fi
rm -rf "$WORKSPACE_DIR/zephyr" || true

# --- Perform west init ---
echo "[INFO] Running west init"
cd "$WORKSPACE_DIR"
west init -l "$PROJECT_ROOT"

# --- Update ---
echo "[INFO] Running west update"
west update --narrow --fetch-opt=--depth=1

# --- Determine Zephyr SHA ---
ZEPHYR_SHA="$(git -C "$WORKSPACE_DIR/zephyr" rev-parse HEAD)"
echo "$ZEPHYR_SHA" > "$PROJECT_ROOT/zephyr_sha.txt"
echo "[INFO] ZEPHYR_SHA = $ZEPHYR_SHA"

# --- Patch pinned manifest ---
echo "[INFO] Patching manifest"
PATCH="$PROJECT_ROOT/manifests/patch_pinned_manifest.sh"
chmod +x "$PATCH"
ZEPHYR_SHA="$ZEPHYR_SHA" "$PATCH"

# --- Apply new manifest configuration ---
west config manifest.file "$PROJECT_ROOT/manifests/pinned_manifest.xml"
west update --narrow --fetch-opt=--depth=1

# --- Export environment ---
echo "[INFO] Creating .env.ci"
cat > "$PROJECT_ROOT/.env.ci" <<EOF
export PROJECT_ROOT="$PROJECT_ROOT"
export WORKSPACE_DIR="$WORKSPACE_DIR"
export ZEPHYR_BASE="$WORKSPACE_DIR/zephyr"
EOF

echo "[INFO] setup_env.sh completed successfully."
