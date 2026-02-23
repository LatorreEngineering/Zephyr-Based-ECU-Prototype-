#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Zephyr ECU Prototype - Environment Setup Script

set -e  # Exit on error

echo "[INFO] Starting setup_env.sh"

# Determine project root (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "[INFO] PROJECT_ROOT = ${PROJECT_ROOT}"

# Workspace directory (parent of project)
WORKSPACE_DIR="${WORKSPACE_DIR:-$(cd "${PROJECT_ROOT}/.." && pwd)}"
echo "[INFO] Workspace: ${WORKSPACE_DIR}"

# Install Python dependencies
echo "[INFO] Installing Python dependencies"
pip3 install --user west pykwalify

# Change to workspace directory
cd "${WORKSPACE_DIR}"

# Check if west is already initialized
if [ ! -d ".west" ]; then
    echo "[INFO] Running west init"
    west init -l "${PROJECT_ROOT}"
else
    echo "[INFO] West workspace already initialized"
fi

# Update Zephyr and modules
echo "[INFO] Running west update"
west update

# Install additional Python requirements
if [ -f "${PROJECT_ROOT}/requirements.txt" ]; then
    echo "[INFO] Installing project Python requirements"
    pip3 install --user -r "${PROJECT_ROOT}/requirements.txt"
fi

# Source Zephyr environment
ZEPHYR_BASE="${WORKSPACE_DIR}/zephyr"
if [ -f "${ZEPHYR_BASE}/zephyr-env.sh" ]; then
    echo "[INFO] Sourcing Zephyr environment"
    source "${ZEPHYR_BASE}/zephyr-env.sh"
fi

# Export environment variables
export ZEPHYR_BASE
export WORKSPACE_DIR
export PROJECT_ROOT

# Create .env.ci file for subsequent steps
cat > "${PROJECT_ROOT}/.env.ci" << EOF
export ZEPHYR_BASE="${ZEPHYR_BASE}"
export WORKSPACE_DIR="${WORKSPACE_DIR}"
export PROJECT_ROOT="${PROJECT_ROOT}"
EOF

echo "[INFO] Environment setup complete"
echo "[INFO] ZEPHYR_BASE=${ZEPHYR_BASE}"
echo "[INFO] To activate in current shell: source ${PROJECT_ROOT}/.env.ci"
