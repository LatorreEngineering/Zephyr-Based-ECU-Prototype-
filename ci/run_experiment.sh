#!/usr/bin/env bash
# =============================================================================
# Zephyr ECU Prototype - Experimental Validation Script
# =============================================================================
# Purpose: Run automated experiments with CAN/LIN simulation
# Usage: ./ci/run_experiment.sh [options]
# Options:
#   -d, --duration SEC     Experiment duration in seconds (default: 60)
#   -o, --output FILE      Output VBS file path
#   -c, --can-interface    CAN interface name (default: vcan0)
#   -t, --test-case        Specific test case to run
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULTS_DIR="${PROJECT_ROOT}/results"
DURATION=60
CAN_INTERFACE="vcan0"
OUTPUT_FILE=""
TEST_CASE="full"

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
            -d|--duration)
                DURATION="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -c|--can-interface)
                CAN_INTERFACE="$2"
                shift 2
                ;;
            -t|--test-case)
                TEST_CASE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  -d, --duration SEC     Duration in seconds (default: 60)"
                echo "  -o, --output FILE      Output file path"
                echo "  -c, --can-interface    CAN interface (default: vcan0)"
                echo "  -t, --test-case        Test case (default: full)"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Set default output file
    if [ -z "${OUTPUT_FILE}" ]; then
        OUTPUT_FILE="${RESULTS_DIR}/experiment_$(date +%Y%m%d_%H%M%S).vbs"
    fi
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
# Check Dependencies
# -----------------------------------------------------------------------------
check_dependencies() {
    log_step "Checking Dependencies"
    
    local deps=("python3" "candump" "cansend")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            missing+=("${dep}")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo apt-get install can-utils python3-can"
        exit 1
    fi
    
    # Check Python modules
    if ! python3 -c "import can" 2>/dev/null; then
        log_error "Python 'can' module not found"
        log_info "Install with: pip install python-can"
        exit 1
    fi
    
    log_info "✅ All dependencies available"
}

# -----------------------------------------------------------------------------
# Setup Virtual CAN
# -----------------------------------------------------------------------------
setup_vcan() {
    log_step "Setting Up Virtual CAN Interface"
    
    # Check if interface already exists
    if ip link show "${CAN_INTERFACE}" &> /dev/null; then
        log_info "Interface ${CAN_INTERFACE} already exists"
        
        # Bring it down to reconfigure
        sudo ip link set "${CAN_INTERFACE}" down 2>/dev/null || true
    else
        # Create virtual CAN interface
        log_info "Creating ${CAN_INTERFACE}..."
        sudo modprobe vcan
        sudo ip link add dev "${CAN_INTERFACE}" type vcan
    fi
    
    # Bring interface up
    log_info "Bringing ${CAN_INTERFACE} up..."
    sudo ip link set "${CAN_INTERFACE}" up
    
    # Verify
    if ip link show "${CAN_INTERFACE}" | grep -q "UP"; then
        log_info "✅ ${CAN_INTERFACE} is UP"
    else
        log_error "Failed to bring up ${CAN_INTERFACE}"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Generate Test Stimuli
# -----------------------------------------------------------------------------
generate_stimuli() {
    log_step "Generating Test Stimuli"
    
    local stimuli_script="${RESULTS_DIR}/stimuli.py"
    mkdir -p "${RESULTS_DIR}"
    
    cat > "${stimuli_script}" <<'EOF'
#!/usr/bin/env python3
"""CAN Test Stimuli Generator"""
import can
import time
import sys
import random

def main():
    interface = sys.argv[1] if len(sys.argv) > 1 else 'vcan0'
    duration = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    
    print(f"Generating stimuli on {interface} for {duration}s")
    
    bus = can.interface.Bus(interface, bustype='socketcan')
    
    start_time = time.time()
    msg_count = 0
    
    try:
        while time.time() - start_time < duration:
            # Simulate various ECU messages
            
            # 1. Engine RPM (0x100) - 10 Hz
            rpm = random.randint(800, 6000)
            msg = can.Message(arbitration_id=0x100, 
                             data=[rpm >> 8, rpm & 0xFF],
                             is_extended_id=False)
            bus.send(msg)
            msg_count += 1
            
            # 2. Vehicle Speed (0x200) - 10 Hz
            speed = random.randint(0, 180)
            msg = can.Message(arbitration_id=0x200,
                             data=[speed],
                             is_extended_id=False)
            bus.send(msg)
            msg_count += 1
            
            # 3. Coolant Temp (0x300) - 1 Hz
            if msg_count % 10 == 0:
                temp = random.randint(60, 105)
                msg = can.Message(arbitration_id=0x300,
                                 data=[temp],
                                 is_extended_id=False)
                bus.send(msg)
            
            # 4. UDS Request (0x7DF) - occasional
            if random.random() < 0.01:  # 1% chance
                msg = can.Message(arbitration_id=0x7DF,
                                 data=[0x02, 0x10, 0x01],  # Session control
                                 is_extended_id=False)
                bus.send(msg)
            
            time.sleep(0.1)
            
    except KeyboardInterrupt:
        print(f"\nSent {msg_count} messages")
    finally:
        bus.shutdown()

if __name__ == '__main__':
    main()
EOF
    
    chmod +x "${stimuli_script}"
    log_info "✅ Stimuli script created: ${stimuli_script}"
}

# -----------------------------------------------------------------------------
# Start Data Collection
# -----------------------------------------------------------------------------
start_data_collection() {
    log_step "Starting Data Collection"
    
    local candump_log="${RESULTS_DIR}/candump_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "Recording CAN traffic to: ${candump_log}"
    
    # Start candump in background
    candump -t A -l "${CAN_INTERFACE}" > "${candump_log}" 2>&1 &
    local candump_pid=$!
    
    echo "${candump_pid}" > "${RESULTS_DIR}/candump.pid"
    log_info "candump PID: ${candump_pid}"
}

# -----------------------------------------------------------------------------
# Run Experiment
# -----------------------------------------------------------------------------
run_experiment() {
    log_step "Running Experiment: ${TEST_CASE}"
    
    log_info "Duration: ${DURATION}s"
    log_info "CAN Interface: ${CAN_INTERFACE}"
    log_info "Output: ${OUTPUT_FILE}"
    
    # Start stimuli generator
    local stimuli_script="${RESULTS_DIR}/stimuli.py"
    log_info "Starting test stimuli generator..."
    
    python3 "${stimuli_script}" "${CAN_INTERFACE}" "${DURATION}" &
    local stimuli_pid=$!
    
    echo "${stimuli_pid}" > "${RESULTS_DIR}/stimuli.pid"
    
    # Wait for experiment duration
    log_info "Experiment running..."
    
    local elapsed=0
    while [ ${elapsed} -lt "${DURATION}" ]; do
        sleep 5
        elapsed=$((elapsed + 5))
        printf "\rProgress: %d/%d seconds" "${elapsed}" "${DURATION}"
    done
    
    echo ""
    log_info "✅ Experiment duration completed"
    
    # Wait for stimuli to finish
    wait "${stimuli_pid}" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Stop Data Collection
# -----------------------------------------------------------------------------
stop_data_collection() {
    log_step "Stopping Data Collection"
    
    # Kill candump
    if [ -f "${RESULTS_DIR}/candump.pid" ]; then
        local pid
        pid=$(cat "${RESULTS_DIR}/candump.pid")
        
        if kill -0 "${pid}" 2>/dev/null; then
            log_info "Stopping candump (PID: ${pid})"
            kill "${pid}"
            wait "${pid}" 2>/dev/null || true
        fi
        
        rm -f "${RESULTS_DIR}/candump.pid"
    fi
    
    log_info "✅ Data collection stopped"
}

# -----------------------------------------------------------------------------
# Convert to VBS Format
# -----------------------------------------------------------------------------
convert_to_vbs() {
    log_step "Converting to VBS Format"
    
    local candump_log
    candump_log=$(find "${RESULTS_DIR}" -name "candump_*.log" -type f | sort | tail -n1)
    
    if [ -z "${candump_log}" ] || [ ! -f "${candump_log}" ]; then
        log_error "No candump log found"
        return 1
    fi
    
    log_info "Converting ${candump_log} to VBS..."
    
    # Simple conversion (in production, use proper VBS writer)
    cat > "${OUTPUT_FILE}" <<EOF
; VBS File - Zephyr ECU Experiment
; Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
; Test Case: ${TEST_CASE}
; Duration: ${DURATION}s
; Interface: ${CAN_INTERFACE}

[Header]
Version=1.0
StartTime=$(date +%s)
Duration=${DURATION}

[Data]
EOF
    
    # Append converted CAN data (simplified format)
    # Format: timestamp,id,dlc,data
    awk '{print $1","$2","$3","$4}' "${candump_log}" >> "${OUTPUT_FILE}" || true
    
    log_info "✅ VBS file created: ${OUTPUT_FILE}"
}

# -----------------------------------------------------------------------------
# Generate Summary Report
# -----------------------------------------------------------------------------
generate_summary() {
    log_step "Generating Experiment Summary"
    
    local summary_file="${RESULTS_DIR}/experiment_summary.txt"
    
    cat > "${summary_file}" <<EOF
================================================================================
Zephyr ECU Experimental Validation Summary
================================================================================
Test Case:      ${TEST_CASE}
Duration:       ${DURATION}s
CAN Interface:  ${CAN_INTERFACE}
Timestamp:      $(date -u +%Y-%m-%dT%H:%M:%SZ)

Output Files:
  VBS Data:     ${OUTPUT_FILE}
  CAN Log:      $(find "${RESULTS_DIR}" -name "candump_*.log" | tail -n1)

Statistics:
EOF
    
    # Count messages
    local candump_log
    candump_log=$(find "${RESULTS_DIR}" -name "candump_*.log" -type f | sort | tail -n1)
    
    if [ -f "${candump_log}" ]; then
        local msg_count
        msg_count=$(wc -l < "${candump_log}")
        echo "  Total Messages: ${msg_count}" >> "${summary_file}"
        echo "  Avg Rate:       $((msg_count / DURATION)) msg/s" >> "${summary_file}"
    fi
    
    echo "" >> "${summary_file}"
    echo "Next Steps:" >> "${summary_file}"
    echo "  1. Analyze results: python3 ci/analyze_vbs.py --input ${OUTPUT_FILE}" >> "${summary_file}"
    echo "  2. Review logs in: ${RESULTS_DIR}" >> "${summary_file}"
    
    cat "${summary_file}"
    log_info "✅ Summary saved: ${summary_file}"
}

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
cleanup() {
    log_info "Cleaning up..."
    
    stop_data_collection
    
    # Remove PID files
    rm -f "${RESULTS_DIR}"/*.pid
    
    log_info "✅ Cleanup complete"
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
main() {
    log_step "Zephyr ECU Experimental Validation"
    
    parse_args "$@"
    
    # Setup trap for cleanup
    trap cleanup EXIT INT TERM
    
    check_dependencies
    setup_vcan
    generate_stimuli
    start_data_collection
    run_experiment
    stop_data_collection
    convert_to_vbs
    generate_summary
    
    log_step "✅ Experiment Complete"
    echo ""
    log_info "Results available in: ${RESULTS_DIR}"
    log_info "VBS file: ${OUTPUT_FILE}"
    echo ""
}

# Run main function
main "$@"
