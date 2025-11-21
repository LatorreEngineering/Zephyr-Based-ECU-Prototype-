#!/usr/bin/env bash
# =============================================================================
# Zephyr ECU Prototype - Build Script (HALO)
# =============================================================================
# Purpose: Build firmware for FRDM-K64F with CI optimizations
# Usage: ./ci/build_halo.sh [options]
# Options:
#   -b, --board BOARD    Target board (default: frdm_k64f)
#   -c, --clean          Clean build directory first
#   -p, --pristine       Pristine build (no cache)
#   -e, --experimental   Enable experimental features
#   -v, --verbose        Verbose build output
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
BOARD="${BOARD:-frdm_k64f}"
CLEAN_BUILD=false
PRISTINE_BUILD=false
EXPERIMENTAL_MODE=false
VERBOSE=false

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Parse Arguments
# -----------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--board)
                BOARD="$2"
                shift 2
                ;;
            -c|--clean)
                CLEAN_BUILD=true
                shift
                ;;
            -p|--pristine)
                PRISTINE_BUILD=true
                shift
                ;;
            -e|--experimental)
                EXPERIMENTAL_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  -b, --board BOARD    Target board (default: frdm_k64f)"
                echo "  -c, --clean          Clean build directory"
                echo "  -p, --pristine       Pristine build (no cache)"
                echo "  -e, --experimental   Enable experimental features"
                echo "  -v, --verbose        Verbose build output"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

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
    echo -e "${BLUE}=========================================="
    echo -e "$*"
    echo -e "==========================================${NC}"
}

# -----------------------------------------------------------------------------
# Environment Validation
# -----------------------------------------------------------------------------
validate_environment() {
    log_step "Validating Build Environment"
    
    # Check ZEPHYR_BASE
    if [ -z "${ZEPHYR_BASE:-}" ]; then
        log_error "ZEPHYR_BASE not set"
        log_error "Source the environment first: source .env.ci"
        exit 1
    fi
    
    if [ ! -d "${ZEPHYR_BASE}" ]; then
        log_error "ZEPHYR_BASE directory not found: ${ZEPHYR_BASE}"
        exit 1
    fi
    
    log_info "ZEPHYR_BASE: ${ZEPHYR_BASE}"
    
    # Check west
    if ! command -v west &> /dev/null; then
        log_error "west not found in PATH"
        exit 1
    fi
    
    log_info "west version: $(west --version)"
    
    # Check SDK
    if [ -n "${ZEPHYR_SDK_INSTALL_DIR:-}" ]; then
        log_info "Zephyr SDK: ${ZEPHYR_SDK_INSTALL_DIR}"
    else
        log_warn "ZEPHYR_SDK_INSTALL_DIR not set (using system toolchain)"
    fi
    
    # Check CMake
    if ! command -v cmake &> /dev/null; then
        log_error "cmake not found in PATH"
        exit 1
    fi
    
    log_info "CMake version: $(cmake --version | head -n1)"
    
    log_info "✅ Environment valid"
}

# -----------------------------------------------------------------------------
# Clean Build Directory
# -----------------------------------------------------------------------------
clean_build_dir() {
    if [ "${CLEAN_BUILD}" = true ] || [ "${PRISTINE_BUILD}" = true ]; then
        log_step "Cleaning Build Directory"
        if [ -d "${BUILD_DIR}" ]; then
            log_info "Removing ${BUILD_DIR}..."
            rm -rf "${BUILD_DIR}"
        fi
        log_info "✅ Build directory cleaned"
    fi
}

# -----------------------------------------------------------------------------
# Generate Build Configuration
# -----------------------------------------------------------------------------
generate_build_config() {
    log_step "Generating Build Configuration"
    
    # Get git info
    local git_commit
    git_commit=$(git -C "${PROJECT_ROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    local git_branch
    git_branch=$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    
    local build_time
    build_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    log_info "Git Commit: ${git_commit}"
    log_info "Git Branch: ${git_branch}"
    log_info "Build Time: ${build_time}"
    log_info "Board: ${BOARD}"
    log_info "Experimental Mode: ${EXPERIMENTAL_MODE}"
    
    # Export build metadata
    export ECU_GIT_COMMIT="${git_commit}"
    export ECU_GIT_BRANCH="${git_branch}"
    export ECU_BUILD_TIME="${build_time}"
}

# -----------------------------------------------------------------------------
# Configure Build Options
# -----------------------------------------------------------------------------
configure_build_options() {
    local cmake_args=()
    
    # Pristine build flag
    if [ "${PRISTINE_BUILD}" = true ]; then
        cmake_args+=("-p" "always")
    elif [ ! -d "${BUILD_DIR}" ]; then
        cmake_args+=("-p" "auto")
    fi
    
    # Experimental mode
    if [ "${EXPERIMENTAL_MODE}" = true ]; then
        cmake_args+=("-DENABLE_EXPERIMENTAL_MODE=ON")
    fi
    
    # Verbose output
    if [ "${VERBOSE}" = true ]; then
        cmake_args+=("-v")
    fi
    
    echo "${cmake_args[@]}"
}

# -----------------------------------------------------------------------------
# Build Firmware
# -----------------------------------------------------------------------------
build_firmware() {
    log_step "Building Firmware for ${BOARD}"
    
    cd "${PROJECT_ROOT}"
    
    # Configure build options
    local build_opts
    build_opts=$(configure_build_options)
    
    # Run west build
    log_info "Running: west build -b ${BOARD} ${build_opts}"
    
    local start_time
    start_time=$(date +%s)
    
    # shellcheck disable=SC2086
    if west build -b "${BOARD}" ${build_opts} .; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_info "✅ Build completed in ${duration}s"
    else
        log_error "❌ Build failed"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Verify Build Artifacts
# -----------------------------------------------------------------------------
verify_artifacts() {
    log_step "Verifying Build Artifacts"
    
    local artifacts=(
        "${BUILD_DIR}/zephyr/zephyr.elf"
        "${BUILD_DIR}/zephyr/zephyr.bin"
        "${BUILD_DIR}/zephyr/zephyr.hex"
    )
    
    local missing_artifacts=()
    
    for artifact in "${artifacts[@]}"; do
        if [ -f "${artifact}" ]; then
            local size
            size=$(stat -c%s "${artifact}" 2>/dev/null || stat -f%z "${artifact}" 2>/dev/null)
            log_info "✅ $(basename "${artifact}") (${size} bytes)"
        else
            missing_artifacts+=("$(basename "${artifact}")")
        fi
    done
    
    if [ ${#missing_artifacts[@]} -ne 0 ]; then
        log_error "Missing artifacts: ${missing_artifacts[*]}"
        exit 1
    fi
    
    log_info "✅ All artifacts present"
}

# -----------------------------------------------------------------------------
# Generate Build Report
# -----------------------------------------------------------------------------
generate_report() {
    log_step "Generating Build Report"
    
    local report_file="${BUILD_DIR}/build_report.txt"
    
    cat > "${report_file}" <<EOF
================================================================================
Zephyr ECU Build Report
================================================================================
Build Time:     $(date -u +%Y-%m-%dT%H:%M:%SZ)
Git Commit:     ${ECU_GIT_COMMIT:-unknown}
Git Branch:     ${ECU_GIT_BRANCH:-unknown}
Board:          ${BOARD}
Zephyr Base:    ${ZEPHYR_BASE}
Experimental:   ${EXPERIMENTAL_MODE}

Artifacts:
EOF
    
    # Add artifact sizes
    for artifact in "${BUILD_DIR}"/zephyr/zephyr.{elf,bin,hex}; do
        if [ -f "${artifact}" ]; then
            local size
            size=$(stat -c%s "${artifact}" 2>/dev/null || stat -f%z "${artifact}" 2>/dev/null)
            printf "  %-20s %10d bytes\n" "$(basename "${artifact}")" "${size}" >> "${report_file}"
        fi
    done
    
    log_info "Build report: ${report_file}"
    
    # Display report
    cat "${report_file}"
}

# -----------------------------------------------------------------------------
# Extract Memory Usage
# -----------------------------------------------------------------------------
extract_memory_usage() {
    log_step "Memory Usage Analysis"
    
    if [ -f "${BUILD_DIR}/zephyr/zephyr.elf" ]; then
        log_info "Analyzing memory footprint..."
        
        # Use size command if available
        if command -v size &> /dev/null; then
            size "${BUILD_DIR}/zephyr/zephyr.elf" | tee "${BUILD_DIR}/memory_usage.txt"
        fi
        
        # Extract from build log
        if [ -f "${BUILD_DIR}/zephyr/.config" ]; then
            log_info "Flash size: $(grep -E "CONFIG_FLASH_SIZE" "${BUILD_DIR}/zephyr/.config" || echo "N/A")"
            log_info "RAM size: $(grep -E "CONFIG_SRAM_SIZE" "${BUILD_DIR}/zephyr/.config" || echo "N/A")"
        fi
    fi
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
main() {
    log_step "Zephyr ECU Build Script (HALO)"
    
    parse_args "$@"
    validate_environment
    clean_build_dir
    generate_build_config
    build_firmware
    verify_artifacts
    generate_report
    extract_memory_usage
    
    log_step "✅ Build Process Complete"
    echo ""
    log_info "Build artifacts available in: ${BUILD_DIR}"
    log_info "Flash firmware with: west flash"
    echo ""
}

# Run main function
main "$@"
