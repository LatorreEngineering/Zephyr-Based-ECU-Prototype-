#!/usr/bin/env bash
set -euo pipefail

MANIFEST_FILE="manifests/pinned_manifest.xml"

# -------------------------------------------------------------------
# Get SHA from environment variable or file
# -------------------------------------------------------------------
if [[ -n "${ZEPHYR_SHA:-}" ]]; then
    SHA="$ZEPHYR_SHA"
elif [[ -f zephyr_sha.txt ]]; then
    SHA=$(<zephyr_sha.txt)
else
    echo "[ERROR] Zephyr SHA not provided. Set ZEPHYR_SHA or create zephyr_sha.txt"
    exit 1
fi

# Remove whitespace
SHA=$(echo "$SHA" | tr -d '[:space:]')
if [[ -z "$SHA" ]]; then
    echo "[ERROR] SHA is empty after trimming"
    exit 1
fi

# -------------------------------------------------------------------
# Verify manifest exists
# -------------------------------------------------------------------
if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "[ERROR] Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

echo "[INFO] Patching Zephyr revision in: $MANIFEST_FILE"
echo "[INFO] Using SHA: $SHA"

# -------------------------------------------------------------------
# Escape characters in SHA for sed
# -------------------------------------------------------------------
ESCAPED_SHA=$(printf '%s' "$SHA" | sed -e 's/[\/&]/\\&/g')

# -------------------------------------------------------------------
# Patch manifest safely
# -------------------------------------------------------------------
sed -i "s|revision=\"[^\"]*\"|revision=\"$ESCAPED_SHA\"|" "$MANIFEST_FILE"

echo "[INFO] pinned_manifest.xml patched successfully"
