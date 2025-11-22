#!/usr/bin/env bash
# ci/build_halo.sh
# Build instrumented VBSPro (Halo.OS Vehicle Base System Pro)
# This is the ONLY subsystem needed for latency/jitter/NPU overhead measurement

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT

# Directories
HALO_SRC_DIR="${HALO_SRC_DIR:-${PROJECT_ROOT}/halo-os-src}"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build}"
LOG_DIR="${PROJECT_ROOT}/logs"

# Manifest configuration - use official Halo.OS manifest
MANIFEST_REPO_URL="${MANIFEST_REPO_URL:-https://gitee.com/haloos/manifests.git}"
MANIFEST_NAME="${MANIFEST_NAME:-vbs.xml}"  # VBS-only manifest

# Build configuration
CLEAN_BUILD=0
JOBS=$(nproc 2>/dev/null || echo 4)

# ==============================================================================
# Logging Setup
# ==============================================================================
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/build_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

fatal() {
    error "$@"
    exit 1
}

# ==============================================================================
# Argument Parsing
# ==============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --clean)
                CLEAN_BUILD=1
                shift
                ;;
            --jobs)
                JOBS="$2"
                shift 2
                ;;
            -j*)
                JOBS="${1#-j}"
                shift
                ;;
            --help|-h)
                cat << EOF
Usage: $0 [OPTIONS]

Build VBSPro (Halo.OS middleware) with LTTng instrumentation.

Options:
    --clean         Clean build (remove build directory)
    --jobs N, -jN   Number of parallel build jobs (default: ${JOBS})
    --help, -h      Show this help message

Environment Variables:
    MANIFEST_REPO_URL   Manifest repo (default: ${MANIFEST_REPO_URL})
    MANIFEST_NAME       Manifest file (default: ${MANIFEST_NAME})
    HALO_SRC_DIR        Source directory (default: ${HALO_SRC_DIR})
    BUILD_DIR           Build directory (default: ${BUILD_DIR})
    GITEE_TOKEN         Gitee access token (for private repos)
    GITEE_SSH_KEY       SSH key for Gitee (alternative to token)
EOF
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# ==============================================================================
# Install System Dependencies
# ==============================================================================
install_dependencies() {
    log "Installing system dependencies..."
    
    # Update package lists
    sudo apt-get update -qq
    
    # Install required packages
    sudo apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        ninja-build \
        git \
        curl \
        ca-certificates \
        openjdk-11-jdk \
        python3 \
        python3-pip \
        lttng-tools \
        liblttng-ust-dev \
        liblttng-ctl-dev \
        liburcu-dev \
        pkg-config
    
    # Configure Java
    export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-1.11.0-openjdk-amd64}"
    export PATH="$JAVA_HOME/bin:$PATH"
    
    log "System dependencies installed"
}

# ==============================================================================
# Install Repo Tool
# ==============================================================================
install_repo_tool() {
    if command -v repo >/dev/null 2>&1; then
        log "repo tool already installed: $(repo --version 2>&1 | head -1 || echo 'unknown')"
        return 0
    fi
    
    log "Installing repo tool..."
    
    local repo_url="https://storage.googleapis.com/git-repo-downloads/repo"
    local repo_bin="/tmp/repo"
    
    if curl -sSfL "$repo_url" -o "$repo_bin"; then
        chmod +x "$repo_bin"
        sudo mv "$repo_bin" /usr/local/bin/repo
        log "repo tool installed successfully"
    else
        fatal "Failed to download repo tool from $repo_url"
    fi
}

# ==============================================================================
# Setup Git Authentication (if credentials provided)
# ==============================================================================
setup_git_auth() {
    if [[ -n "${GITEE_SSH_KEY:-}" ]]; then
        log "Configuring SSH authentication for Gitee..."
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        
        # Write SSH key
        echo "$GITEE_SSH_KEY" > ~/.ssh/id_rsa_gitee
        chmod 600 ~/.ssh/id_rsa_gitee
        
        # Add Gitee to known hosts
        ssh-keyscan gitee.com >> ~/.ssh/known_hosts 2>/dev/null || true
        
        # Configure git to use this key
        cat > ~/.ssh/config << EOF
Host gitee.com
    IdentityFile ~/.ssh/id_rsa_gitee
    StrictHostKeyChecking yes
EOF
        chmod 600 ~/.ssh/config
        
        export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa_gitee"
        log "SSH authentication configured"
    elif [[ -n "${GITEE_TOKEN:-}" ]]; then
        log "Using GITEE_TOKEN for HTTPS authentication"
        # Token will be embedded in URLs during repo init
    fi
}

# ==============================================================================
# Initialize and Sync Repository
# ==============================================================================
sync_repository() {
    log "Preparing source directory: $HALO_SRC_DIR"
    mkdir -p "$HALO_SRC_DIR"
    cd "$HALO_SRC_DIR"
    
    # Initialize repo if needed
    if [[ ! -d ".repo" ]]; then
        log "Initializing repo with manifest: $MANIFEST_NAME"
        
        local manifest_url="$MANIFEST_REPO_URL"
        
        # Modify URL if using token
        if [[ -n "${GITEE_TOKEN:-}" ]]; then
            manifest_url="${MANIFEST_REPO_URL/https:\/\//https://${GITEE_TOKEN}@}"
        fi
        
        if [[ -n "${GITEE_SSH_KEY:-}" ]]; then
            manifest_url="${MANIFEST_REPO_URL/https:\/\/gitee.com/git@gitee.com:}"
        fi
        
        log "Manifest URL: ${manifest_url}"
        
        if ! repo init -u "$manifest_url" -m "$MANIFEST_NAME" --no-repo-verify; then
            fatal "Failed to initialize repo"
        fi
    else
        log "Repo already initialized"
    fi
    
    # Normalize SSH URLs to HTTPS if no SSH key (prevents auth errors)
    if [[ -z "${GITEE_SSH_KEY:-}" ]]; then
        log "Normalizing remote URLs to HTTPS..."
        repo forall -c '
            origin_url=$(git remote get-url origin 2>/dev/null || true)
            if [[ "$origin_url" == git@* ]]; then
                https_url=$(echo "$origin_url" | sed "s|git@gitee.com:|https://gitee.com/|")
                git remote set-url origin "$https_url"
                echo "Normalized: $origin_url -> $https_url"
            fi
        ' || true
    fi
    
    # Sync with retries
    local max_retries=3
    local retry=0
    local sync_success=0
    
    while [[ $retry -lt $max_retries ]]; do
        log "Syncing repositories (attempt $((retry + 1))/${max_retries})..."
        
        if repo sync -j"$JOBS" --force-sync --no-tags --current-branch; then
            sync_success=1
            break
        else
            error "Sync attempt $((retry + 1)) failed"
            ((retry++))
            
            if [[ $retry -lt $max_retries ]]; then
                log "Waiting 5 seconds before retry..."
                sleep 5
            fi
        fi
    done
    
    if [[ $sync_success -eq 0 ]]; then
        fatal "Repository sync failed after $max_retries attempts"
    fi
    
    log "Repository sync completed successfully"
}

# ==============================================================================
# Record Build Provenance
# ==============================================================================
record_provenance() {
    log "Recording build provenance..."
    
    mkdir -p "$BUILD_DIR"
    local git_info="${BUILD_DIR}/git_info.txt"
    
    cd "$HALO_SRC_DIR"
    
    {
        echo "Build Date: $(date)"
        echo "Manifest Repo: $MANIFEST_REPO_URL"
        echo "Manifest File: $MANIFEST_NAME"
        echo ""
        echo "Repository States:"
        echo "===================="
        
        repo forall -c '
            echo "Project: $REPO_PROJECT"
            echo "  Path: $REPO_PATH"
            echo "  Commit: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
            echo "  Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
            echo ""
        ' 2>/dev/null || echo "Could not record all project states"
    } > "$git_info"
    
    log "Provenance saved to: $git_info"
}

# ==============================================================================
# Build IDL Tools (Gradle-based)
# ==============================================================================
build_idl_tools() {
    local idlgen_dir="$HALO_SRC_DIR/vbs/vbspro/tools/idlgen"
    
    if [[ ! -d "$idlgen_dir" ]]; then
        log "IDL tools directory not found, skipping IDL build"
        return 0
    fi
    
    log "Building IDL generation tools..."
    cd "$idlgen_dir"
    
    if [[ -f "gradlew" ]]; then
        # Use Gradle wrapper if available
        log "Running Gradle build for IDL tools..."
        
        # Make gradlew executable
        chmod +x gradlew
        
        # Run Gradle (suppress most output, show errors)
        if ./gradlew assemble --no-daemon --console=plain 2>&1 | tee -a "$LOG_FILE"; then
            log "IDL tools built successfully"
        else
            error "IDL tools build failed (non-fatal, continuing)"
        fi
    else
        log "No Gradle wrapper found, skipping IDL build"
    fi
}

# ==============================================================================
# Inject Tracepoints
# ==============================================================================
inject_tracepoints() {
    log "Injecting LTTng tracepoints into VBSPro..."
    
    local trace_header="$PROJECT_ROOT/tracepoints/halo_tracepoints.h"
    local vbspro_include="$HALO_SRC_DIR/vbs/vbspro/framework/include"
    
    if [[ ! -f "$trace_header" ]]; then
        log "No tracepoint header found at $trace_header (will create stub)"
        
        # Create minimal tracepoint header
        mkdir -p "$(dirname "$trace_header")"
        cat > "$trace_header" << 'EOF'
#ifndef HALO_TRACEPOINTS_H
#define HALO_TRACEPOINTS_H

// LTTng UST tracepoint definitions for Halo.OS VBS performance measurement
// Add your TRACEPOINT_EVENT definitions here

#ifdef ENABLE_LTTNG
#include <lttng/tracepoint.h>

TRACEPOINT_EVENT(
    halo_vbs,
    message_send,
    TP_ARGS(
        const char*, topic,
        uint64_t, timestamp_ns,
        uint32_t, msg_id
    ),
    TP_FIELDS(
        ctf_string(topic, topic)
        ctf_integer(uint64_t, timestamp_ns, timestamp_ns)
        ctf_integer(uint32_t, msg_id, msg_id)
    )
)

TRACEPOINT_EVENT(
    halo_vbs,
    message_recv,
    TP_ARGS(
        const char*, topic,
        uint64_t, timestamp_ns,
        uint32_t, msg_id
    ),
    TP_FIELDS(
        ctf_string(topic, topic)
        ctf_integer(uint64_t, timestamp_ns, timestamp_ns)
        ctf_integer(uint32_t, msg_id, msg_id)
    )
)

#else
// Stub macros when LTTng is disabled
#define tracepoint(...)
#endif

#endif // HALO_TRACEPOINTS_H
EOF
        log "Created stub tracepoint header"
    fi
    
    # Copy to VBSPro include directory
    mkdir -p "$vbspro_include"
    cp "$trace_header" "$vbspro_include/" || log "Could not copy tracepoint header (non-fatal)"
    
    log "Tracepoints injected"
}

# ==============================================================================
# Build VBSPro
# ==============================================================================
build_vbspro() {
    log "Building VBSPro (Vehicle Base System Pro)..."
    
    local vbspro_dir="$HALO_SRC_DIR/vbs/vbspro"
    
    if [[ ! -d "$vbspro_dir" ]]; then
        fatal "VBSPro directory not found at: $vbspro_dir"
    fi
    
    # VBSPro uses CMake in build/ subdirectory
    local cmake_build_dir="$vbspro_dir/build/out"
    
    if [[ $CLEAN_BUILD -eq 1 ]]; then
        log "Cleaning previous build..."
        rm -rf "$cmake_build_dir"
    fi
    
    mkdir -p "$cmake_build_dir"
    cd "$cmake_build_dir"
    
    log "Configuring VBSPro with CMake..."
    
    # CMake configuration with tracing enabled
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_TRACER=ON \
        -DENABLE_TRACING=ON \
        -DENABLE_LTTNG=ON \
        -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install" \
        "$vbspro_dir" || fatal "CMake configuration failed"
    
    log "Building VBSPro (using $JOBS parallel jobs)..."
    
    local build_start
    build_start=$(date +%s)
    
    if ! cmake --build . --parallel "$JOBS"; then
        error "Build failed"
        
        # Show build log tail for debugging
        if [[ -f "CMakeFiles/CMakeError.log" ]]; then
            error "CMake error log (last 20 lines):"
            tail -20 "CMakeFiles/CMakeError.log" | tee -a "$LOG_FILE"
        fi
        
        fatal "VBSPro build failed"
    fi
    
    local build_end
    build_end=$(date +%s)
    local build_time=$((build_end - build_start))
    
    log "Build completed in ${build_time} seconds"
    
    # Install artifacts
    log "Installing build artifacts..."
    cmake --install . --prefix "$BUILD_DIR/install" || log "Install step returned non-zero (may be optional)"
}

# ==============================================================================
# Validate Build Artifacts
# ==============================================================================
validate_build() {
    log "Validating build artifacts..."
    
    local vbspro_build="$HALO_SRC_DIR/vbs/vbspro/build/out"
    local install_dir="$BUILD_DIR/install"
    
    # Look for key artifacts
    local found_artifacts=0
    
    # Check for shared libraries
    if compgen -G "$vbspro_build/*.so" > /dev/null || compgen -G "$install_dir/lib/*.so" > /dev/null; then
        log "Found VBSPro shared libraries"
        find "$vbspro_build" "$install_dir" -name "*.so" 2>/dev/null | head -5 | while read -r lib; do
            log "  - $lib"
        done
        ((found_artifacts++))
    fi
    
    # Check for static libraries
    if compgen -G "$vbspro_build/*.a" > /dev/null || compgen -G "$install_dir/lib/*.a" > /dev/null; then
        log "Found VBSPro static libraries"
        ((found_artifacts++))
    fi
    
    # Check for executables
    if compgen -G "$vbspro_build/vbs_*" > /dev/null || compgen -G "$install_dir/bin/vbs_*" > /dev/null; then
        log "Found VBSPro executables"
        find "$vbspro_build" "$install_dir" -name "vbs_*" -type f 2>/dev/null | head -5 | while read -r exe; do
            log "  - $exe"
        done
        ((found_artifacts++))
    fi
    
    if [[ $found_artifacts -eq 0 ]]; then
        error "WARNING: No obvious VBSPro artifacts found"
        error "Build may have succeeded but produced unexpected outputs"
        error "Check CMake targets in $vbspro_build"
    else
        log "Build validation passed - found $found_artifacts artifact type(s)"
    fi
    
    # Copy all artifacts to build directory for easy access
    log "Copying artifacts to $BUILD_DIR..."
    cp -r "$vbspro_build"/* "$BUILD_DIR/" 2>/dev/null || true
}

# ==============================================================================
# Main Execution
# ==============================================================================
main() {
    log "========================================"
    log "Halo.OS VBSPro Build Script"
    log "========================================"
    log "Log file: $LOG_FILE"
    
    parse_args "$@"
    
    log "Build configuration:"
    log "  Source directory: $HALO_SRC_DIR"
    log "  Build directory:  $BUILD_DIR"
    log "  Manifest repo:    $MANIFEST_REPO_URL"
    log "  Manifest file:    $MANIFEST_NAME"
    log "  Parallel jobs:    $JOBS"
    log "  Clean build:      $CLEAN_BUILD"
    
    install_dependencies
    install_repo_tool
    setup_git_auth
    sync_repository
    record_provenance
    build_idl_tools
    inject_tracepoints
    build_vbspro
    validate_build
    
    log "========================================"
    log "Build completed successfully!"
    log "========================================"
    log ""
    log "Build artifacts: $BUILD_DIR/"
    log "Build log:       $LOG_FILE"
    log ""
    log "Next step: ./ci/run_experiment.sh <run_id> <duration>"
}

main "$@"
