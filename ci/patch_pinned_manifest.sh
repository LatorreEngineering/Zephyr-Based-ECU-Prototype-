#!/usr/bin/env bash
set -euo pipefail

MANIFEST_FILE="manifests/pinned_manifest.xml"

# Determine SHA source
if [ -n "${ZEPHYR_SHA:-}" ]; then
    SHA="$ZEPHYR_SHA"
elif [ -f zephyr_sha.txt ]; then
    SHA=$(<zephyr_sha.txt)
else
    echo "[ERROR] Zephyr SHA not provided. Set ZEPHYR_SHA or create zephyr_sha.txt"
    exit 1
fi

SHA=$(echo "$SHA" | tr -d '[:space:]')

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "[ERROR] Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

echo "[INFO] Patching $MANIFEST_FILE with SHA: $SHA"

# Safe sed replacement using @ delimiter
sed -i "s@revision=\"[^\"]*\"@revision=\"$SHA\"@" "$MANIFEST_FILE"

echo "[INFO] pinned_manifest.xml patched successfully"
