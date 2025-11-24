#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Setup Zephyr workspace and patch pinned manifest
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_DIR="${WORKSPACE_DIR:-${HOME}/zephyr-workspace}"

PATCH_SCRIPT="${PROJECT_ROOT}/manifests/patch_pinned_manifest.sh"
PINNED_MANIFEST="${PROJECT_ROOT}/manifests/pinned_manifest.xml"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Ensure dependencies
ensure_dependencies() {
    command -v python3 >/dev/null || { err "python3 missing"; exit 1; }
    command -v pip >/dev/null || { err "pip missing"; exit 1; }
    command -v west >/dev/null || python3 -m pip install --upgrade west lxml pyelftools cantools pyyaml intelhex pyserial pytest
}

# Fetch Zephyr branch to SHA
fetch_sha() {
    mkdir -p "$WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"
    west init -l "$PROJECT_ROOT"
    west update --narrow --fetch-opt=--depth=1
    if [[ ! -d "$WORKSPACE_DIR/zephyr/.git" ]]; then
        err "Zephyr repo missing"
        exit 1
    fi
    SHA=$(git -C "$WORKSPACE_DIR/zephyr" rev-parse HEAD)
    echo "$SHA" > "$PROJECT_ROOT/zephyr_sha.txt"
    echo "$SHA"
}

# Patch manifest
patch_manifest() {
    SHA="$1"
    ZEPHYR_SHA="$SHA" bash "$PATCH_SCRIPT"
}

# Switch to pinned manifest and sync
sync_pinned() {
    cd "$WORKSPACE_DIR"
    west config manifest.file "$PINNED_MANIFEST"
    west update --narrow --fetch-opt=--depth=1
    west zephyr-export
}

# Generate .env.ci
generate_env_file() {
    cat > "$PROJECT_ROOT/.env.ci" <<EOF
export ZEPHYR_BASE="$WORKSPACE_DIR/zephyr"
export WORKSPACE_DIR="$WORKSPACE_DIR"
export PROJECT_ROOT="$PROJECT_ROOT"
EOF
}

# Main
main() {
    log "Starting setup"
    ensure_dependencies
    SHA=$(fetch_sha)
    log "Patching pinned manifest"
    patch_manifest "$SHA"
    log "Syncing workspace to pinned manifest"
    sync_pinned
    generate_env_file
    log "Setup complete"
}

main "$@"
