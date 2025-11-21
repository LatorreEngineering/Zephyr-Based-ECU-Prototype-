# Zephyr-Based ECU Prototype

[![CI Status](https://github.com/LatorreEngineering/Zephyr-Based-ECU-Prototype-/workflows/CI/badge.svg)](https://github.com/LatorreEngineering/Zephyr-Based-ECU-Prototype-/actions)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Zephyr](https://img.shields.io/badge/Zephyr-v3.7-blue)](https://github.com/zephyrproject-rtos/zephyr)

**Production-ready automotive ECU architecture on Zephyr RTOS**  
**Aligned with Non-AUTOSAR SDV Raul Latorre Platform Vision**

##  Project Overview

This project demonstrates a **fully functional automotive-style ECU** implemented on the Zephyr RTOS, targeting the **NXP FRDM-K64F** development board. It provides a complete reference architecture for next-generation ECUs with:

✅ **Complete UDS diagnostics stack** (ISO 14229) - 13 services  
✅ **Multi-protocol support** - CAN, LIN, ISO-TP  
✅ **Safety-oriented design** - Watchdog, fault injection, DTC management  
✅ **Production CI/CD pipeline** - Reproducible builds, automated testing  
✅ **Modular architecture** - AUTOSAR-inspired layer separation  
✅ **Volvo RFI alignment** - Non-AUTOSAR platform readiness

---

## 📡 Key Features

### Network Layer
- **CAN Bus**: Low-level driver via Zephyr CAN API
- **ISO-TP**: Transport layer for diagnostic communication
- **LIN Master**: UART-based LIN with schedule tables
- **Queue-based architecture**: Asynchronous message handling

### Diagnostics (UDS ISO 14229)
Complete implementation of 13 UDS services:

| Service | Description | Status |
|---------|-------------|--------|
| 0x10 | Diagnostic Session Control | ✅ |
| 0x11 | ECU Reset | ✅ |
| 0x14 | Clear Diagnostics | ✅ |
| 0x19 | Read DTC | ✅ |
| 0x22 | Read Data By Identifier | ✅ |
| 0x23 | Read Memory By Address | ✅ |
| 0x27 | Security Access (Seed/Key) | ✅ |
| 0x28 | Communication Control | ✅ |
| 0x2E | Write Data By Identifier | ✅ |
| 0x31 | Routine Control | ✅ |
| 0x34 | Request Download | ✅ |
| 0x36 | Transfer Data | ✅ |
| 0x37 | Transfer Exit | ✅ |

### Application Layer
- **ECU State Machine**: Ignition states, mode management
- **Sensor Simulation**: RPM, temperature, voltage
- **Fault Injection**: CAN timeout, over-temp, LIN errors
- **Watchdog Supervision**: System health monitoring
- **DTC Manager**: ISO-compliant fault memory with NVS persistence

---

##  Architecture

```
zephyr-ecu-prototype/
├── app/                    # Application layer
│   ├── main.c
│   ├── ecu_state_machine.*
│   ├── sensor_sim.*
│   ├── fault_injection.*
│   └── watchdog_supervisor.*
│
├── diagnostics/            # UDS implementation
│   ├── uds_server.*
│   ├── uds_session.*
│   ├── dtc_manager.*
│   ├── uds_services/       # Individual UDS services
│   └── transport/          # ISO-TP layer
│
├── network/                # Network protocols
│   ├── comm_manager.*
│   ├── can/
│   └── lin/
│
├── storage/                # Persistent storage
│   └── nvs_dtc_storage.*
│
├── ci/                     # CI/CD scripts
│   ├── setup_env.sh
│   ├── build_halo.sh
│   ├── run_experiment.sh
│   └── analyze_vbs.py
│
├── manifests/              # West workspace
│   ├── default.xml
│   └── pinned_manifest.xml
│
├── tests/                  # Unit tests
│   ├── test_state_machine/
│   ├── test_diagnostics/
│   ├── test_isotp/
│   └── test_lin/
│
└── docs/                   # Documentation
    ├── architecture.md
    ├── ci_pipeline.md
    └── safety_readiness.md
```

---

##  Quick Start

### Option 1: Docker (Recommended)

```bash
# Build container
docker build -t zephyr-ecu:latest .

# Run interactive session
docker run -it --rm \
  -v $(pwd):/workspace \
  -v ~/.ccache:/workspace/.ccache \
  zephyr-ecu:latest

# Inside container
source ci/setup_env.sh
ci/build_halo.sh
```

### Option 2: Native Installation

#### Prerequisites
- Ubuntu 22.04 (or compatible Linux distribution)
- Python 3.8+
- CMake 3.20+
- Git

#### Setup

```bash
# Clone repository
git clone https://github.com/LatorreEngineering/Zephyr-Based-ECU-Prototype-.git
cd Zephyr-Based-ECU-Prototype-

# Run setup script
./ci/setup_env.sh

# Source environment
source .env.ci

# Build firmware
./ci/build_halo.sh
```

---

## 🔧 Build System

### Building for Hardware (FRDM-K64F)

```bash
# Standard build
west build -b frdm_k64f -p auto .

# Clean build
west build -b frdm_k64f -p always .

# Flash to board
west flash

# View console output
west attach
```

### Building Tests (native_posix)

```bash
# Build and run state machine tests
west build -b native_posix tests/test_state_machine
./build/zephyr/zephyr.exe

# Build ISO-TP tests
west build -b native_posix tests/test_isotp
./build/zephyr/zephyr.exe

# Build LIN tests
west build -b native_posix tests/test_lin
./build/zephyr/zephyr.exe
```

---

##  Testing & Validation

### Unit Tests

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=. --cov-report=html
```

### Experimental Validation

```bash
# Run 60-second CAN/LIN experiment
./ci/run_experiment.sh --duration 60

# Analyze results
python3 ci/analyze_vbs.py \
  --input results/experiment.vbs \
  --output results/analysis.csv
```

### Static Analysis

```bash
# Run cppcheck
cppcheck --enable=all \
  -I app -I network -I diagnostics \
  app/ network/ diagnostics/

# Check code formatting
find . -name "*.c" -o -name "*.h" | \
  xargs clang-format --dry-run --Werror
```

---

## 📊 CI/CD Pipeline

The project includes a complete GitHub Actions workflow:

- ✅ **Environment setup** with cached dependencies
- ✅ **Multi-board builds** (FRDM-K64F + native_posix)
- ✅ **Automated testing** with coverage reports
- ✅ **Static analysis** (cppcheck, clang-format)
- ✅ **Security scanning** (Trivy)
- ✅ **Experimental validation** with VBS data collection
- ✅ **Documentation generation** (Doxygen)

**Status**: [![CI](https://github.com/LatorreEngineering/Zephyr-Based-ECU-Prototype-/workflows/CI/badge.svg)](https://github.com/LatorreEngineering/Zephyr-Based-ECU-Prototype-/actions)

---

## 🛠️ Supported Hardware

### Primary Target: FRDM-K64F
- **MCU**: NXP Kinetis K64F (ARM Cortex-M4 @ 120 MHz)
- **Flash**: 1 MB
- **RAM**: 256 KB
- **CAN**: Integrated FlexCAN controller
- **LIN**: UART-based (external transceiver recommended)

### Future Targets
- NXP S32K series
- STM32F7 series
- Renesas RH850

---

## 📚 Documentation

Comprehensive documentation available in `docs/`:

- **[Architecture Guide](docs/architecture.md)** - System design and module interactions
- **[CI/CD Pipeline](docs/ci_pipeline.md)** - Build automation and testing
- **[Safety Readiness](docs/safety_readiness.md)** - ASIL compliance roadmap
- **[UDS Service Matrix](docs/uds_service_matrix.md)** - Diagnostic services reference
- **[DTC List](docs/dtc_list.md)** - Fault code definitions

---

## Zephyr-Based ECU Development Roadmap 🎯 

### Phase 1: Foundation (Current)
- ✅ Zephyr RTOS integration
- ✅ Basic CAN/LIN communication
- ✅ UDS diagnostics
- ✅ Reproducible CI/CD

### Phase 2: Maturation (Q4 2025)
- ⬜ Multi-core support (AMP/SMP)
- ⬜ Secure boot (MCUboot)
- ⬜ OTA updates
- ⬜ FMEA documentation

### Phase 3: Safety Certification (Q1 2026)
- ⬜ ASIL-B compliance
- ⬜ Formal verification
- ⬜ Safety manual
- ⬜ Tool qualification

---

## 🔒 Security

Security features:
- ✅ Seed/key authentication (UDS 0x27)
- ✅ Secure session management
- ✅ Memory access protection
- ⬜ Secure boot (planned)
- ⬜ Cryptographic verification (planned)

Report security issues to: security@latorreengineering.com

---

## 🤝 Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/my-feature`
3. **Commit** changes: `git commit -am 'Add feature'`
4. **Push** to branch: `git push origin feature/my-feature`
5. **Submit** a Pull Request

---

## 📄 License

This project is licensed under the **Apache License 2.0**.  
See [LICENSE](LICENSE) for details.

---

## 📧 Contact

**Latorre Engineering**  
Website: https://www.linkedin.com/in/raul-latorre-fortes-631b7130/
Email: raul.latorre+guithub@gmail.com
GitHub: [@LatorreEngineering](https://github.com/LatorreEngineering)

---

## 🌟 Acknowledgments

- **Zephyr Project** - RTOS foundation
- **NXP Semiconductors** - FRDM-K64F support
- **ISO** - UDS and diagnostic standards

---

**⭐ If this project helps you, please consider starring it on GitHub!**
