#!/usr/bin/env bash
# =============================================================================
# patch_pinned_manifest.sh
# -----------------------------------------------------------------------------
# Patches the pinned_manifest.xml with a specific Zephyr commit SHA.
# Can take SHA from environment variable ZEPHYR_SHA or from zephyr_sha.txt.
# =============================================================================
set -euo pipefail

MANIFEST_FILE="manifests/pinned_manifest.xml"

# ---------------------------------------------------------------------------
# Get Zephyr SHA
# ---------------------------------------------------------------------------
if [ -n "${ZEPHYR_SHA:-}" ]; then
    SHA="$ZEPHYR_SHA"
elif [ -f zephyr_sha.txt ]; then
    SHA=$(<zephyr_sha.txt)
else
    echo "[ERROR] Zephyr SHA not provided. Set ZEPHYR_SHA or create zephyr_sha.txt"
    exit 1
fi

# Remove whitespace and validate SHA
SHA=$(echo "$SHA" | tr -d '[:space:]')
if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
    echo "[ERROR] Invalid Zephyr SHA: '$SHA'"
    exit 1
fi

# ---------------------------------------------------------------------------
# Check manifest exists
# ---------------------------------------------------------------------------
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "[ERROR] Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

# ---------------------------------------------------------------------------
# Patch manifest safely
# ---------------------------------------------------------------------------
echo "[INFO] Patching $MANIFEST_FILE with Zephyr SHA: $SHA"

# Use '@' as delimiter to avoid conflicts with slashes
sed -i "s@revision=\"[^\"]*\"@revision=\"$SHA\"@" "$MANIFEST_FILE"

echo "[INFO] Patched $MANIFEST_FILE successfully"
