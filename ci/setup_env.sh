#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/zephyr-workspace}"

PATCH_SCRIPT="${PROJECT_ROOT}/manifests/patch_pinned_manifest.sh"
PINNED_MANIFEST="${PROJECT_ROOT}/manifests/pinned_manifest.xml"

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step() { echo -e "\n==========================================\n$*\n=========================================="; }

# -----------------------------------------------------------------------------
# Check Dependencies
# -----------------------------------------------------------------------------
check_dependencies() {
    step "Checking Dependencies"
    for cmd in python3 pip git cmake ninja sed xmllint west; do
        command -v "$cmd" >/dev/null || { err "Missing dependency: $cmd"; exit 1; }
    done
    log "All dependencies available"
}

# -----------------------------------------------------------------------------
# Patch Manifest
# -----------------------------------------------------------------------------
patch_manifest() {
    step "Patching pinned_manifest.xml"
    if [[ ! -f "$PATCH_SCRIPT" ]]; then
        err "Patch script not found: $PATCH_SCRIPT"
        exit 1
    fi
    chmod +x "$PATCH_SCRIPT"
    "$PATCH_SCRIPT"
}

# -----------------------------------------------------------------------------
# Setup Python
# -----------------------------------------------------------------------------
setup_python_env() {
    step "Installing Python dependencies"
    python3 -m pip install --upgrade pip
    pip install --upgrade west lxml
    pip install pyelftools cantools pyyaml intelhex pyserial pytest
    log "Python environment ready"
}

# -----------------------------------------------------------------------------
# Initialize Workspace
# -----------------------------------------------------------------------------
init_workspace() {
    step "Initializing Zephyr workspace"
    mkdir -p "$WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"
    west init -l "$PROJECT_ROOT"
    log "Workspace initialized at $WORKSPACE_DIR"
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
# Verify
# -----------------------------------------------------------------------------
verify_installation() {
    step "Verifying Zephyr installation"
    export ZEPHYR_BASE="${WORKSPACE_DIR}/zephyr"
    if [[ ! -f "$ZEPHYR_BASE/VERSION" ]]; then
        err "Zephyr installation incomplete — VERSION file missing"
        exit 1
    fi
    log "Zephyr installed correctly"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    step "Zephyr ECU CI Setup"
    log "Project root: $PROJECT_ROOT"
    log "Workspace: $WORKSPACE_DIR"

    check_dependencies
    patch_manifest
    setup_python_env
    init_workspace
    update_dependencies
    verify_installation

    step "Setup Complete"
}

main "$@"
