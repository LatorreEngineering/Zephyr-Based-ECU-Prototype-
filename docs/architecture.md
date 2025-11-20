# Zephyr ECU Prototype Architecture

## Overview

This project implements a **fully functional automotive-style ECU** on **Zephyr RTOS**, targeting **NXP FRDM-K64F**. It features:

- CAN bus communication with ISO-TP transport
- LIN Master implementation (UART-based)
- Full UDS stack (ISO 14229)
- DTC management and persistent storage
- ECU application logic (state machine, sensors, fault injection)

---

## System Components

| Module | Description |
|--------|-------------|
| `app/` | ECU application logic: FSM, sensor simulation, fault injection, watchdog |
| `network/` | Communication stack: CAN, LIN, comm manager |
| `diagnostics/` | UDS server, DTC manager, ISO-TP transport |
| `storage/` | Persistent storage for DTCs using Zephyr NVS |
| `boards/` | Board overlays and pin configurations |
| `tests/` | Unit tests for all modules |
| `docs/` | Architecture and service documentation |

---

## Data Flow

1. **Sensors** simulate real ECU inputs (RPM, temperature, voltage).  
2. **ECU FSM** evaluates ignition, faults, and triggers state changes.  
3. **Comm Manager** sends periodic CAN and LIN messages.  
4. **UDS Server** handles diagnostic requests via CAN (ISO-TP).  
5. **DTC Manager** logs fault codes persistently.  
6. **Watchdog** monitors system health.

---

## Diagram

[ Sensors ] –> [ ECU FSM ] –> [ Comm Manager ] –> [ CAN / LIN ]
|
v
[ UDS Server ]
|
v
[ DTC Manager ] –> [ NVS Storage ]
