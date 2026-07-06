# Build environment for PTX drivers
#   Ubuntu 24.04 + kernel 6.8 (default) / Ubuntu 26.04 + kernel 7.0:
#   docker build -t ptx-build .
#   docker build --build-arg UBUNTU=26.04 --build-arg KSRC=7.0 -t ptx-build-7.0 .
ARG UBUNTU=24.04
FROM ubuntu:${UBUNTU}

# Kernel source version to build modules against (e.g. 6.8, 7.0)
ARG KSRC=6.8

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies and kernel development tools
RUN apt-get update && apt-get install -y \
        build-essential \
        kmod \
        dkms \
        git \
        wget \
        curl \
        bc \
        bison \
        flex \
        libssl-dev \
        libelf-dev \
        ncurses-dev \
        pkg-config \
        vim \
        xz-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download and prepare kernel source for module building
WORKDIR /usr/src
RUN wget https://cdn.kernel.org/pub/linux/kernel/v${KSRC%%.*}.x/linux-${KSRC}.tar.xz && \
    tar -xf linux-${KSRC}.tar.xz && \
    rm linux-${KSRC}.tar.xz && \
    ln -s linux-${KSRC} linux

# Prepare kernel source for module building
WORKDIR /usr/src/linux-${KSRC}
RUN make defconfig && \
    make prepare && \
    make modules_prepare

# Set up the working directory for the PTX driver
WORKDIR /opt/ptx

# Copy the PTX driver source code
COPY . /opt/ptx/

# Create a script to set up the build environment
RUN echo "#!/bin/bash\n\
export KVER=${KSRC}.0\n\
export KDIR=/usr/src/linux-${KSRC}\n\
export KBUILD=/usr/src/linux-${KSRC}\n\
echo \"Build environment set for kernel \$KVER\"\n\
echo \"KDIR=\$KDIR\"\n\
echo \"KBUILD=\$KBUILD\"\n\
exec \"\$@\"" > /usr/local/bin/ptx-env.sh && \
    chmod +x /usr/local/bin/ptx-env.sh

# Set the entry point to use the environment script
ENTRYPOINT ["/usr/local/bin/ptx-env.sh"]

# Default command
CMD ["/bin/bash"]
