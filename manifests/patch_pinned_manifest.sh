#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# patch_pinned_manifest.sh
#  - Patches manifests/pinned_manifest.xml replacing the Zephyr project
#    revision attribute with a provided full 40-char commit SHA.
#  - Usage:
#      ZEPHYR_SHA=<40hex> ./manifests/patch_pinned_manifest.sh
#      or place SHA into zephyr_sha.txt and run without env var.
# =============================================================================

MANIFEST_FILE="manifests/pinned_manifest.xml"

# ---------------------------------------------------------------------
# Get SHA from env or file
# ---------------------------------------------------------------------
if [[ -n "${ZEPHYR_SHA:-}" ]]; then
    SHA="${ZEPHYR_SHA}"
elif [[ -f zephyr_sha.txt ]]; then
    SHA="$(<zephyr_sha.txt)"
else
    echo "[ERROR] Zephyr SHA not provided. Set ZEPHYR_SHA or create zephyr_sha.txt"
    exit 1
fi

# Trim whitespace and CR/LF
SHA="$(printf '%s' "$SHA" | tr -d '[:space:]\r\n')"

# Validate 40-hex SHA (strict reproducibility)
if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
    echo "[ERROR] Invalid Zephyr SHA: '$SHA' (expected 40 hex characters)"
    exit 1
fi

# ---------------------------------------------------------------------
# Ensure manifest exists
# ---------------------------------------------------------------------
if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "[ERROR] Manifest not found: $MANIFEST_FILE"
    exit 1
fi

echo "[INFO] Patching $MANIFEST_FILE with Zephyr SHA: $SHA"

# Use @ delimiter in sed to avoid slash escaping issues.
# This replaces only the revision attribute value for the 'zephyr' project.
# It is intentionally conservative: it matches project name="zephyr" then the revision attr.
sed -E -i \
  "s@(project[[:space:]]+name=\"zephyr\"[^>]*revision=\")([^\"]+)(\")@\1${SHA}\3@G" \
  "$MANIFEST_FILE"

echo "[INFO] Patched $MANIFEST_FILE successfully"

