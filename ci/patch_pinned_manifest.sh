#!/usr/bin/env bash
set -euo pipefail

MANIFEST_FILE="manifests/pinned_manifest.xml"

# -----------------------------------------------------------------------------
# Get SHA
# -----------------------------------------------------------------------------
if [ -n "${ZEPHYR_SHA:-}" ]; then
    SHA="$ZEPHYR_SHA"
elif [ -f zephyr_sha.txt ]; then
    SHA=$(<zephyr_sha.txt)
else
    echo "[ERROR] Zephyr SHA not provided. Set ZEPHYR_SHA or create zephyr_sha.txt"
    exit 1
fi

SHA=$(echo "$SHA" | tr -d '[:space:]')

if [ -z "$SHA" ]; then
    echo "[ERROR] SHA is empty after cleaning"
    exit 1
fi

# -----------------------------------------------------------------------------
# Validate manifest file exists
# -----------------------------------------------------------------------------
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "[ERROR] Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

echo "[INFO] Patching Zephyr revision inside: $MANIFEST_FILE"
echo "[INFO] Using SHA: $SHA"

# -----------------------------------------------------------------------------
# Replace ONLY the Zephyr project revision
# -----------------------------------------------------------------------------
# Example target in XML:
#   <project name="zephyr" revision="abc123" path="zephyr">
#
# Regex:
#   Find: project name="zephyr" ... revision="anything"
#   Replace only the revision value
# -----------------------------------------------------------------------------

sed -i -E \
    "s@(project[[:space:]]+name=\"zephyr\"[^>]*revision=\")([^\"]+)(\")@\1${SHA}\3@" \
    "$MANIFEST_FILE"

echo "[INFO] pinned_manifest.xml updated successfully"
