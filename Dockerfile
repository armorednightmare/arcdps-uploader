FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install build tools and MinGW-w64 cross-compiler
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    curl \
    zip \
    unzip \
    tar \
    pkg-config \
    mingw-w64 \
    && rm -rf /var/lib/apt/lists/*

# Set MinGW to use POSIX threads (needed for std::thread, std::mutex, etc.)
RUN update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix && \
    update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

# Install vcpkg
RUN git clone https://github.com/microsoft/vcpkg.git /opt/vcpkg && \
    /opt/vcpkg/bootstrap-vcpkg.sh -disableMetrics

ENV VCPKG_ROOT=/opt/vcpkg
ENV PATH="${VCPKG_ROOT}:${PATH}"

WORKDIR /src

# Default: run the build
CMD ["/bin/bash", "/src/docker-build.sh"]
