# SPDX-License-Identifier: Apache-2.0
# Zephyr-Based ECU Prototype - Root CMakeLists.txt
# Aligned with Volvo Non-AUTOSAR RFI Architecture

cmake_minimum_required(VERSION 3.20.0)

# ============================================================================
# PROJECT METADATA & VERSION CONTROL
# ============================================================================
set(ECU_VERSION_MAJOR 1)
set(ECU_VERSION_MINOR 0)
set(ECU_VERSION_PATCH 0)
set(ECU_VERSION "${ECU_VERSION_MAJOR}.${ECU_VERSION_MINOR}.${ECU_VERSION_PATCH}")

# Build timestamp for reproducibility tracking
string(TIMESTAMP BUILD_TIMESTAMP UTC)
execute_process(
    COMMAND git rev-parse --short HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_HASH
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)

# ============================================================================
# ZEPHYR PROJECT SETUP
# ============================================================================
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(zephyr_ecu_prototype VERSION ${ECU_VERSION})

# ============================================================================
# CONFIGURATION OPTIONS
# ============================================================================
option(ENABLE_EXPERIMENTAL_MODE "Enable experimental features for CI testing" OFF)
option(ENABLE_FAULT_INJECTION "Enable runtime fault injection" ON)
option(ENABLE_VERBOSE_LOGGING "Enable detailed diagnostic logging" OFF)
option(BUILD_TESTS "Build unit tests instead of main application" OFF)

# ============================================================================
# COMPILER FLAGS & SAFETY OPTIONS
# ============================================================================
zephyr_compile_options(
    -Wall
    -Wextra
    -Werror
    -Wno-unused-parameter
    -ffunction-sections
    -fdata-sections
)

# Safety-critical build options
if(CONFIG_MISRA_COMPLIANCE)
    zephyr_compile_options(-Wconversion -Wsign-conversion)
endif()

# ============================================================================
# VERSION DEFINITIONS
# ============================================================================
zephyr_compile_definitions(
    ECU_VERSION_MAJOR=${ECU_VERSION_MAJOR}
    ECU_VERSION_MINOR=${ECU_VERSION_MINOR}
    ECU_VERSION_PATCH=${ECU_VERSION_PATCH}
    ECU_BUILD_TIMESTAMP="${BUILD_TIMESTAMP}"
    ECU_GIT_COMMIT="${GIT_COMMIT_HASH}"
)

# ============================================================================
# SOURCE FILES - MODULAR ORGANIZATION
# ============================================================================

# Core Application Layer
target_sources(app PRIVATE
    app/main.c
    app/ecu_state_machine.c
    app/sensor_sim.c
    app/watchdog_supervisor.c
)

if(ENABLE_FAULT_INJECTION)
    target_sources(app PRIVATE app/fault_injection.c)
    zephyr_compile_definitions(ENABLE_FAULT_INJECTION=1)
endif()

# Network Layer
target_sources(app PRIVATE
    network/comm_manager.c
    network/can/can_transport.c
    network/lin/lin_driver.c
    network/lin/lin_scheduler.c
)

# Diagnostics Layer - Full UDS Implementation
target_sources(app PRIVATE
    diagnostics/uds_server.c
    diagnostics/uds_session.c
    diagnostics/dtc_manager.c
    diagnostics/transport/isotp_can.c
    
    # UDS Services (ISO 14229)
    diagnostics/uds_services/uds_10_session_control.c
    diagnostics/uds_services/uds_11_ecu_reset.c
    diagnostics/uds_services/uds_14_clear_dtc.c
    diagnostics/uds_services/uds_19_read_dtc.c
    diagnostics/uds_services/uds_22_rdbi.c
    diagnostics/uds_services/uds_23_write_data.c
    diagnostics/uds_services/uds_27_security_access.c
    diagnostics/uds_services/uds_28_communication_control.c
    diagnostics/uds_services/uds_2e_write_did.c
    diagnostics/uds_services/uds_31_routine_control.c
    diagnostics/uds_services/uds_34_request_download.c
    diagnostics/uds_services/uds_36_transfer_data.c
    diagnostics/uds_services/uds_37_transfer_exit.c
)

# Storage Layer
target_sources(app PRIVATE
    storage/nvs_dtc_storage.c
)

# ============================================================================
# INCLUDE DIRECTORIES
# ============================================================================
target_include_directories(app PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/app
    ${CMAKE_CURRENT_SOURCE_DIR}/network
    ${CMAKE_CURRENT_SOURCE_DIR}/network/can
    ${CMAKE_CURRENT_SOURCE_DIR}/network/lin
    ${CMAKE_CURRENT_SOURCE_DIR}/diagnostics
    ${CMAKE_CURRENT_SOURCE_DIR}/diagnostics/uds_services
    ${CMAKE_CURRENT_SOURCE_DIR}/diagnostics/transport
    ${CMAKE_CURRENT_SOURCE_DIR}/storage
)

# ============================================================================
# BOARD-SPECIFIC OVERLAYS
# ============================================================================
if(BOARD STREQUAL "frdm_k64f")
    set(DTC_FILE_SUFFIX boards/frdm_k64f.overlay)
elseif(BOARD STREQUAL "native_posix")
    # Testing configuration
    set(DTC_FILE_SUFFIX boards/native_posix.overlay)
endif()

# ============================================================================
# EXPERIMENTAL CI FEATURES
# ============================================================================
if(ENABLE_EXPERIMENTAL_MODE)
    message(STATUS "🧪 Experimental mode enabled for CI")
    zephyr_compile_definitions(EXPERIMENTAL_MODE=1)
    
    # Enable performance monitoring
    zephyr_compile_definitions(ENABLE_PERF_COUNTERS=1)
endif()

# ============================================================================
# POST-BUILD ACTIONS
# ============================================================================
add_custom_command(TARGET app POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
    COMMAND ${CMAKE_COMMAND} -E echo "ECU Firmware Build Complete"
    COMMAND ${CMAKE_COMMAND} -E echo "Version: ${ECU_VERSION}"
    COMMAND ${CMAKE_COMMAND} -E echo "Git Hash: ${GIT_COMMIT_HASH}"
    COMMAND ${CMAKE_COMMAND} -E echo "Board: ${BOARD}"
    COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
)

# Generate build metadata file
file(WRITE ${CMAKE_BINARY_DIR}/build_info.txt
    "ECU_VERSION=${ECU_VERSION}\n"
    "GIT_COMMIT=${GIT_COMMIT_HASH}\n"
    "BUILD_TIMESTAMP=${BUILD_TIMESTAMP}\n"
    "BOARD=${BOARD}\n"
    "ZEPHYR_VERSION=${ZEPHYR_VERSION}\n"
)

# ============================================================================
# TESTING SUPPORT
# ============================================================================
if(BUILD_TESTS)
    message(STATUS "🧪 Building tests instead of main application")
    # Test builds will use separate CMakeLists in tests/ subdirectories
endif()
