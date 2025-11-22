#!/usr/bin/env bash
set -e

TEMPLATE="manifests/pinned_manifest.template.xml"
OUTPUT="manifests/pinned_manifest.xml"
SHA_FILE="zephyr_sha.txt"

if [ ! -f "$SHA_FILE" ]; then
  echo "[ERROR] SHA file not found: $SHA_FILE"
  exit 1
fi

SHA=$(cat "$SHA_FILE")

echo "[INFO] Using Zephyr SHA: $SHA"
echo "[INFO] Patching manifest..."

sed "s/{{ZEPHYR_SHA}}/$SHA/g" "$TEMPLATE" > "$OUTPUT"

echo "[INFO] Manifest generated:"
echo "----------------------------------"
cat "$OUTPUT"
echo "----------------------------------"
