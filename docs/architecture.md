# Zephyr ECU Architecture Documentation

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Layer Organization](#layer-organization)
4. [Module Interfaces](#module-interfaces)
5. [Data Flow](#data-flow)
6. [Threading Model](#threading-model)
7. [Memory Management](#memory-management)
8. [Safety Mechanisms](#safety-mechanisms)

---

## Overview

The Zephyr ECU implements a **layered, AUTOSAR-inspired architecture** optimized for automotive applications. The design emphasizes:

- **Modularity**: Clear separation of concerns
- **Testability**: Each layer independently testable
- **Safety**: Fault detection and graceful degradation
- **Scalability**: Easy addition of new protocols/services
- **Maintainability**: Consistent coding patterns

### Design Principles

1. **Hardware Abstraction**: Board-specific code isolated in HAL
2. **Protocol Independence**: Network layer agnostic to upper layers
3. **Service-Oriented**: UDS services as independent modules
4. **Event-Driven**: Asynchronous communication via queues
5. **Fail-Safe**: Watchdog supervision and error recovery

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     APPLICATION LAYER                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   ECU State  │  │   Sensor     │  │   Fault      │      │
│  │   Machine    │  │   Simulation │  │   Injection  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │
┌─────────────────────────────┼───────────────────────────────┐
│                     DIAGNOSTICS LAYER                        │
│  ┌──────────────────────────┴───────────────────────────┐   │
│  │              UDS Server (ISO 14229)                   │   │
│  ├───────────────────────────────────────────────────────┤   │
│  │  Session │ Security │ DTC │ RDBI │ WDBI │ Routine    │   │
│  │  Control │ Access   │ Mgmt│      │      │ Control    │   │
│  └───────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────┬───────────────────────────┐   │
│  │     ISO-TP Transport      │      DTC Manager          │   │
│  └──────────────────────────┴───────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │
┌─────────────────────────────┼───────────────────────────────┐
│                      NETWORK LAYER                           │
│  ┌──────────────────────────┴───────────────────────────┐   │
│  │           Communication Manager                       │   │
│  │     (Message routing, buffering, prioritization)     │   │
│  └───────────────────────────┬───────────────────────────┘   │
│  ┌──────────────────────┬────┴────┬──────────────────────┐  │
│  │   CAN Transport      │ LIN     │   Future: Ethernet   │  │
│  │   (FlexCAN driver)   │ Master  │   (SOME/IP, etc.)    │  │
│  └──────────────────────┴─────────┴──────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │
┌─────────────────────────────┼───────────────────────────────┐
│                    HARDWARE ABSTRACTION                      │
│  ┌──────────────────────────┴───────────────────────────┐   │
│  │               Zephyr RTOS Services                    │   │
│  │    (Device drivers, timers, threads, synchronization)│   │
│  └───────────────────────────────────────────────────────┘   │
│  ┌───────────────────────────────────────────────────────┐   │
│  │              Board Support Package (BSP)              │   │
│  │         (FRDM-K64F: Kinetis K64F peripherals)         │   │
│  └───────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Layer Organization

### 1. Application Layer (`app/`)

**Responsibility**: ECU-specific business logic

#### Modules

**ECU State Machine** (`ecu_state_machine.c/h`)
- Manages ignition states: OFF → ACC → ON → CRANK → RUN
- Coordinates mode transitions
- Triggers watchdog updates

```c
typedef enum {
    ECU_STATE_OFF,
    ECU_STATE_ACCESSORY,
    ECU_STATE_IGNITION_ON,
    ECU_STATE_CRANKING,
    ECU_STATE_RUNNING,
    ECU_STATE_ERROR
} ecu_state_t;
```

**Sensor Simulation** (`sensor_sim.c/h`)
- Generates realistic sensor values (RPM, temp, voltage)
- Supports fault injection for testing
- Periodic updates via timer workqueue

**Fault Injection** (`fault_injection.c/h`)
- Simulates CAN timeout, over-temperature, LIN errors
- Triggers DTC generation
- Used for validation and testing

**Watchdog Supervisor** (`watchdog_supervisor.c/h`)
- Monitors system health
- Feeds hardware watchdog
- Detects application hangs

---

### 2. Diagnostics Layer (`diagnostics/`)

**Responsibility**: UDS protocol implementation (ISO 14229)

#### UDS Server (`uds_server.c/h`)
- Entry point for all diagnostic requests
- Service dispatcher
- Response formatting
- Negative response handling

#### Session Management (`uds_session.c/h`)
```c
typedef enum {
    UDS_SESSION_DEFAULT = 0x01,
    UDS_SESSION_PROGRAMMING = 0x02,
    UDS_SESSION_EXTENDED = 0x03
} uds_session_type_t;
```

- Tracks current diagnostic session
- Enforces service availability per session
- Handles session timeouts (S3 timer)

#### DTC Manager (`dtc_manager.c/h`)
```c
typedef struct {
    uint32_t dtc_code;          // ISO 14229-1 format
    uint8_t status_byte;        // Status mask
    uint16_t occurrence_count;
    uint32_t timestamp;
} dtc_entry_t;
```

- Stores fault memory (NVS-backed)
- Manages DTC status bits
- Supports freeze frame data

#### UDS Services (`uds_services/`)

Each service implemented as independent module:

| File | Service | Description |
|------|---------|-------------|
| `uds_10_session_control.c` | 0x10 | Change diagnostic session |
| `uds_11_ecu_reset.c` | 0x11 | Soft/hard reset |
| `uds_14_clear_dtc.c` | 0x14 | Clear fault memory |
| `uds_19_read_dtc.c` | 0x19 | Read DTCs by status |
| `uds_22_rdbi.c` | 0x22 | Read data identifiers |
| `uds_27_security_access.c` | 0x27 | Seed/key authentication |
| `uds_2e_write_did.c` | 0x2E | Write data identifiers |
| `uds_31_routine_control.c` | 0x31 | Execute routines |
| `uds_34_request_download.c` | 0x34 | Initiate download |
| `uds_36_transfer_data.c` | 0x36 | Transfer firmware blocks |
| `uds_37_transfer_exit.c` | 0x37 | Complete download |

---

### 3. Network Layer (`network/`)

**Responsibility**: Multi-protocol message handling

#### Communication Manager (`comm_manager.c/h`)
- **Message Routing**: Directs incoming messages to correct handler
- **Queue Management**: Separate TX/RX queues per protocol
- **Priority Scheduling**: High-priority messages (UDS) preempt low-priority
- **Flow Control**: Prevents queue overflow

```c
typedef struct {
    uint32_t msg_id;
    uint8_t data[64];
    uint8_t length;
    uint8_t priority;
    protocol_type_t protocol;
} comm_message_t;
```

#### CAN Transport (`can/can_transport.c/h`)
- Zephyr CAN API wrapper
- Hardware filtering configuration
- Error frame handling
- Bus-off recovery

#### LIN Master (`lin/lin_driver.c/h`, `lin_scheduler.c/h`)
- **UART-Based Timing**: Precise bit timing for LIN sync break
- **Schedule Tables**: Deterministic slot execution
- **PID Calculation**: Parity bits per LIN 2.x
- **Enhanced Checksum**: Full frame protection

```c
typedef struct {
    uint8_t pid;
    uint8_t data[8];
    uint8_t length;
    uint16_t period_ms;
    bool is_publisher;
} lin_frame_t;
```

---

### 4. Storage Layer (`storage/`)

**Responsibility**: Persistent data management

#### NVS DTC Storage (`nvs_dtc_storage.c/h`)
- Uses Zephyr NVS (Non-Volatile Storage) subsystem
- Flash wear leveling
- Atomic write operations
- Power-loss protection

**Storage Layout**:
```
Flash Partition: 0x7F000 - 0x80000 (4 KB)
├── DTC Count: [4 bytes]
├── DTC Entry 0: [16 bytes]
├── DTC Entry 1: [16 bytes]
...
└── DTC Entry N: [16 bytes]
```

---

## Module Interfaces

### Inter-Module Communication

**Design Pattern**: Loose coupling via callbacks and queues

#### Example: CAN → UDS Flow

```c
// 1. CAN driver receives frame
void can_rx_callback(const struct can_frame *frame) {
    comm_message_t msg = {
        .msg_id = frame->id,
        .length = frame->dlc,
        .protocol = PROTOCOL_CAN
    };
    memcpy(msg.data, frame->data, frame->dlc);
    
    // 2. Enqueue to comm manager
    comm_manager_receive(&msg);
}

// 3. Comm manager routes to ISO-TP
void comm_manager_receive(comm_message_t *msg) {
    if (is_isotp_frame(msg->msg_id)) {
        isotp_receive(msg);
    }
}

// 4. ISO-TP reassembles and calls UDS
void isotp_frame_complete(uint8_t *data, uint16_t len) {
    uds_server_process_request(data, len);
}

// 5. UDS dispatches to service handler
void uds_server_process_request(uint8_t *req, uint16_t len) {
    uint8_t sid = req[0];
    switch (sid) {
        case 0x10:
            uds_10_session_control_handler(req, len);
            break;
        // ...
    }
}
```

---

## Data Flow

### Diagnostic Request Flow

```
Tester Tool
     │
     │ (ISO-TP)
     ▼
┌─────────────┐
│ CAN Driver  │ → Hardware RX FIFO
└─────────────┘
     │
     ▼
┌─────────────────┐
│  Comm Manager   │ → Message Queue
└─────────────────┘
     │
     ▼
┌─────────────────┐
│   ISO-TP Layer  │ → Reassembly Buffer
└─────────────────┘
     │
     ▼
┌─────────────────┐
│   UDS Server    │ → Service Dispatcher
└─────────────────┘
     │
     ├─→ 0x10: Session Control
     ├─→ 0x22: Read Data
     ├─→ 0x27: Security Access
     └─→ ...
```

### Response Path (Reverse)

```
UDS Service Handler
     │
     ▼
UDS Server (Format Response)
     │
     ▼
ISO-TP (Segment if needed)
     │
     ▼
Comm Manager (Queue for TX)
     │
     ▼
CAN Driver (Transmit)
     │
     ▼
Tester Tool
```

---

## Threading Model

### Thread Architecture

```
┌────────────────────────────────────────────────────────────┐
│  Main Thread (Priority: 5)                                 │
│  - System initialization                                   │
│  - Module startup                                          │
│  - Idle loop (K_FOREVER sleep)                             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│  CAN RX Thread (Priority: 7 - HIGH)                        │
│  - Process incoming CAN frames                             │
│  - Feed to comm manager queue                              │
│  - Non-blocking, interrupt-driven                          │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│  UDS Processing Thread (Priority: 6)                       │
│  - Dequeue diagnostic requests                             │
│  - Execute service handlers                                │
│  - Generate responses                                      │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│  LIN Scheduler Thread (Priority: 8 - REALTIME)             │
│  - Execute LIN schedule table                              │
│  - Deterministic slot timing                               │
│  - UART TX/RX handling                                     │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│  Application Thread (Priority: 4)                          │
│  - ECU state machine updates                               │
│  - Sensor value updates                                    │
│  - Watchdog feeding                                        │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│  System Workqueue (Priority: -1)                           │
│  - Deferred work items                                     │
│  - Timers, delayed callbacks                               │
└────────────────────────────────────────────────────────────┘
```

### Synchronization Mechanisms

- **Mutexes**: Protect shared data structures (DTC list, session state)
- **Semaphores**: Signal event completion (ISO-TP transfer done)
- **Message Queues**: Inter-thread communication (CAN → UDS)
- **Atomic Operations**: Lock-free counters

---

## Memory Management

### Static Allocation Strategy

**Design Decision**: No dynamic allocation (malloc forbidden)

**Rationale**:
1. Deterministic memory usage
2. No fragmentation issues
3. MISRA-C compliance
4. Safety certification requirements

### Memory Pools

```c
// Example: ISO-TP buffer pool
#define ISOTP_MAX_FRAMES 4
static uint8_t isotp_rx_buffers[ISOTP_MAX_FRAMES][4095];
static bool isotp_buffer_in_use[ISOTP_MAX_FRAMES];

// Example: DTC storage
#define MAX_DTCS 256
static dtc_entry_t dtc_storage[MAX_DTCS];
```

### Stack Sizing

| Thread | Stack Size | Rationale |
|--------|-----------|-----------|
| Main | 2048 bytes | Minimal, enters sleep quickly |
| CAN RX | 1024 bytes | Simple frame copying |
| UDS | 4096 bytes | Complex service logic |
| LIN | 1024 bytes | Timing-critical, minimal work |
| App | 2048 bytes | State machine + sensors |

---

## Safety Mechanisms

### 1. Watchdog Supervision

```c
void watchdog_supervisor_init(void) {
    wdt_dev = device_get_binding(DT_LABEL(DT_ALIAS(watchdog0)));
    
    struct wdt_timeout_cfg wdt_config = {
        .window.min = 0,
        .window.max = 1000,  // 1 second timeout
        .callback = watchdog_callback,
        .flags = WDT_FLAG_RESET_SOC
    };
    
    wdt_install_timeout(wdt_dev, &wdt_config);
    wdt_setup(wdt_dev, WDT_OPT_PAUSE_HALTED_BY_DBG);
}
```

### 2. Error Recovery

- **CAN Bus-Off**: Automatic recovery with exponential backoff
- **LIN Frame Error**: Retry with timeout
- **UDS Request Timeout**: NRC 0x78 (Response Pending)
- **Flash Write Failure**: Retry with backup sector

### 3. Fault Detection

```c
typedef enum {
    FAULT_CAN_TIMEOUT = 0x00C101,
    FAULT_OVERHEAT = 0x00C102,
    FAULT_UNDERVOLTAGE = 0x00C103,
    FAULT_LIN_BUS_ERROR = 0x00C104
} fault_code_t;
```

### 4. Safe State

On critical fault:
1. **Disable non-essential functions**
2. **Set DTCs**
3. **Enter safe mode (extended session)**
4. **Maintain diagnostic communication**
5. **Log to NVS**

---

## Configuration

### Kconfig Options

```kconfig
# Application settings
CONFIG_ECU_ENABLE_FAULT_INJECTION=y
CONFIG_ECU_SENSOR_UPDATE_PERIOD_MS=100
CONFIG_ECU_WATCHDOG_TIMEOUT_MS=1000

# Network settings
CONFIG_CAN_BITRATE=500000
CONFIG_LIN_BAUDRATE=19200
CONFIG_ISOTP_RX_BUFFER_COUNT=4

# Diagnostics
CONFIG_UDS_MAX_MESSAGE_SIZE=4095
CONFIG_UDS_SESSION_TIMEOUT_MS=5000
CONFIG_UDS_SECURITY_SEED_LENGTH=4
```

### Device Tree Overlays

```dts
// boards/frdm_k64f.overlay
&flexcan0 {
    status = "okay";
    bus-speed = <500000>;
};

&uart3 {
    status = "okay";
    current-speed = <19200>;
    // LIN transceiver
};

&flash0 {
    partitions {
        dtc_partition: partition@7f000 {
            label = "dtc-storage";
            reg = <0x0007f000 0x1000>;
        };
    };
};
```

---

## Performance Characteristics

### Measured Performance (FRDM-K64F @ 120 MHz)

| Metric | Value | Notes |
|--------|-------|-------|
| CAN RX Latency | < 100 µs | Interrupt to queue |
| UDS Response Time | < 10 ms | Simple RDBI |
| LIN Frame Period | ±50 µs | Schedule accuracy |
| DTC Write Time | < 5 ms | Flash operation |
| Watchdog Feed Jitter | < 1 ms | Deterministic |

### Resource Usage

| Resource | Usage | Available |
|----------|-------|-----------|
| Flash | ~180 KB | 1 MB |
| RAM | ~45 KB | 256 KB |
| Threads | 5 | Configurable |
| Timers | 3 | Hardware |

---

## Future Enhancements

### Planned Features

1. **Multi-Core Support**: AMP/SMP on dual-core MCUs
2. **Ethernet**: SOME/IP, DoIP
3. **Secure Boot**: MCUboot integration
4. **OTA Updates**: FOTA via CAN/Ethernet
5. **ASIL-B Certification**: Safety manual, formal verification

### Scalability Path

```
Current: Single-Core, CAN/LIN
    ↓
Phase 2: Dual-Core, Add Ethernet
    ↓
Phase 3: ASIL-B, Secure Boot
    ↓
Future: ASIL-D, Hypervisor
```

---

## References

- **ISO 14229-1**: Unified Diagnostic Services (UDS)
- **ISO 15765-2**: ISO-TP Protocol
- **LIN 2.2A**: Specification Package
- **AUTOSAR 4.4**: Software Architecture
- **Zephyr RTOS**: Documentation v3.7

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-21  
**Author**: Latorre Engineering
