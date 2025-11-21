#!/usr/bin/env bash
# =============================================================================
# Zephyr ECU Prototype - CI Environment Setup Script
# =============================================================================
# Purpose: Initialize Zephyr workspace with pinned dependencies
# Usage: ./ci/setup_env.sh
# Requirements: Python 3.8+, pip, git
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_DIR="${WORKSPACE_DIR:-${HOME}/zephyr-workspace}"
ZEPHYR_VERSION="${ZEPHYR_VERSION:-v3.7-branch}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_step() {
    echo ""
    echo "=========================================="
    echo "$*"
    echo "=========================================="
}

# -----------------------------------------------------------------------------
# Dependency Checks
# -----------------------------------------------------------------------------
check_dependencies() {
    log_step "Checking Dependencies"
    
    local missing_deps=()
    
    for cmd in python3 pip git cmake ninja; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_deps+=("${cmd}")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Install them with: sudo apt-get install python3 python3-pip git cmake ninja-build"
        exit 1
    fi
    
    log_info "✅ All dependencies found"
}

# -----------------------------------------------------------------------------
# Python Environment Setup
# -----------------------------------------------------------------------------
setup_python_env() {
    log_step "Setting Up Python Environment"
    
    # Upgrade pip
    python3 -m pip install --upgrade pip --quiet
    
    # Install west
    if ! pip show west &> /dev/null; then
        log_info "Installing west..."
        pip install west
    else
        log_info "West already installed, upgrading..."
        pip install --upgrade west
    fi
    
    # Verify west installation
    if ! command -v west &> /dev/null; then
        log_error "West installation failed"
        exit 1
    fi
    
    log_info "West version: $(west --version)"
    
    # Install additional Python dependencies
    log_info "Installing Python dependencies..."
    pip install --quiet \
        pyelftools \
        cantools \
        pyyaml \
        intelhex \
        pyserial \
        pytest
    
    log_info "✅ Python environment ready"
}

# -----------------------------------------------------------------------------
# Workspace Initialization
# -----------------------------------------------------------------------------
init_workspace() {
    log_step "Initializing Zephyr Workspace"
    
    # Check if workspace already exists
    if [ -d "${WORKSPACE_DIR}/zephyr" ]; then
        log_warn "Workspace already exists at ${WORKSPACE_DIR}"
        log_info "Skipping initialization (use west update to refresh)"
        return 0
    fi
    
    # Create workspace directory
    mkdir -p "${WORKSPACE_DIR}"
    cd "${WORKSPACE_DIR}"
    
    # Initialize west workspace
    log_info "Initializing west workspace..."
    west init -m https://github.com/LatorreEngineering/Zephyr-Based-ECU-Prototype- .
    
    log_info "✅ Workspace initialized"
}

# -----------------------------------------------------------------------------
# Update Dependencies with Pinned Manifest
# -----------------------------------------------------------------------------
update_dependencies() {
    log_step "Updating Dependencies (Pinned Manifest)"
    
    cd "${WORKSPACE_DIR}"
    
    # Configure manifest to use pinned version
    log_info "Configuring pinned manifest..."
    west config manifest.file manifests/pinned_manifest.xml
    
    # Verify pinned manifest exists
    if [ ! -f "${WORKSPACE_DIR}/ecu-prototype/manifests/pinned_manifest.xml" ]; then
        log_error "Pinned manifest not found!"
        log_error "Expected: ${WORKSPACE_DIR}/ecu-prototype/manifests/pinned_manifest.xml"
        exit 1
    fi
    
    # Update all modules
    log_info "Fetching dependencies (this may take a few minutes)..."
    west update --narrow --fetch-opt=--depth=1
    
    # Export CMake package
    log_info "Exporting Zephyr CMake package..."
    west zephyr-export
    
    log_info "✅ Dependencies updated"
}

# -----------------------------------------------------------------------------
# Verify Installation
# -----------------------------------------------------------------------------
verify_installation() {
    log_step "Verifying Installation"
    
    # Check ZEPHYR_BASE
    export ZEPHYR_BASE="${WORKSPACE_DIR}/zephyr"
    
    if [ ! -f "${ZEPHYR_BASE}/VERSION" ]; then
        log_error "Zephyr installation incomplete"
        exit 1
    fi
    
    local zephyr_version
    zephyr_version=$(cat "${ZEPHYR_BASE}/VERSION")
    log_info "Zephyr version: ${zephyr_version}"
    
    # Verify key modules
    local modules=("hal_nxp" "hal_cmsis" "mcuboot" "mbedtls")
    for module in "${modules[@]}"; do
        if [ -d "${WORKSPACE_DIR}/modules/hal/${module}" ] || \
           [ -d "${WORKSPACE_DIR}/bootloader/${module}" ] || \
           [ -d "${WORKSPACE_DIR}/modules/crypto/${module}" ]; then
            log_info "✅ Module found: ${module}"
        else
            log_warn "⚠️  Module not found: ${module}"
        fi
    done
    
    log_info "✅ Installation verified"
}

# -----------------------------------------------------------------------------
# Generate Environment File
# -----------------------------------------------------------------------------
generate_env_file() {
    log_step "Generating Environment Configuration"
    
    local env_file="${PROJECT_ROOT}/.env.ci"
    
    cat > "${env_file}" <<EOF
# Zephyr ECU CI Environment Configuration
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

export ZEPHYR_BASE="${WORKSPACE_DIR}/zephyr"
export ZEPHYR_SDK_INSTALL_DIR="${HOME}/zephyr-sdk-\${ZEPHYR_SDK_VERSION}"
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export GNUARMEMB_TOOLCHAIN_PATH="\${ZEPHYR_SDK_INSTALL_DIR}/arm-zephyr-eabi"

# Project paths
export PROJECT_ROOT="${PROJECT_ROOT}"
export WORKSPACE_DIR="${WORKSPACE_DIR}"

# Build configuration
export CMAKE_PREFIX_PATH="\${ZEPHYR_BASE}"
EOF
    
    log_info "Environment file created: ${env_file}"
    log_info "Source it with: source ${env_file}"
    
    log_info "✅ Environment configured"
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
main() {
    log_step "Zephyr ECU CI Environment Setup"
    log_info "Project: ${PROJECT_ROOT}"
    log_info "Workspace: ${WORKSPACE_DIR}"
    log_info "Zephyr Version: ${ZEPHYR_VERSION}"
    
    check_dependencies
    setup_python_env
    init_workspace
    update_dependencies
    verify_installation
    generate_env_file
    
    log_step "✅ Setup Complete!"
    echo ""
    log_info "Next steps:"
    log_info "  1. Source environment: source ${PROJECT_ROOT}/.env.ci"
    log_info "  2. Build firmware: ./ci/build_halo.sh"
    log_info "  3. Run tests: west build -b native_posix tests/test_state_machine"
    echo ""
}

# Run main function
main "$@"
