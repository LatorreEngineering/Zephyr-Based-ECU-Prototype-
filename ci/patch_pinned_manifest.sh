#!/usr/bin/env bash
set -euo pipefail

MANIFEST_FILE="manifests/pinned_manifest.xml"

# Obtain SHA
if [[ -n "${ZEPHYR_SHA:-}" ]]; then
    SHA="$ZEPHYR_SHA"
elif [[ -f zephyr_sha.txt ]]; then
    SHA=$(<zephyr_sha.txt)
else
    echo "[ERROR] Zephyr SHA not provided"
    exit 1
fi

SHA=$(echo "$SHA" | tr -d '[:space:]')
if [[ -z "$SHA" ]]; then
    echo "[ERROR] SHA is empty"
    exit 1
fi

if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "[ERROR] Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

echo "[INFO] Patching $MANIFEST_FILE with SHA: $SHA"

# Escape & for sed
ESC_SHA=$(printf '%s' "$SHA" | sed 's/[&]/\\&/g')

# Use simple @ delimiter
sed -i "s@revision=\"[^\"]*\"@revision=\"$ESC_SHA\"@" "$MANIFEST_FILE"

echo "[INFO] pinned_manifest.xml patched successfully"
