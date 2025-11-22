#!/usr/bin/env bash
set -e

echo "=============================================="
echo " Fetching Zephyr v3.7-branch SHA"
echo "=============================================="

# The official Zephyr repository
ZEPHYR_URL="https://github.com/zephyrproject-rtos/zephyr.git"
BRANCH="v3.7-branch"

# Temporary directory to clone minimal data
TMP_DIR=$(mktemp -d)

echo "[INFO] Cloning Zephyr repository (shallow)..."
git clone --branch $BRANCH --depth=1 $ZEPHYR_URL $TMP_DIR > /dev/null 2>&1

cd $TMP_DIR

# Get the SHA of the branch HEAD
SHA=$(git rev-parse HEAD)

echo "----------------------------------------------"
echo " Zephyr v3.7-branch SHA:"
echo " $SHA"
echo "----------------------------------------------"

# Write output file for CI usage
OUTPUT_FILE="$OLDPWD/zephyr_sha.txt"
echo "$SHA" > "$OUTPUT_FILE"

echo "[INFO] SHA saved to: $OUTPUT_FILE"
echo "[INFO] Done."

# Clean up
rm -rf $TMP_DIR
