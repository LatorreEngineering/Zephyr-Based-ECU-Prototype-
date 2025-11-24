#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_DIR="${WORKSPACE_DIR:-${HOME}/zephyr-workspace}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step() { echo -e "\n==========================================\n$*\n=========================================="; }

# -----------------------------------------------------------------------------
# Dependency Checks
# -----------------------------------------------------------------------------
check_dependencies() {
    step "Checking Dependencies"
    for cmd in python3 pip git cmake ninja sed; do
        command -v "$cmd" >/dev/null || { err "Missing dependency: $cmd"; exit 1; }
    done
    log "All dependencies available"
}

# -----------------------------------------------------------------------------
# Patch pinned manifest
# -----------------------------------------------------------------------------
patch_pinned_manifest() {
    step "Patching pinned manifest"

    PATCH_SCRIPT="${PROJECT_ROOT}/manifests/patch_pinned_manifest.sh"

    if [ ! -f "$PATCH_SCRIPT" ]; then
        err "Missing: manifests/patch_pinned_manifest.sh"
        exit 1
    fi

    chmod +x "$PATCH_SCRIPT"
    bash "$PATCH_SCRIPT"
}

# -----------------------------------------------------------------------------
# Python Env
# -----------------------------------------------------------------------------
setup_python_env() {
    step "Setting up Python environment"
    python3 -m pip install --upgrade pip
    pip install --upgrade west
    pip install pyelftools cantools pyyaml intelhex pyserial pytest
}

# -----------------------------------------------------------------------------
# Initialize Workspace
# -----------------------------------------------------------------------------
init_workspace() {
    step "Initializing Zephyr workspace"

    mkdir -p "$WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"

    log "Running: west init -l $PROJECT_ROOT"
    west init -l "$PROJECT_ROOT"

    # DO NOT override west.yml with XML file
    log "Using west.yml normally (no override)"

    log "Workspace initialized"
}

# -----------------------------------------------------------------------------
# Update Dependencies
# -----------------------------------------------------------------------------
update_dependencies() {
    step "Updating Zephyr modules"
    cd "$WORKSPACE_DIR"
    west update --narrow --fetch-opt=--depth=1
    west zephyr-export
}

# -----------------------------------------------------------------------------
# Verify Install
# -----------------------------------------------------------------------------
verify_installation() {
    step "Verifying installation"

    export ZEPHYR_BASE="${WORKSPACE_DIR}/zephyr"
    if [ ! -f "${ZEPHYR_BASE}/VERSION" ]; then
        err "Zephyr installation incomplete — VERSION file missing"
        exit 1
    fi

    log "Zephyr installed successfully"
}

# -----------------------------------------------------------------------------
main() {
    step "Zephyr ECU CI Setup"
    log "Project root: $PROJECT_ROOT"
    log "Workspace: $WORKSPACE_DIR"

    check_dependencies
    patch_pinned_manifest
    setup_python_env
    init_workspace
    update_dependencies
    verify_installation

    step "Setup Complete"
}

main "$@"
