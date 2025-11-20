# Zephyr-Based-ECU-Prototype-

FRDM-K64F | CAN + LIN + ISO-TP + Full UDS | Real ECU Architecture

This project demonstrates a fully functional automotive-style ECU implemented on top of the Zephyr RTOS, targeting the NXP FRDM-K64F.

It includes:

✔ CAN bus communication

✔ LIN Master implementation (UART-based)

✔ Full UDS diagnostics stack (ISO 14229)

✔ ISO-TP transport over CAN

✔ DTC storage using Zephyr NVS subsystem

✔ Real ECU behavior (state machine, sensor simulation, watchdog)

✔ Fault injection & error handling

✔ Clean, Autosar-inspired architecture

⸻

🛠 Supported Board

FRDM-K64F
	•	Kinetis K64 MCU
	•	Integrated CAN controller
	•	Excellent Zephyr support
	•	LIN via UART (external transceiver recommended)

⸻

📡 Features

CAN
	•	Low-level driver via Zephyr CAN API
	•	ISO-TP transport layer
	•	Queue-based communication manager

LIN
	•	UART-timed LIN master
	•	Schedule tables
	•	PID computation, checksum, sync break generation
	•	Deterministic slot timing

UDS – FULL IMPLEMENTATION

Supported services:
	•	0x10 Diagnostic Session Control
	•	0x11 ECU Reset
	•	0x14 Clear Diagnostics
	•	0x19 Read DTC
	•	0x22 Read Data By Identifier
	•	0x23 Write Data By Identifier
	•	0x27 Security Access (seed/key)
	•	0x28 Communication Control
	•	0x2E WriteDataByIdentifier
	•	0x31 Routine Control
	•	0x34 Request Download
	•	0x36 Transfer Data
	•	0x37 Transfer Exit

DTC Manager
	•	ISO 14229 compliant status bytes
	•	Occurrence counters
	•	Persistent storage in NVS

ECU Application
	•	Ignition state machine
	•	Sensor value simulation (RPM, temperature, voltage)
	•	Fault injection (CAN timeout, over-temp, LIN errors)
	•	Watchdog supervision

# Architecture
see docs/Architecture.md

```text
zephyr-ecu-prototype/
├─ app/
│  ├─ main.c
│  ├─ ecu_state_machine.c
│  ├─ ecu_state_machine.h
│  ├─ sensor_sim.c
│  ├─ sensor_sim.h
│  ├─ fault_injection.c
│  ├─ fault_injection.h
│  ├─ watchdog_supervisor.c
│  └─ watchdog_supervisor.h
│
├─ diagnostics/
│  ├─ uds_server.c
│  ├─ uds_server.h
│  ├─ uds_session.c
│  ├─ uds_session.h
│  ├─ dtc_manager.c
│  ├─ dtc_manager.h
│  ├─ uds_services/
│  │  ├─ uds_10_session_control.c
│  │  ├─ uds_11_ecu_reset.c
│  │  ├─ uds_14_clear_dtc.c
│  │  ├─ uds_19_read_dtc.c
│  │  ├─ uds_22_rdbi.c
│  │  ├─ uds_23_write_data.c
│  │  ├─ uds_27_security_access.c
│  │  ├─ uds_28_communication_control.c
│  │  ├─ uds_2e_write_did.c
│  │  ├─ uds_31_routine_control.c
│  │  ├─ uds_34_request_download.c
│  │  ├─ uds_36_transfer_data.c
│  │  └─ uds_37_transfer_exit.c
│  └─ transport/
│     ├─ isotp_can.c
│     └─ isotp_can.h
│
├─ network/
│  ├─ comm_manager.c
│  ├─ comm_manager.h
│  ├─ can/
│  │  ├─ can_transport.c
│  │  └─ can_transport.h
│  ├─ lin/
│  │  ├─ lin_driver.c
│  │  ├─ lin_driver.h
│  │  ├─ lin_scheduler.c
│  │  └─ lin_scheduler.h
│
├─ storage/
│  ├─ nvs_dtc_storage.c
│  └─ nvs_dtc_storage.h
│
├─ boards/
│  ├─ frdm_k64f.overlay
│  └─ lin_pins.md
│
├─ tests/
│  ├─ test_state_machine/
│  │  └─ main.c
│  ├─ test_diagnostics/
│  │  └─ main.c
│  ├─ test_isotp/
│  │  └─ main.c
│  └─ test_lin/
│     └─ main.c
│
├─ docs/
│  ├─ architecture.md
│  ├─ uds_service_matrix.md
│  ├─ dtc_list.md
│  └─ diagrams/   (placeholder)
│
├─ CMakeLists.txt
├─ Kconfig
└─ README.md


Tests

Unit tests built on native_posix:
	•	UDS parsing
	•	ISO-TP segment reassembly
	•	DTC persistence
	•	LIN timing + scheduler simulation
	•	FSM logic

⸻

📄 License
Apache 2.0 


Build
west build -b frdm_k64f -p auto .

