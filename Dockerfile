# =============================================================================
# Zephyr ECU Prototype - Development & CI Container
# =============================================================================
# Purpose: Reproducible build environment for local development and CI/CD
# Base: Ubuntu 22.04 LTS with Zephyr SDK
# Usage:
#   docker build -t zephyr-ecu:latest .
#   docker run -it -v $(pwd):/workspace zephyr-ecu:latest
# =============================================================================

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Build arguments for version control
ARG ZEPHYR_SDK_VERSION=0.16.8
ARG ZEPHYR_VERSION=v3.7-branch
ARG BUILD_DATE
ARG VCS_REF

# Metadata labels
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.authors="Latorre Engineering"
LABEL org.opencontainers.image.url="https://github.com/LatorreEngineering/Zephyr-Based-ECU-Prototype-"
LABEL org.opencontainers.image.source="https://github.com/LatorreEngineering/Zephyr-Based-ECU-Prototype-"
LABEL org.opencontainers.image.version="${VCS_REF}"
LABEL org.opencontainers.image.title="Zephyr ECU Development Environment"
LABEL org.opencontainers.image.description="Complete development environment for Zephyr-based automotive ECU"

# =============================================================================
# Stage 1: Base System Setup
# =============================================================================

# Update package lists and install essential tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    cmake \
    ninja-build \
    make \
    gcc \
    g++ \
    # Version control
    git \
    git-lfs \
    # Python
    python3 \
    python3-pip \
    python3-dev \
    python3-setuptools \
    python3-wheel \
    # Zephyr dependencies
    ccache \
    dfu-util \
    device-tree-compiler \
    wget \
    xz-utils \
    file \
    # Debugging tools
    gdb-multiarch \
    openocd \
    # CAN tools
    can-utils \
    # Network tools
    iproute2 \
    iputils-ping \
    # Documentation
    doxygen \
    graphviz \
    # Analysis tools
    cppcheck \
    clang-format \
    clang-tidy \
    # Security scanning
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Stage 2: Python Environment
# =============================================================================

# Upgrade pip
RUN python3 -m pip install --no-cache-dir --upgrade pip

# Install Python packages
RUN pip install --no-cache-dir \
    west==1.2.0 \
    pyelftools \
    pyyaml \
    cantools \
    python-can \
    intelhex \
    pyserial \
    pytest \
    pytest-cov \
    gcovr \
    kconfiglib \
    # Additional tools
    black \
    pylint \
    mypy

# =============================================================================
# Stage 3: Zephyr SDK Installation
# =============================================================================

# Create directories
RUN mkdir -p /opt/zephyr-sdk

# Download and install Zephyr SDK
WORKDIR /tmp
RUN wget -q https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}/zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-x86_64.tar.xz \
    && tar -xf zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-x86_64.tar.xz -C /opt \
    && rm zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-x86_64.tar.xz

# Run SDK setup script
RUN /opt/zephyr-sdk-${ZEPHYR_SDK_VERSION}/setup.sh -t arm-zephyr-eabi -h -c

# =============================================================================
# Stage 4: Environment Configuration
# =============================================================================

# Set environment variables
ENV ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk-${ZEPHYR_SDK_VERSION}
ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr
ENV GNUARMEMB_TOOLCHAIN_PATH=/opt/zephyr-sdk-${ZEPHYR_SDK_VERSION}/arm-zephyr-eabi

# Configure Git for container usage
RUN git config --global user.email "ci@latorreengineering.com" \
    && git config --global user.name "Zephyr ECU CI" \
    && git config --global safe.directory '*'

# Setup ccache
ENV CCACHE_DIR=/workspace/.ccache
RUN mkdir -p /workspace/.ccache

# =============================================================================
# Stage 5: Workspace Setup
# =============================================================================

# Create workspace directory
RUN mkdir -p /workspace
WORKDIR /workspace

# Create non-root user for security
RUN useradd -m -u 1000 -s /bin/bash developer \
    && chown -R developer:developer /workspace \
    && chown -R developer:developer /opt/zephyr-sdk-${ZEPHYR_SDK_VERSION}

# Switch to non-root user
USER developer

# Initialize shell environment
RUN echo 'export ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk-'${ZEPHYR_SDK_VERSION} >> ~/.bashrc \
    && echo 'export ZEPHYR_TOOLCHAIN_VARIANT=zephyr' >> ~/.bashrc \
    && echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc \
    && echo 'alias build-ecu="west build -b frdm_k64f -p auto"' >> ~/.bashrc \
    && echo 'alias test-ecu="west build -b native_posix tests/"' >> ~/.bashrc

# =============================================================================
# Stage 6: Helper Scripts
# =============================================================================

# Create entrypoint script
USER root
RUN echo '#!/bin/bash\n\
set -e\n\
echo "========================================"\n\
echo "Zephyr ECU Development Container"\n\
echo "========================================"\n\
echo "Zephyr SDK: '${ZEPHYR_SDK_VERSION}'"\n\
echo "Python: $(python3 --version)"\n\
echo "West: $(west --version)"\n\
echo "CMake: $(cmake --version | head -n1)"\n\
echo "========================================"\n\
echo ""\n\
if [ "$#" -eq 0 ]; then\n\
    exec /bin/bash\n\
else\n\
    exec "$@"\n\
fi\n' > /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

USER developer

# =============================================================================
# Stage 7: Volume Mounts & Final Configuration
# =============================================================================

# Define volumes
VOLUME ["/workspace"]

# Set working directory
WORKDIR /workspace

# Healthcheck (optional)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD west --version || exit 1

# Entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]

# =============================================================================
# Build Information
# =============================================================================
# To build:
#   docker build -t zephyr-ecu:latest \
#     --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
#     --build-arg VCS_REF=$(git rev-parse --short HEAD) \
#     .
#
# To run:
#   docker run -it --rm \
#     -v $(pwd):/workspace \
#     -v ~/.ccache:/workspace/.ccache \
#     --device=/dev/ttyACM0 \
#     zephyr-ecu:latest
#
# For CI:
#   docker run --rm \
#     -v $(pwd):/workspace \
#     zephyr-ecu:latest \
#     bash -c "source ci/setup_env.sh && ci/build_halo.sh"
# =============================================================================
