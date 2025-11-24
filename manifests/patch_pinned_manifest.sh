#!/usr/bin/env bash
set -euo pipefail

MANIFEST_FILE="manifests/pinned_manifest.xml"

# ---------------------------------------------------------------------
# Get SHA from env or file
# ---------------------------------------------------------------------
if [[ -n "${ZEPHYR_SHA:-}" ]]; then
    SHA="${ZEPHYR_SHA}"
elif [[ -f zephyr_sha.txt ]]; then
    SHA="$(<zephyr_sha.txt)"
else
    echo "[ERROR] Zephyr SHA not provided"
    exit 1
fi

# Trim spaces and CR/LF
SHA=$(echo "$SHA" | tr -d '[:space:]\r\n')

# Validate SHA
if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
    echo "[ERROR] Invalid SHA: '$SHA'"
    exit 1
fi

if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "[ERROR] Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

echo "[INFO] Patching $MANIFEST_FILE with SHA $SHA"

# Escape slashes & ampersands
ESC_SHA=$(printf '%s' "$SHA" | sed 's/[\/&]/\\&/g')

# Patch the revision attribute
sed -i -E "s@(revision=\")[^\"]+(\")@\1$ESC_SHA\2@" "$MANIFEST_FILE"

echo "[INFO] Patched successfully"
