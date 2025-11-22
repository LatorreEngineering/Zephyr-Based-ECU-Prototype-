#!/usr/bin/env bash
# =============================================================================
# Zephyr ECU Prototype - CI Environment Setup Script
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_DIR="${WORKSPACE_DIR:-${HOME}/zephyr-workspace}"
ZEPHYR_VERSION="${ZEPHYR_VERSION:-v3.7-branch}"
WEST_MANIFEST_URL="${WEST_MANIFEST_URL:-}"   # optional: private manifest
WEST_MANIFEST_BRANCH="${WEST_MANIFEST_BRANCH:-$ZEPHYR_VERSION}"
WEST_MANIFEST_FILE="${WEST_MANIFEST_FILE:-manifests/pinned_manifest.xml}"
ZEPHYR_REPO_URL="${ZEPHYR_REPO_URL:-https://github.com/zephyrproject-rtos/zephyr.git}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Logging Functions
# ---------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n==========================================\n$*\n=========================================="; }

# ---------------------------------------------------------------------------
# Dependency Checks
# ---------------------------------------------------------------------------
check_dependencies() {
    log_step "Checking Dependencies"
    local missing=()
    for cmd in python3 pip git cmake ninja sed; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [ "${#missing[@]}" -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_error "Install them with: sudo apt-get install python3 python3-pip git cmake ninja-build"
        exit 1
    fi
    log_info "✅ All dependencies found"
}

# ---------------------------------------------------------------------------
# Fetch latest Zephyr SHA
# ---------------------------------------------------------------------------
fetch_zephyr_sha() {
    log_step "Fetching latest Zephyr SHA for branch $ZEPHYR_VERSION"
    local sha
    sha=$(git ls-remote "$ZEPHYR_REPO_URL" "$ZEPHYR_VERSION" | awk '{print $1}' | tr -d '\r\n')
    if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
        log_error "Invalid SHA fetched: '$sha'"
        exit 1
    fi
    log_info "Zephyr SHA: $sha"
    echo "$sha"
}

# ---------------------------------------------------------------------------
# Patch pinned manifest safely
# ---------------------------------------------------------------------------
patch_pinned_manifest() {
    log_step "Patching Pinned Manifest with Zephyr SHA"
    local manifest="${PROJECT_ROOT}/${WEST_MANIFEST_FILE}"
    if [ ! -f "$manifest" ]; then
        log_error "Pinned manifest not found: $manifest"
        exit 1
    fi

    local sha
    sha=$(fetch_zephyr_sha)

    # Use @ as delimiter to avoid conflicts; ensure no newlines
    sed -i "s@revision=\"[^\"]*\"@revision=\"$sha\"@" "$manifest"
    log_info "✅ Pinned manifest patched successfully"
}

# ---------------------------------------------------------------------------
# Python Environment Setup
# ---------------------------------------------------------------------------
setup_python_env() {
    log_step "Setting Up Python Environment"
    python3 -m pip install --upgrade pip --quiet
    if ! pip show west &>/dev/null; then
        log_info "Installing west..."
        pip install west
    else
        log_info "West already installed, upgrading..."
        pip install --upgrade west
    fi
    if ! command -v west &>/dev/null; then
        log_error "West installation failed"
        exit 1
    fi
    log_info "West version: $(west --version)"
    pip install --quiet pyelftools cantools pyyaml intelhex pyserial pytest
    log_info "✅ Python environment ready"
}

# ---------------------------------------------------------------------------
# Workspace Initialization
# ---------------------------------------------------------------------------
init_workspace() {
    log_step "Initializing Zephyr Workspace"
    mkdir -p "$WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"

    if [ -n "$WEST_MANIFEST_URL" ]; then
        log_info "Using private manifest repo"
        git config --global url."https://${GITHUB_TOKEN}:x-oauth-basic@github.com/".insteadOf "https://github.com/"
        west init -m "$WEST_MANIFEST_URL" -b "$WEST_MANIFEST_BRANCH" .
    else
        log_info "Using local manifest file"
        west init -l .
    fi

    west config manifest.file "${PROJECT_ROOT}/${WEST_MANIFEST_FILE}"
    log_info "✅ Workspace initialized"
}

# ---------------------------------------------------------------------------
# Update Dependencies
# ---------------------------------------------------------------------------
update_dependencies() {
    log_step "Updating Dependencies"
    cd "$WORKSPACE_DIR"
    west update --narrow --fetch-opt=--depth=1
    west zephyr-export
    log_info "✅ Dependencies updated"
}

# ---------------------------------------------------------------------------
# Verify Installation
# ---------------------------------------------------------------------------
verify_installation() {
    log_step "Verifying Installation"
    export ZEPHYR_BASE="${WORKSPACE_DIR}/zephyr"
    if [ ! -f "${ZEPHYR_BASE}/VERSION" ]; then
        log_error "Zephyr installation incomplete"
        exit 1
    fi
    log_info "Zephyr version: $(cat "${ZEPHYR_BASE}/VERSION")"
}

# ---------------------------------------------------------------------------
# Generate Environment File
# ---------------------------------------------------------------------------
generate_env_file() {
    log_step "Generating Environment Configuration"
    local env_file="${PROJECT_ROOT}/.env.ci"
    cat > "$env_file" <<EOF
# Zephyr ECU CI Environment Configuration
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

export ZEPHYR_BASE="${WORKSPACE_DIR}/zephyr"
export ZEPHYR_SDK_INSTALL_DIR="${HOME}/zephyr-sdk-\${ZEPHYR_SDK_VERSION}"
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export GNUARMEMB_TOOLCHAIN_PATH="\${ZEPHYR_SDK_INSTALL_DIR}/arm-zephyr-eabi"
export PROJECT_ROOT="${PROJECT_ROOT}"
export WORKSPACE_DIR="${WORKSPACE_DIR}"
export CMAKE_PREFIX_PATH="\${ZEPHYR_BASE}"
EOF
    log_info "✅ Environment configured: $env_file"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    log_step "Zephyr ECU CI Environment Setup"
    log_info "Project: $PROJECT_ROOT"
    log_info "Workspace: $WORKSPACE_DIR"
    log_info "Zephyr Version: $ZEPHYR_VERSION"

    check_dependencies
    patch_pinned_manifest
    setup_python_env
    init_workspace
    update_dependencies
    verify_installation
    generate_env_file

    log_step "✅ Setup Complete!"
    log_info "Next steps:"
    log_info "  1. Source environment: source $PROJECT_ROOT/.env.ci"
    log_info "  2. Build firmware: ./ci/build_halo.sh"
    log_info "  3. Run tests: west build -b native_posix tests/test_state_machine"
}

main "$@"

