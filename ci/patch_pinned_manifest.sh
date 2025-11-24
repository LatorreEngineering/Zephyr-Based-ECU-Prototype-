#!/usr/bin/env bash
set -euo pipefail

MANIFEST_FILE="manifests/pinned_manifest.xml"

if [[ -n "${ZEPHYR_SHA:-}" ]]; then
    SHA="${ZEPHYR_SHA}"
elif [[ -f zephyr_sha.txt ]]; then
    SHA="$(<zephyr_sha.txt)"
else
    echo "[ERROR] Zephyr SHA not provided"
    exit 1
fi

SHA=$(echo "$SHA" | tr -d '[:space:]\r\n')

if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
    echo "[ERROR] Invalid SHA: '$SHA'"
    exit 1
fi

if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "[ERROR] Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

echo "[INFO] Patching $MANIFEST_FILE with SHA $SHA"

ESC_SHA=$(printf '%s' "$SHA" | sed 's/[\/&]/\\&/g')
sed -i -E "s@(revision=\")[^\"]+(\")@\1$ESC_SHA\2@" "$MANIFEST_FILE"

echo "[INFO] Patched successfully"
