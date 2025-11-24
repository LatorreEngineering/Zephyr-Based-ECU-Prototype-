#!/usr/bin/env bash
set -euo pipefail

MANIFEST_FILE="manifests/pinned_manifest.xml"

# -----------------------------------------------------------------------------
# Determine Zephyr SHA
# -----------------------------------------------------------------------------
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
    echo "[ERROR] SHA is empty after cleaning"
    exit 1
fi

# -----------------------------------------------------------------------------
# Ensure manifest exists
# -----------------------------------------------------------------------------
if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "[ERROR] Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

echo "[INFO] Patching Zephyr revision in $MANIFEST_FILE"
echo "[INFO] Using SHA: $SHA"

# -----------------------------------------------------------------------------
# Replace only the Zephyr project revision
# -----------------------------------------------------------------------------
# Match: <project name="zephyr" ... revision="anything" ...>
# Replace revision value only
# -----------------------------------------------------------------------------
sed -i -E "s@(project[[:space:]]+name=\"zephyr\"[^>]*revision=\")([^\"]+)(\")@\1${SHA}\3@" "$MANIFEST_FILE"

echo "[INFO] pinned_manifest.xml updated successfully"
