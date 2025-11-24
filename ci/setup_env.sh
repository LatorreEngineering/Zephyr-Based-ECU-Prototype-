#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# ci/setup_env.sh
# - Initializes a west workspace, fetches Zephyr branch to obtain concrete SHA,
#   patches manifests/pinned_manifest.xml with the SHA, then re-syncs workspace
#   using the pinned manifest to guarantee reproducible builds.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_DIR="${WORKSPACE_DIR:-${HOME}/zephyr-workspace}"

PATCH_SCRIPT="${PROJECT_ROOT}/manifests/patch_pinned_manifest.sh"
PINNED_MANIFEST="${PROJECT_ROOT}/manifests/pinned_manifest.xml"

# Colors for nicer logs
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --------------------------------------------------------------------------
# Ensure required commands exist (install minimal Python deps if missing)
# --------------------------------------------------------------------------
ensure_dependencies() {
    log "Checking for python3 and pip..."
    if ! command -v python3 >/dev/null 2>&1; then
        err "python3 is required"
        exit 1
    fi
    if ! command -v pip >/dev/null 2>&1 && ! command -v pip3 >/dev/null 2>&1; then
        log "pip not found; attempting to install python3-pip via apt-get (CI only)"
        if command -v sudo >/dev/null 2>&1; then
            sudo apt-get update -y
            sudo apt-get install -y python3-pip
        else
            err "pip/pip3 not available and sudo not present"
            exit 1
        fi
    fi

    log "Ensuring west is installed..."
    if ! command -v west >/dev/null 2>&1; then
        python3 -m pip install --upgrade pip
        python3 -m pip install --upgrade west lxml pyelftools cantools pyyaml intelhex pyserial pytest
    fi
}

# --------------------------------------------------------------------------
# Create workspace and fetch Zephyr (branch-based) to read commit SHA
# --------------------------------------------------------------------------
fetch_branch_and_extract_sha() {
    log "Preparing workspace at: ${WORKSPACE_DIR}"
    mkdir -p "${WORKSPACE_DIR}"
    cd "${WORKSPACE_DIR}"

    log "Initializing west workspace (using local manifest/west.yml in project repo)..."
    # west init -l points to the project repo which contains west.yml
    west init -l "${PROJECT_ROOT}"

    log "Fetching modules (shallow) using branch references so we can read the actual Zephyr commit SHA..."
    # This will clone zephyr at the branch specified in west.yml/west manifest (v3.7-branch)
    west update --narrow --fetch-opt=--depth=1

    # Verify zephyr was fetched
    if [[ ! -d "${WORKSPACE_DIR}/zephyr/.git" ]]; then
        err "zephyr repo not found in workspace after 'west update'"
        exit 1
    fi

    # Get precise commit SHA for Zephyr
    ZEPHYR_SHA=$(git -C "${WORKSPACE_DIR}/zephyr" rev-parse --verify HEAD)
    if [[ -z "${ZEPHYR_SHA:-}" ]]; then
        err "Failed to determine Zephyr commit SHA"
        exit 1
    fi

    log "Extracted Zephyr commit SHA: ${ZEPHYR_SHA}"
    # Write to a file in project root for the patch script to consume if desired
    echo "${ZEPHYR_SHA}" > "${PROJECT_ROOT}/zephyr_sha.txt"

    # Export variable to caller env
    echo "${ZEPHYR_SHA}"
}

# --------------------------------------------------------------------------
# Patch pinned manifest (in project repository)
# --------------------------------------------------------------------------
patch_pinned_manifest() {
    local sha="$1"
    if [[ -z "${sha}" ]]; then
        err "patch_pinned_manifest requires a SHA"
        exit 1
    fi

    if [[ ! -x "${PATCH_SCRIPT}" ]]; then
        if [[ -f "${PATCH_SCRIPT}" ]]; then
            chmod +x "${PATCH_SCRIPT}"
        else
            err "Patch script not found: ${PATCH_SCRIPT}"
            exit 1
        fi
    fi

    log "Patching ${PINNED_MANIFEST} with SHA ${sha}..."
    # Set environment variable for the script
    ZEPHYR_SHA="${sha}" bash "${PATCH_SCRIPT}"
}

# --------------------------------------------------------------------------
# Reconfigure west to use pinned manifest file and re-sync using SHAs
# --------------------------------------------------------------------------
switch_to_pinned_manifest_and_sync() {
    log "Configuring west to use pinned manifest: ${PINNED_MANIFEST}"
    cd "${WORKSPACE_DIR}"
    # west config manifest.file accepts path relative to workspace; give absolute path
    west config manifest.file "${PINNED_MANIFEST}"

    log "Updating workspace using pinned manifest (will fetch exact SHAs)..."
    west update --narrow --fetch-opt=--depth=1

    log "Exporting Zephyr build configuration"
    west zephyr-export
}

# --------------------------------------------------------------------------
# Generate .env.ci (helpful helper for builds)
# --------------------------------------------------------------------------
generate_env_file() {
    local env_file="${PROJECT_ROOT}/.env.ci"
    cat > "${env_file}" <<EOF
# Generated by ci/setup_env.sh
export ZEPHYR_BASE="${WORKSPACE_DIR}/zephyr"
export ZEPHYR_SDK_INSTALL_DIR="\${HOME}/zephyr-sdk-\${ZEPHYR_SDK_VERSION:-0.16.8}"
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export GNUARMEMB_TOOLCHAIN_PATH="\${ZEPHYR_SDK_INSTALL_DIR}/arm-zephyr-eabi"
export PROJECT_ROOT="${PROJECT_ROOT}"
export WORKSPACE_DIR="${WORKSPACE_DIR}"
export CMAKE_PREFIX_PATH="\${ZEPHYR_BASE}"
EOF
    log "Created environment file: ${env_file}"
    log "Source it before builds: source ${env_file}"
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
main() {
    log "Starting CI workspace setup"
    ensure_dependencies

    # Step 1: fetch branch and extract SHA
    ZEPHYR_SHA=$(fetch_branch_and_extract_sha)

    # Step 2: patch manifest in project repository
    patch_pinned_manifest "${ZEPHYR_SHA}"

    # Step 3: reconfigure workspace to use pinned manifest and update to SHAs
    switch_to_pinned_manifest_and_sync

    # Step 4: generate helper env file
    generate_env_file

    log "Setup complete"
}

main "$@"
