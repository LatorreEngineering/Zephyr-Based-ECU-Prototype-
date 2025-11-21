# CI/CD Pipeline Documentation

## Overview

The Zephyr ECU project implements a **production-grade CI/CD pipeline** ensuring reproducible builds, automated testing, and continuous quality validation.

## Pipeline Architecture

```
┌─────────────┐
│   Trigger   │  Push, PR, Schedule, Manual
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────────────────────┐
│  Job 1: Setup & Validation                       │
│  - Validate manifest pinning                     │
│  - Check Python dependencies                     │
│  - Generate cache keys                           │
└──────┬───────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────┐
│  Job 2: Initialize Zephyr Workspace              │
│  - West init with pinned_manifest.xml            │
│  - West update (cached)                          │
│  - Export Zephyr environment                     │
└──────┬───────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────┐
│  Job 3: Install Zephyr SDK                       │
│  - Download SDK 0.16.8 (cached)                  │
│  - Install ARM toolchain                         │
└──────┬───────────────────────────────────────────┘
       │
       ├────────────────────┬─────────────────────┐
       │                    │                     │
       ▼                    ▼                     ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────┐
│  Build HW    │  │  Build Tests │  │  Static Analysis │
│  FRDM-K64F   │  │  native_posix│  │  cppcheck        │
│  - Firmware  │  │  - Unit tests│  │  - clang-format  │
│  - Metadata  │  │  - Run tests │  │                  │
└──────┬───────┘  └──────┬───────┘  └──────────────────┘
       │                 │
       │                 │
       ▼                 ▼
┌────────────────────────────────────────────┐
│  Job 6: Experimental Validation (Optional) │
│  - Setup vcan0                             │
│  - Run experiments                         │
│  - Generate VBS data                       │
│  - Analysis & reports                      │
└────────────────────────────────────────────┘
       │
       ▼
┌────────────────────────────────────────────┐
│  Job 7: Security Scan                      │
│  - Trivy vulnerability scan                │
│  - Upload SARIF results                    │
└────────────────────────────────────────────┘
       │
       ▼
┌────────────────────────────────────────────┐
│  Job 8: Documentation Generation           │
│  - Doxygen API docs                        │
│  - Upload artifacts                        │
└────────────────────────────────────────────┘
       │
       ▼
┌────────────────────────────────────────────┐
│  Job 9: Build Summary                      │
│  - Aggregate results                       │
│  - Generate badge status                   │
└────────────────────────────────────────────┘
```

## Key Features

### 1. Reproducible Builds

**Mechanism**: Pinned manifest with commit SHAs

```xml
<!-- All dependencies locked to specific commits -->
<project name="zephyr" 
         revision="3c984bcb2e6c3e35b9d3f8c3f9e2a5b7c6d4e5f8"/>
```

**Validation**:
- CI fails if branch names found in `pinned_manifest.xml`
- Weekly jobs to detect upstream drift

### 2. Intelligent Caching

**Cache Strategy**:
```yaml
cache-key: zephyr-${{ env.ZEPHYR_VERSION }}-${{ hashFiles('manifests/pinned_manifest.xml') }}
```

**Cached Artifacts**:
- Zephyr workspace (~1 GB)
- Zephyr SDK (~600 MB)
- CMake build cache
- ccache compilation cache

**Performance Impact**:
- Cold build: ~15 minutes
- Cached build: ~3 minutes

### 3. Multi-Board Testing

| Board | Purpose | Tests |
|-------|---------|-------|
| `frdm_k64f` | Production firmware | Build, size check |
| `native_posix` | Unit tests | State machine, ISO-TP, LIN |

### 4. Automated Experiments

**Trigger**: Nightly or manual

**Process**:
1. Setup virtual CAN (`vcan0`)
2. Generate test stimuli (Python)
3. Record traffic (candump)
4. Convert to VBS format
5. Analyze timing & anomalies
6. Generate CSV reports

**Artifacts**: Stored for 90 days

### 5. Security Scanning

**Tools**:
- **Trivy**: CVE detection in dependencies
- **SARIF Upload**: Integrates with GitHub Security

**Frequency**: Every push

## CI Scripts Reference

### `ci/setup_env.sh`

**Purpose**: Initialize Zephyr workspace

**Usage**:
```bash
./ci/setup_env.sh
source .env.ci
```

**Features**:
- Dependency checking
- West installation
- Workspace initialization
- Manifest validation
- Environment file generation

**Output**: `.env.ci` with environment variables

### `ci/build_halo.sh`

**Purpose**: Build firmware with metadata

**Usage**:
```bash
./ci/build_halo.sh [options]
  -b, --board BOARD      Target board (default: frdm_k64f)
  -c, --clean            Clean build
  -p, --pristine         Pristine build
  -e, --experimental     Enable experimental features
  -v, --verbose          Verbose output
```

**Features**:
- Environment validation
- Git metadata capture
- Build timing
- Artifact verification
- Memory usage analysis
- Build report generation

**Artifacts**:
- `build/zephyr/zephyr.{elf,bin,hex}`
- `build/build_report.txt`
- `build/memory_usage.txt`

### `ci/run_experiment.sh`

**Purpose**: Run automated CAN/LIN experiments

**Usage**:
```bash
./ci/run_experiment.sh [options]
  -d, --duration SEC     Duration in seconds (default: 60)
  -o, --output FILE      Output VBS file
  -c, --can-interface    CAN interface (default: vcan0)
```

**Process**:
1. Setup vcan0
2. Start candump logging
3. Generate test stimuli
4. Wait for duration
5. Stop logging
6. Convert to VBS
7. Generate summary

**Output**:
- `results/experiment_YYYYMMDD_HHMMSS.vbs`
- `results/candump_YYYYMMDD_HHMMSS.log`
- `results/experiment_summary.txt`

### `ci/analyze_vbs.py`

**Purpose**: Analyze VBS experimental data

**Usage**:
```python
python3 ci/analyze_vbs.py \
  --input results/experiment.vbs \
  --output results/analysis.csv \
  --report results/report.txt
```

**Analysis**:
- Message timing statistics
- ID distribution
- Jitter detection
- Frequency irregularities
- Anomaly detection

**Output**:
- CSV with detailed metrics
- Text report with summary
- Anomaly list with severity

## Environment Variables

### Required for CI

```bash
# Zephyr configuration
export ZEPHYR_BASE=/path/to/zephyr
export ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk-0.16.8
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr

# Build configuration
export BOARD=frdm_k64f
export CMAKE_PREFIX_PATH=$ZEPHYR_BASE
```

### Optional

```bash
# Experimental features
export ENABLE_EXPERIMENTAL_MODE=ON

# Performance
export CCACHE_DIR=/workspace/.ccache
export CCACHE_MAXSIZE=5G
```

## GitHub Actions Workflow

### Triggers

```yaml
on:
  push:
    branches: [main, develop, 'feature/**']
  pull_request:
    branches: [main, develop]
  schedule:
    - cron: '0 2 * * *'  # Nightly at 2 AM UTC
  workflow_dispatch:
```

### Concurrency Control

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Prevents duplicate builds on rapid pushes.

### Job Dependencies

```
setup → init-workspace → install-sdk
                    ↓
            build-hardware, build-tests, static-analysis
                    ↓
            run-experiments (optional)
                    ↓
            security-scan, documentation
                    ↓
            summary
```

## Docker Support

### Building Container

```bash
docker build -t zephyr-ecu:latest \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  .
```

### Running in CI

```bash
docker run --rm \
  -v $(pwd):/workspace \
  -v ~/.ccache:/workspace/.ccache \
  zephyr-ecu:latest \
  bash -c "source ci/setup_env.sh && ci/build_halo.sh"
```

### Local Development

```bash
docker run -it --rm \
  -v $(pwd):/workspace \
  --device=/dev/ttyACM0 \
  zephyr-ecu:latest
```

## Monitoring & Alerts

### Build Status Badge

```markdown
[![CI Status](https://github.com/LatorreEngineering/Zephyr-Based-ECU-Prototype-/workflows/CI/badge.svg)](https://github.com/LatorreEngineering/Zephyr-Based-ECU-Prototype-/actions)
```

### Notifications

- **Email**: On build failure (main branch)
- **Slack**: Integration via webhook (optional)
- **GitHub**: PR comments with test results

## Best Practices

### 1. Manifest Pinning

❌ **Bad**:
```xml
<project name="zephyr" revision="main"/>
```

✅ **Good**:
```xml
<project name="zephyr" revision="3c984bcb2e6c3e35b9d3f8c3f9e2a5b7c6d4e5f8"/>
```

### 2. Cache Invalidation

Update cache keys when:
- Manifest changes
- SDK version changes
- Build configuration changes

### 3. Artifact Retention

| Artifact Type | Retention | Reason |
|--------------|-----------|---------|
| Firmware | 30 days | Release candidates |
| Test results | 14 days | Debug failures |
| Experimental data | 90 days | Research |
| Documentation | 30 days | API reference |

### 4. Error Handling

All scripts use:
```bash
set -euo pipefail
```

- `-e`: Exit on error
- `-u`: Error on undefined variable
- `-o pipefail`: Pipeline failures propagate

## Troubleshooting

### Common Issues

**Issue**: West update fails
```bash
# Solution: Clear cache
rm -rf ~/zephyr-workspace
./ci/setup_env.sh
```

**Issue**: Build cache corruption
```bash
# Solution: Clean ccache
ccache -C
west build -b frdm_k64f -p always .
```

**Issue**: Manifest not pinned
```bash
# Solution: Regenerate pinned manifest
west update
west manifest --freeze > manifests/pinned_manifest.xml
```

## Performance Metrics

### Typical Build Times

| Stage | Cold | Cached |
|-------|------|--------|
| Setup | 2 min | 30 sec |
| West init | 5 min | 1 min |
| SDK install | 3 min | 10 sec |
| Firmware build | 5 min | 1 min |
| Tests | 2 min | 30 sec |
| **Total** | **17 min** | **3 min** |

### Resource Usage

- **CPU**: 2 cores recommended
- **RAM**: 4 GB minimum, 8 GB recommended
- **Disk**: 5 GB (workspace + cache)
- **Network**: ~1.5 GB initial download

## Future Improvements

1. **Parallel Testing**: Run tests concurrently
2. **Hardware-in-Loop**: Automated FRDM-K64F testing
3. **Performance Regression**: Track binary size, RAM usage
4. **Release Automation**: Tag → Build → GitHub Release
5. **Nightly Performance Tests**: Long-duration stress tests

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-21
