#!/usr/bin/env bash
# Build script for Zephyr ECU firmware (FRDM-K64F board)
# NOTE: We use this solution for the moment, in the future we will target C.

set -euo pipefail
echo "=== Building Zephyr ECU firmware ==="
export ZEPHYR_BASE="${HOME}/zephyr-workspace/zephyr"
export ZEPHYR_SDK_INSTALL_DIR="${HOME}/zephyr-sdk-${ZEPHYR_SDK_VERSION}"

cd "$(dirname "$0")/.."  # go to repo root
west build -b ${BOARD} -d build/zephyr \
    --pristine \
    app/

echo "=== Build complete: output in build/zephyr ==="
