# Ubuntu 24.04 LTS for kernel 6.8.0 compatibility
FROM ubuntu:24.04

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

# Download and prepare kernel 6.8.0 source for module building
WORKDIR /usr/src
RUN wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz && \
    tar -xf linux-6.8.tar.xz && \
    rm linux-6.8.tar.xz && \
    ln -s linux-6.8 linux

# Prepare kernel source for module building
WORKDIR /usr/src/linux-6.8
RUN make defconfig && \
    make prepare && \
    make modules_prepare

# Set up the working directory for the PTX driver
WORKDIR /opt/ptx

# Copy the PTX driver source code
COPY . /opt/ptx/

# Create a script to set up the build environment
RUN echo '#!/bin/bash\n\
export KVER=6.8.0\n\
export KDIR=/usr/src/linux-6.8\n\
export KBUILD=/usr/src/linux-6.8\n\
echo "Build environment set for kernel $KVER"\n\
echo "KDIR=$KDIR"\n\
echo "KBUILD=$KBUILD"\n\
exec "$@"' > /usr/local/bin/ptx-env.sh && \
    chmod +x /usr/local/bin/ptx-env.sh

# Set the entry point to use the environment script
ENTRYPOINT ["/usr/local/bin/ptx-env.sh"]

# Default command
CMD ["/bin/bash"]