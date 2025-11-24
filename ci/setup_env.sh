#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Environment-safe path setup
# -----------------------------------------------------------------------------
if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
    WORKSPACE_DIR="${WORKSPACE_DIR:-$GITHUB_WORKSPACE/zephyr-workspace}"
else
    WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/zephyr-workspace}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PATCH_SCRIPT="${PROJECT_ROOT}/manifests/patch_pinned_manifest.sh"
PINNED_MANIFEST="${PROJECT_ROOT}/manifests/pinned_manifest.xml"

# -----------------------------------------------------------------------------
# Colors for logging
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
# Dependency Checks
# -----------------------------------------------------------------------------
check_dependencies() {
    step "Checking Dependencies"
    for cmd in python3 pip git cmake ninja sed; do
        if ! command -v "$cmd" >/dev/null; then
            err "Missing dependency: $cmd"
            exit 1
        fi
    done
    log "All dependencies available"
}

# -----------------------------------------------------------------------------
# Patch pinned manifest (enforce Zephyr SHA)
# -----------------------------------------------------------------------------
patch_pinned_manifest() {
    step "Patching pinned manifest"

    if [[ ! -f "$PATCH_SCRIPT" ]]; then
        err "Missing: manifests/patch_pinned_manifest.sh"
        exit 1
    fi
    if [[ ! -f "$PINNED_MANIFEST" ]]; then
        err "Missing: manifests/pinned_manifest.xml"
        exit 1
    fi

    chmod +x "$PATCH_SCRIPT"
    "$PATCH_SCRIPT"

    log "Pinned manifest patched successfully"
}

# -----------------------------------------------------------------------------
# Python + West setup
# -----------------------------------------------------------------------------
setup_python_env() {
    step "Installing Python dependencies"

    python3 -m pip install --upgrade pip
    pip install --upgrade west
    pip install pyelftools cantools pyyaml intelhex pyserial pytest

    log "Python environment ready"
}

# -----------------------------------------------------------------------------
# Initialize Zephyr Workspace
# -----------------------------------------------------------------------------
init_workspace() {
    step "Initializing West workspace"

    mkdir -p "$WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"

    if [[ -f .west/config ]]; then
        warn "Workspace already initialized, skipping west init"
    else
        log "Running: west init -l $PROJECT_ROOT"
        west init -l "$PROJECT_ROOT"
    fi

    log "Workspace ready at $WORKSPACE_DIR"
}

# -----------------------------------------------------------------------------
# Update Zephyr modules
# -----------------------------------------------------------------------------
update_dependencies() {
    step "Updating Zephyr modules"

    cd "$WORKSPACE_DIR"
    west update --narrow --fetch-opt=--depth=1
    west zephyr-export

    log "Zephyr modules updated"
}

# -----------------------------------------------------------------------------
# Verify Zephyr Installation
# -----------------------------------------------------------------------------
verify_installation() {
    step "Verifying Zephyr installation"

    export ZEPHYR_BASE="${WORKSPACE_DIR}/zephyr"
    if [[ ! -f "$ZEPHYR_BASE/VERSION" ]]; then
        err "Zephyr installation incomplete — VERSION file missing"
        exit 1
    fi

    log "Zephyr installation verified"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    step "Zephyr ECU CI Setup"
    log "Project root: $PROJECT_ROOT"
    log "Workspace:    $WORKSPACE_DIR"

    check_dependencies
    patch_pinned_manifest
    setup_python_env
    init_workspace
    update_dependencies
    verify_installation

    step "Setup Complete"
}

main "$@"
